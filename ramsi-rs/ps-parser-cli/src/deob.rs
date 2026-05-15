//! Recursive base64 deobfuscation -- mirrors steps 2 and 14 of
//! `PsParser/AmsiBypassDetector.cs::ScanSource`.
//!
//! Catches the (very common) pattern of embedding a compiled .NET DLL
//! as a base64 string and loading it via `[Reflection.Assembly]::Load(...)`.
//! The embedded DLL's literal strings live in the `#US` heap as UTF-16LE,
//! so we decode bytes and search both an ASCII and a UTF-16LE view.

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use std::collections::HashSet;

/// Maximum base64 layers we will recurse through (matches PsParser's 8).
const MAX_DEPTH: usize = 8;
const MIN_BLOB_LEN: usize = 20;

/// Scan `source` for base64 blobs; decode each, then call `consume` with
/// the decoded text (ASCII view + UTF-16LE view joined). Recursively
/// processes base64 blobs found *within* the decoded output up to
/// `MAX_DEPTH` levels deep.
pub fn scan_recursive<F: FnMut(&str)>(source: &str, mut consume: F) {
    let mut seen: HashSet<String> = HashSet::new();
    let mut queue: Vec<(String, usize)> = Vec::new();

    for blob in find_blobs(source) {
        if seen.insert(blob.to_string()) {
            queue.push((blob.to_string(), 0));
        }
    }

    while let Some((blob, depth)) = queue.pop() {
        if depth >= MAX_DEPTH {
            continue;
        }
        let Some(decoded) = decode_to_text(&blob) else {
            continue;
        };
        consume(&decoded);

        if depth + 1 < MAX_DEPTH {
            for inner in find_blobs(&decoded) {
                if seen.insert(inner.to_string()) {
                    queue.push((inner.to_string(), depth + 1));
                }
            }
        }
    }
}

fn find_blobs(s: &str) -> Vec<&str> {
    let bytes = s.as_bytes();
    let mut out = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        while i < bytes.len() && !is_b64_char(bytes[i]) {
            i += 1;
        }
        let start = i;
        while i < bytes.len() && is_b64_char(bytes[i]) {
            i += 1;
        }
        // Capture trailing '=' padding chars (up to 2)
        let core_end = i;
        let mut pad_end = core_end;
        let mut pad_count = 0;
        while pad_end < bytes.len() && bytes[pad_end] == b'=' && pad_count < 2 {
            pad_end += 1;
            pad_count += 1;
        }
        let len = pad_end - start;
        if len >= MIN_BLOB_LEN && len % 4 == 0 {
            out.push(&s[start..pad_end]);
        }
        i = pad_end.max(i + 1);
    }
    out
}

fn is_b64_char(b: u8) -> bool {
    b.is_ascii_alphanumeric() || b == b'+' || b == b'/'
}

/// Decode and project to a search-friendly text view: ASCII (replacing
/// control bytes with spaces) joined with a printable-UTF-16LE projection.
/// `None` if the blob is too small to plausibly contain anything useful.
fn decode_to_text(blob: &str) -> Option<String> {
    let bytes = STANDARD.decode(blob).ok()?;
    if bytes.is_empty() {
        return None;
    }

    let ascii: String = bytes
        .iter()
        .map(|&b| {
            if (0x20..0x7F).contains(&b) || b == b'\n' || b == b'\r' || b == b'\t' {
                b as char
            } else {
                ' '
            }
        })
        .collect();

    // UTF-16LE projection: pair adjacent bytes as u16, keep printable code units.
    let mut utf16_out = String::with_capacity(bytes.len() / 2);
    for chunk in bytes.chunks_exact(2) {
        let cu = u16::from_le_bytes([chunk[0], chunk[1]]);
        if (0x20..0x7F).contains(&cu) {
            utf16_out.push(cu as u8 as char);
        } else {
            utf16_out.push(' ');
        }
    }

    let mut combined = String::with_capacity(ascii.len() + utf16_out.len() + 1);
    combined.push_str(&ascii);
    combined.push('\n');
    combined.push_str(&utf16_out);
    Some(combined)
}
