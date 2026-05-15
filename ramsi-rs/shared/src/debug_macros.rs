#[macro_export]
macro_rules! dprintln {
    ($($arg:tt)*) => {
        {
            let mut res = std::fmt::format(format_args!($($arg)*));

            // carriage return should be dipslay only on windows
            #[cfg(windows)]
            res.push('\r');

            res.push_str("\n\0");

            #[allow(unused_unsafe)]
            unsafe {
                windows::Win32::System::Diagnostics::Debug::OutputDebugStringA(windows_core::PCSTR::from_raw(res.as_ptr()));
            }
        }

    }
}

// #[macro_export]
// macro_rules! debug {
//     ($($arg:tt)*) => {
//         if $crate::DEBUG {
//             $crate::dprintln!($($arg)*)
//         }
//     }
// }

#[macro_export]
macro_rules! win_log {
    ($($arg:tt)*) => {
        $crate::dprintln!($($arg)*)
    }
}

pub fn write_log_line(line: &str) {
    use std::io::Write;
    let log_path = r"C:\ProgramData\Confidence\logs\ramsi-com.log";
    if let Some(parent) = std::path::Path::new(log_path).parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(log_path)
    {
        let pid = std::process::id();
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        let _ = writeln!(f, "[{now} pid={pid}] {line}");
        let _ = f.flush();
    }
}

#[macro_export]
macro_rules! file_log {
    ($($arg:tt)*) => {
        {
            let msg = std::fmt::format(format_args!($($arg)*));
            $crate::debug_macros::write_log_line(&msg);
            $crate::dprintln!("{}", msg);
        }
    }
}
