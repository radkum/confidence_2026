mod error_msg;

use crate::error_msg::print_last_error;
use common::ItemInfo;
use std::{
    collections::HashMap,
    mem::size_of,
    process::Command,
    ptr::null_mut,
    thread,
    time::Duration,
};
use windows::core::imp::HANDLE;
use windows_sys::Win32::{
    Foundation::{CloseHandle, GENERIC_READ, GENERIC_WRITE, INVALID_HANDLE_VALUE},
    Storage::FileSystem::{CreateFileA, ReadFile, OPEN_EXISTING},
    System::Threading::{
        OpenProcess, QueryFullProcessImageNameW, TerminateProcess,
        PROCESS_QUERY_LIMITED_INFORMATION, PROCESS_SUSPEND_RESUME, PROCESS_TERMINATE,
    },
};

// NtSuspendProcess / NtResumeProcess are not exported by windows-sys but live in ntdll.
// We declare them manually -- standard pattern for these "undocumented" APIs.
#[link(name = "ntdll")]
unsafe extern "system" {
    fn NtSuspendProcess(process: isize) -> i32;
    fn NtResumeProcess(process: isize) -> i32;
}

// Console attach/write APIs -- used to print a red "BLOCKED" message in the
// target process's console (looks like AMSI's "ScriptContainedMaliciousContent").
#[link(name = "kernel32")]
unsafe extern "system" {
    fn AttachConsole(pid: u32) -> i32;
    fn FreeConsole() -> i32;
    fn GetStdHandle(handle: i32) -> isize;
    fn SetConsoleTextAttribute(h: isize, attr: u16) -> i32;
    fn WriteConsoleW(h: isize, buf: *const u16, len: u32, written: *mut u32, reserved: *mut core::ffi::c_void) -> i32;
}

const STD_ERROR_HANDLE: i32 = -12;
const ATTACH_PARENT_PROCESS: u32 = 0xFFFF_FFFF; // a.k.a. -1
const CONSOLE_RED: u16 = 0x0C;   // FOREGROUND_RED | FOREGROUND_INTENSITY
const CONSOLE_GRAY: u16 = 0x07;  // default

/// Writes a red message to the target process's console (the one the user is
/// looking at). Briefly detaches sysmon-um's own console -- restores it after.
fn write_red_to_target_console(target_pid: u32, message: &str) {
    unsafe {
        // Detach from our own console temporarily
        FreeConsole();
        if AttachConsole(target_pid) == 0 {
            // Couldn't attach (e.g. target has no console) -- restore ours and bail
            AttachConsole(ATTACH_PARENT_PROCESS);
            return;
        }
        let h = GetStdHandle(STD_ERROR_HANDLE);
        if h != 0 && h != -1isize {
            SetConsoleTextAttribute(h, CONSOLE_RED);
            let wide: Vec<u16> = message.encode_utf16().collect();
            let mut written: u32 = 0;
            WriteConsoleW(h, wide.as_ptr(), wide.len() as u32, &mut written, core::ptr::null_mut());
            SetConsoleTextAttribute(h, CONSOLE_GRAY);
        }
        FreeConsole();
        AttachConsole(ATTACH_PARENT_PROCESS);
    }
}

// Candidate locations for PsParser.exe (compiled standalone) -- checked in order.
// We prefer the standalone .exe so we don't spawn `dotnet run` (slow + needs source path).
const PSPARSER_EXE_CANDIDATES: &[&str] = &[
    r"C:\Program Files\Confidence\PSParser.exe",
    r"C:\VSExclude\confidence_2026\PsParser\bin\Release\net8.0\PSParser.exe",
    r"C:\VSExclude\confidence_2026\PsParser\bin\Debug\net8.0\PSParser.exe",
];

// Suspicious DLL names (case-insensitive check)
const SUSPICIOUS_DLLS: &[&str] = &["amsi.dll", "wldp.dll"];

// AMSI-related registry key substrings
const SUSPICIOUS_REG_KEYS: &[&str] = &["amsi", "antimalware scan interface"];

