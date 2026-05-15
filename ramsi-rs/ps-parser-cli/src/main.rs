//! ps-parser-cli -- PowerShell scanner CLI based on ps-parser.
//!
//! Mirrors the `PsParser.exe [--json] <path>` interface so it can drop in
//! as an alternative to the C# detector. Where PsParser.exe relies on its
//! own AST walker, this binary leans on the ps-parser crate to recover
//! literal strings from method-call / format-operator / encoding
//! obfuscation that the C# side currently misses.
//!
//! Usage:
//!     ps-parser-cli [--json | -j] [--features] <file-or-dir>
//!
//! - Without `--json`: human-readable report on stdout, one block per file.
//! - With `--json`: machine-readable JSON. A single object for a file, a
//!   JSON array for a directory. Banner / errors go to stderr so stdout
//!   stays parseable.
//! - `--features`: currently a no-op (kept for CLI parity with PsParser.exe;
//!   prints a notice to stderr and exits 0).

mod deob;
mod detector;
mod patterns;

use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use detector::{ScanResult, scan_source};

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let json_mode = args.iter().any(|a| a == "--json" || a == "-j");
    let features_mode = args.iter().any(|a| a == "--features");
    let path_args: Vec<&String> = args
        .iter()
        .filter(|a| *a != "--json" && *a != "-j" && *a != "--features")
        .collect();

    if path_args.is_empty() {
        eprintln!("usage: ps-parser-cli [--json|-j] [--features] <file-or-dir>");
        return ExitCode::from(2);
    }

    if features_mode {
        eprintln!("--features mode is not implemented by ps-parser-cli (only PsParser.exe emits feature CSVs).");
        return ExitCode::SUCCESS;
    }

    let path = PathBuf::from(path_args[0]);
    let files = match collect_files(&path) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("error: {e}");
            return ExitCode::from(1);
        },
    };

    if json_mode {
        eprintln!("Scanning {} file(s) in: {}", files.len(), path.display());
        if path.is_dir() {
            let results: Vec<ScanResult> = files
                .iter()
                .filter_map(|f| scan_one(f).ok())
                .collect();
            println!(
                "{}",
                serde_json::to_string_pretty(&results).expect("serialize array")
            );
        } else {
            match scan_one(&files[0]) {
                Ok(r) => println!(
                    "{}",
                    serde_json::to_string_pretty(&r).expect("serialize object")
                ),
                Err(e) => {
                    eprintln!("ERROR {}: {e}", files[0].display());
                    return ExitCode::from(1);
                },
            }
        }
        return ExitCode::SUCCESS;
    }

    // ── plain text mode ─────────────────────────────────────────────────
    println!("Scanning {} file(s) in: {}\n", files.len(), path.display());
    println!(
        "{:<50} {:<14} {:>5}  Indicators",
        "File", "Status", "Conf"
    );
    println!("{}", "-".repeat(100));

    for f in &files {
        match scan_one(f) {
            Ok(r) => {
                let name = f.file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
                let summary = indicator_summary(&r);
                println!(
                    "{:<50} {:<14} {:>5}  {}",
                    truncate(&name, 50),
                    r.status,
                    r.confidence,
                    summary
                );
            },
            Err(e) => {
                let name = f.file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
                println!("{:<50} {:<14}        {e}", truncate(&name, 50), "ERROR");
            },
        }
    }

    println!();
    ExitCode::SUCCESS
}

fn collect_files(path: &Path) -> std::io::Result<Vec<PathBuf>> {
    if path.is_file() {
        return Ok(vec![path.to_path_buf()]);
    }
    if !path.is_dir() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!("path not found: {}", path.display()),
        ));
    }
    let mut out = Vec::new();
    walk(path, &mut out)?;
    out.sort();
    Ok(out)
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let p = entry.path();
        let ty = entry.file_type()?;
        if ty.is_dir() {
            walk(&p, out)?;
        } else if ty.is_file()
            && p.extension().map(|e| e.eq_ignore_ascii_case("ps1")).unwrap_or(false)
        {
            out.push(p);
        }
    }
    Ok(())
}

fn scan_one(file: &Path) -> std::io::Result<ScanResult> {
    let source = fs::read_to_string(file)?;
    let name = file.file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
    Ok(scan_source(&name, &source))
}

fn indicator_summary(r: &ScanResult) -> String {
    use std::collections::BTreeMap;
    let mut counts: BTreeMap<&str, u32> = BTreeMap::new();
    for ind in &r.amsi_bypass.indicators {
        *counts.entry(ind.kind.as_str()).or_insert(0) += 1;
    }
    if counts.is_empty() {
        return "-".into();
    }
    counts
        .iter()
        .map(|(k, v)| format!("{k}({v})"))
        .collect::<Vec<_>>()
        .join(", ")
}

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max { s.into() } else { format!("{}...", &s[..max - 3]) }
}
