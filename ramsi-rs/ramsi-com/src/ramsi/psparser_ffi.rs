//! FFI loader for PSParser.dll (C# NativeAOT).
//! Loads the DLL at runtime via LoadLibraryW + GetProcAddress.

use windows::Win32::{
    Foundation::HMODULE,
    System::LibraryLoader::{GetProcAddress, LoadLibraryW},
};
use windows_core::PCSTR;

type PsParserScanFn = unsafe extern "C" fn(
    script: *const u8,
    script_len: i32,
    out_json: *mut u8,
    out_json_len: i32,
) -> i32;

pub struct PsParserDll {
    _handle: HMODULE,
    scan_fn: PsParserScanFn,
}

pub struct PsParserResult {
    pub is_amsi_bypass: bool,
    pub confidence_score: u32,
}

impl PsParserDll {
    /// Try to load PSParser.dll from the given path.
    /// Returns None if the DLL is not found or the export is missing.
    pub fn load(path: &str) -> Option<Self> {
        use std::ffi::OsStr;
        use std::os::windows::ffi::OsStrExt;

        let wide: Vec<u16> = OsStr::new(path)
            .encode_wide()
            .chain(std::iter::once(0))
            .collect();

        let handle = match unsafe { LoadLibraryW(windows_core::PCWSTR(wide.as_ptr())) } {
            Ok(h) => h,
            Err(_) => {
                log::warn!("PSParser.dll not found at: {path}");
                return None;
            }
        };

        let scan_fn = unsafe {
            GetProcAddress(handle, PCSTR::from_raw(b"psparser_scan\0".as_ptr()))
        }?;

        let scan_fn: PsParserScanFn = unsafe {
            std::mem::transmute::<unsafe extern "system" fn() -> isize, PsParserScanFn>(scan_fn)
        };
        log::info!("PSParser.dll loaded from: {path}");
        Some(Self { _handle: handle, scan_fn })
    }

    /// Scan a PowerShell script. Returns None if the scan fails.
    pub fn scan(&self, script: &str) -> Option<PsParserResult> {
        let script_bytes = script.as_bytes();
        let mut out_buf = vec![0u8; 65536];

        let written = unsafe {
            (self.scan_fn)(
                script_bytes.as_ptr(),
                script_bytes.len() as i32,
                out_buf.as_mut_ptr(),
                out_buf.len() as i32,
            )
        };

        if written < 0 {
            log::warn!("psparser_scan returned error ({})", written);
            return None;
        }

        let json_str = std::str::from_utf8(&out_buf[..written as usize]).ok()?;
        parse_result(json_str)
    }
}

// DLL lives for process lifetime; OS cleans up on exit.

fn parse_result(json: &str) -> Option<PsParserResult> {
    // Simple manual parse — avoid serde dependency for a single bool+u32
    let is_bypass = json.contains("\"is_amsi_bypass\":true");
    let confidence = parse_u32_field(json, "confidence_score").unwrap_or(0);
    Some(PsParserResult {
        is_amsi_bypass: is_bypass,
        confidence_score: confidence,
    })
}

fn parse_u32_field(json: &str, field: &str) -> Option<u32> {
    let key = format!("\"{}\":", field);
    let start = json.find(&key)? + key.len();
    let rest = json[start..].trim_start();
    let end = rest.find(|c: char| !c.is_ascii_digit()).unwrap_or(rest.len());
    rest[..end].parse().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_result_bypass() {
        let json = r#"{"is_amsi_bypass":true,"confidence_score":85,"indicators":[]}"#;
        let r = parse_result(json).unwrap();
        assert!(r.is_amsi_bypass);
        assert_eq!(r.confidence_score, 85);
    }

    #[test]
    fn test_parse_result_clean() {
        let json = r#"{"is_amsi_bypass":false,"confidence_score":0,"indicators":[]}"#;
        let r = parse_result(json).unwrap();
        assert!(!r.is_amsi_bypass);
        assert_eq!(r.confidence_score, 0);
    }
}