fn main() {
    println!("[SysMon Daemon] Starting...");

    unsafe {
        let h_file = CreateFileA(
            "\\\\.\\SysMon\0".as_ptr(),
            GENERIC_READ | GENERIC_WRITE,
            0,
            null_mut(),
            OPEN_EXISTING,
            0,
            0isize,
        ) as HANDLE;

        if h_file == INVALID_HANDLE_VALUE as HANDLE {
            print_last_error("Failed to open SysMon device");
            return;
        }
        println!("[SysMon Daemon] Connected to driver. Monitoring...\n");

        // Track pid -> command_line
        let mut pid_cmdline: HashMap<u32, String> = HashMap::new();
        let mut buffer = vec![0u8; 0x100000]; // 1MB buffer (256 events × ~1048 bytes ≈ 268KB; give headroom)

        loop {
            let mut bytes: u32 = 0;
            let status = ReadFile(
                h_file as isize,
                buffer.as_mut_ptr(),
                buffer.len() as u32,
                &mut bytes as *mut u32,
                null_mut(),
            );

            if status != 0 && bytes > 0 {
                process_events(&buffer, bytes, &mut pid_cmdline);
            }

            thread::sleep(Duration::from_millis(200));
        }
    }
}

fn process_events(buffer: &[u8], size: u32, pid_cmdline: &mut HashMap<u32, String>) {
    let mut offset = 0usize;
    while offset + size_of::<ItemInfo>() <= size as usize {
        let item = unsafe { &*(buffer.as_ptr().add(offset) as *const ItemInfo) };

        match item {
            ItemInfo::ProcessCreate {
                pid,
                parent_pid,
                ref command_line,
            } => {
                let cmd = format!("{:?}", command_line);
                let cmd = cmd.trim_matches('"').to_string();
                if !cmd.is_empty() {
                    println!(
                        "[+] ProcessCreate  pid={:<6} ppid={} cmd={}",
                        pid,
                        parent_pid,
                        &cmd[..cmd.len().min(80)]
                    );
                    pid_cmdline.insert(*pid, cmd);
                }
            }
            ItemInfo::ProcessExit { pid } => {
                pid_cmdline.remove(pid);
            }
            ItemInfo::ImageLoad {
                pid,
                ref image_file_name,
                ..
            } => {
                let name = format!("{:?}", image_file_name);
                let name = name.trim_matches('"').to_string();
                let name_lower = name.to_lowercase();

                let is_suspicious = SUSPICIOUS_DLLS.iter().any(|dll| name_lower.ends_with(dll));

                if is_suspicious {
                    println!("[!] ImageLoad      pid={:<6} dll={}", pid, name);
                    check_and_kill(*pid, pid_cmdline, &format!("ImageLoad({})", name));
                }
            }
            ItemInfo::RegistrySetValue {
                pid, ref key_name, ..
            } => {
                let key = format!("{:?}", key_name);
                let key_lower = key.to_lowercase();

                let is_suspicious = SUSPICIOUS_REG_KEYS.iter().any(|k| key_lower.contains(k));

                if is_suspicious {
                    println!("[!] RegistryWrite  pid={:<6} key={}", pid, key);
                    check_and_kill(*pid, pid_cmdline, &format!("RegistryWrite({})", key));
                }
            }
            ItemInfo::RegistryEnumerate {
                pid, ref key_name, ..
            } => {
                let key = format!("{:?}", key_name);
                println!("[!] AMSI-RECON     pid={:<6} key={}", pid, key);
                handle_amsi_recon(*pid, pid_cmdline);
            }
            _ => {}
        }

        offset += size_of::<ItemInfo>();
    }
}

fn get_process_image_path(pid: u32) -> Option<String> {
    unsafe {
        let h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
        if h == 0 { return None; }
        let mut buf = [0u16; 1024];
        let mut size: u32 = buf.len() as u32;
        let ok = QueryFullProcessImageNameW(h, 0, buf.as_mut_ptr(), &mut size);
        CloseHandle(h);
        if ok == 0 { return None; }
        Some(String::from_utf16_lossy(&buf[..size as usize]))
    }
}

/// Process-image basenames that LEGITIMATELY enumerate AMSI providers
/// (Defender engine, security health). Reads from these are pass-through.
const AMSI_RECON_WHITELIST: &[&str] = &[
    "MsMpEng.exe",
    "MpCmdRun.exe",
    "MsSense.exe",
    "SecurityHealthService.exe",
    "smartscreen.exe",
];

/// User-writable path fragments. When a process has a `.ps1` in its cmdline that
/// references such a path, it's a strong signal: someone runs an attacker-controlled
/// script that reads AMSI registry. Legit users don't do this.
const SUSPECT_PATH_FRAGMENTS: &[&str] = &[
    r"\downloads\",
    r"\desktop\",
    r"\documents\",
    r"\temp\",
    r"\appdata\local\temp\",
    r"\users\",  // generic user-writable
];

fn basename_lower(path: &str) -> String {
    path.rsplit_once(['\\', '/']).map(|(_, b)| b).unwrap_or(path).to_ascii_lowercase()
}

/// Returns true if this process should be killed for performing AMSI recon.
/// `was_tracked` = sysmon-um saw a ProcessCreate event for this pid (i.e. process
/// was spawned AFTER daemon started). Untracked = pre-existing process.
fn is_amsi_recon_suspect(image_path: &str, cmdline: &str, was_tracked: bool) -> bool {
    // 1. Whitelist by image basename (Defender etc.)
    let base = basename_lower(image_path);
    for w in AMSI_RECON_WHITELIST {
        if base == w.to_ascii_lowercase() { return false; }
    }
    let cmd_lower = cmdline.to_ascii_lowercase();

    // 2. PowerShell / cmd loading a script from user-writable path -> suspect
    if cmd_lower.contains(".ps1") {
        for frag in SUSPECT_PATH_FRAGMENTS {
            if cmd_lower.contains(frag) { return true; }
        }
    }
    // 3. reg.exe explicitly querying AMSI -- demo trigger
    if base == "reg.exe" && cmd_lower.contains("amsi") {
        return true;
    }
    // 4. PowerShell / cmd / wmic / etc. enumerating AMSI registry
    //    Legitimate AMSI consumers do their registry reads at process startup
    //    (amsi.dll's provider enumeration during AmsiInitialize). Once amsi.dll
    //    is loaded, those reads STOP. If we receive AMSI recon events for a
    //    PowerShell process whose creation we did NOT track (i.e. the process
    //    was running before sysmon-um started), the reads are happening at
    //    interactive/script execution time -- well after init. That's suspect.
    let scripting_hosts = ["powershell.exe", "pwsh.exe", "cmd.exe", "wscript.exe", "cscript.exe", "mshta.exe", "wmic.exe"];
    if scripting_hosts.contains(&base.as_str()) && !was_tracked {
        return true;
    }
    false
}

fn suspend_process(pid: u32) -> Option<isize> {
    unsafe {
        let h = OpenProcess(
            PROCESS_SUSPEND_RESUME | PROCESS_TERMINATE | PROCESS_QUERY_LIMITED_INFORMATION,
            0,
            pid,
        );
        if h == 0 { return None; }
        let st = NtSuspendProcess(h as isize);
        if st < 0 {
            CloseHandle(h);
            return None;
        }
        Some(h as isize)
    }
}

fn resume_process(h: isize) {
    unsafe {
        let _ = NtResumeProcess(h);
        CloseHandle(h);
    }
}

fn terminate_process_h(h: isize) {
    unsafe {
        let _ = TerminateProcess(h, 1);
        CloseHandle(h);
    }
}

fn handle_amsi_recon(pid: u32, pid_cmdline: &HashMap<u32, String>) {
    let was_tracked = pid_cmdline.contains_key(&pid);
    // 1. SUSPEND FIRST -- freeze the process before it can do more
    let h = match suspend_process(pid) {
        Some(h) => h,
        None => {
            // Process already exited (e.g. fast tools like reg.exe) -- we just log.
            let cmdline = pid_cmdline.get(&pid).cloned().unwrap_or_else(|| "<unknown>".to_string());
            println!("    [!] pid={} ALREADY EXITED -- cannot suspend, only logged", pid);
            println!("        last-known cmdline: {}", &cmdline[..cmdline.len().min(120)]);
            return;
        }
    };
    println!("    [~] SUSPENDED pid={}", pid);

    // 2. Gather context for decision
    let image = get_process_image_path(pid).unwrap_or_else(|| "<unknown>".to_string());
    let cmdline = pid_cmdline.get(&pid).cloned().unwrap_or_else(|| image.clone());
    println!("        image:   {}", image);
    println!("        cmdline: {}", &cmdline[..cmdline.len().min(120)]);
    println!("        tracked: {}", was_tracked);

    // 3. Decide
    if is_amsi_recon_suspect(&image, &cmdline, was_tracked) {
        println!("    [X] VERDICT: SUSPECT -- terminating");

        // Print red "BLOCKED" notice in target's console BEFORE killing it.
        // Mimics AMSI's "ScriptContainedMaliciousContent" red error in PowerShell.
        let red_msg = format!(
            "\r\n\
             This script contains malicious content and has been blocked by Confidence Layer 2.\r\n\
             Reason: AMSI provider registry enumeration (technique used to disable AMSI before payload).\r\n\
                 + CategoryInfo          : ParserError: (:) [], ParseException\r\n\
                 + FullyQualifiedErrorId : ConfidenceAmsiProviderHijackBlocked\r\n\
                 + PID                   : {}\r\n\r\n",
            pid
        );
        write_red_to_target_console(pid, &red_msg);

        terminate_process_h(h);
        println!("    [X] pid={} TERMINATED", pid);
    } else {
        println!("    [OK] VERDICT: whitelisted -- resuming");
        resume_process(h);
    }
}

fn check_and_kill(pid: u32, pid_cmdline: &HashMap<u32, String>, trigger: &str) {
    // Find cmdline for this pid -- fallback to image path if process started before sysmon-um
    let (cmdline, source) = match pid_cmdline.get(&pid) {
        Some(cmd) => (cmd.clone(), "tracked"),
        None => match get_process_image_path(pid) {
            Some(p) => (p, "image path"),
            None => {
                println!("    [?] Cannot get cmdline or image for pid={} — skipping scan", pid);
                return;
            }
        }
    };

    println!(
        "    [>] Scanning pid={} via PsParser (trigger: {}, source: {})",
        pid, trigger, source
    );
    println!("        cmdline: {}", &cmdline[..cmdline.len().min(100)]);

    match run_psparser(&cmdline) {
        Some(result) => {
            println!(
                "        is_amsi_bypass={} confidence={}",
                result.is_bypass, result.confidence
            );
            if result.is_bypass {
                println!("    [!!!] AMSI BYPASS DETECTED — killing pid={}", pid);
                kill_process(pid);
            }
        }
        None => {
            println!("    [?] PsParser scan failed for pid={}", pid);
        }
    }
}

struct ScanResult {
    is_bypass: bool,
    confidence: u32,
}

fn find_psparser_exe() -> Option<&'static str> {
    PSPARSER_EXE_CANDIDATES.iter().find(|p| std::path::Path::new(p).exists()).copied()
}

fn run_psparser(input: &str) -> Option<ScanResult> {
    let exe = find_psparser_exe()?;

    // Write input to temp file
    let tmp_path = std::env::temp_dir().join(format!("sysmon_scan_{}.ps1", std::process::id()));
    std::fs::write(&tmp_path, input).ok()?;

    let output = Command::new(exe)
        .args(["--json", tmp_path.to_str()?])
        .output()
        .ok()?;

    let _ = std::fs::remove_file(&tmp_path);

    let stdout = String::from_utf8_lossy(&output.stdout);

    // Find JSON line
    for line in stdout.lines() {
        let line = line.trim();
        if line.starts_with('{') {
            if let Ok(v) = serde_json::from_str::<serde_json::Value>(line) {
                let is_bypass = v["is_amsi_bypass"].as_bool().unwrap_or(false);
                let confidence = v["confidence_score"].as_u64().unwrap_or(0) as u32;
                return Some(ScanResult {
                    is_bypass,
                    confidence,
                });
            }
        }
    }
    None
}

fn kill_process(pid: u32) {
    unsafe {
        let h = OpenProcess(PROCESS_TERMINATE, 0, pid);
        if h == 0 {
            println!("    [!] Failed to open process pid={}", pid);
            return;
        }
        if TerminateProcess(h, 1) != 0 {
            println!("    [OK] Process pid={} terminated successfully", pid);
        } else {
            print_last_error(&format!("Failed to terminate pid={}", pid));
        }
        CloseHandle(h);
    }
}
