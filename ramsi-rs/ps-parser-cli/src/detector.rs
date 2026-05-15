//! Detection over ps-parser tokens.
//!
//! `scan_source` is the single entry point: it runs ps-parser, harvests
//! the lowercased token sets, matches them against the keyword tables in
//! `keywords`, and assembles a `ScanResult` that mirrors the JSON schema
//! produced by `PsParser.exe --json` (where the fields overlap).

use ps_parser::{PowerShellSession, Token, Variables};
use serde::Serialize;
use std::collections::BTreeSet;

use crate::keywords::*;

/// Top-level JSON envelope. Field names match `PsParser.exe --json` output
/// for the fields we populate; we add `engine` and `deobfuscated` because
/// they are uniquely produced by this CLI.
#[derive(Serialize)]
pub struct ScanResult {
    pub file: String,
    pub engine: &'static str,
    pub status: &'static str,
    pub confidence: u32,
    pub amsi_bypass: AmsiBypassReport,
    pub deobfuscated: String,
    pub parse_errors: Vec<String>,
}

#[derive(Serialize, Default)]
pub struct AmsiBypassReport {
    pub is_amsi_bypass: bool,
    pub confidence_score: u32,
    pub indicators: Vec<Indicator>,
}

#[derive(Serialize, Clone)]
pub struct Indicator {
    #[serde(rename = "type")]
    pub kind: String,
    pub severity: &'static str,
    pub description: String,
}

pub fn scan_source(file: &str, source: &str) -> ScanResult {
    let mut session = PowerShellSession::new().with_variables(Variables::env());

    let (string_set, commands_and_methods, ttypes, deobfuscated, parse_errors, ps_v2) =
        match session.parse_script(source) {
            Ok(script_result) => {
                let tokens = script_result.tokens();
                let strings: BTreeSet<String> = tokens.lowercased_string_set().into_iter().collect();
                let methods: BTreeSet<String> = tokens
                    .methods_and_commands()
                    .iter()
                    .map(|s| s.to_ascii_lowercase())
                    .collect();
                let types: BTreeSet<String> = tokens
                    .ttypes()
                    .iter()
                    .map(|s| s.to_ascii_lowercase())
                    .collect();
                let all_tokens = tokens.all();
                let ps_v2 = detect_psv2(&all_tokens);
                let errors: Vec<String> =
                    script_result.errors().iter().map(|e| e.to_string()).collect();

                let mut deob = script_result.deobfuscated();
                if deob.len() > 4000 {
                    deob.truncate(4000);
                    deob.push_str("\n...[truncated]");
                }

                (strings, methods, types, deob, errors, ps_v2)
            },
            Err(err) => {
                // Parser refused the file entirely. Fall back to a raw lowercased
                // substring scan so we still surface obvious literal IoCs.
                let lower = source.to_ascii_lowercase();
                let mut strings = BTreeSet::new();
                for tok in lower
                    .split(|c: char| !c.is_alphanumeric() && c != '.' && c != '-' && c != '\\')
                    .filter(|s| !s.is_empty())
                {
                    strings.insert(tok.to_string());
                }
                (
                    strings,
                    BTreeSet::new(),
                    BTreeSet::new(),
                    String::new(),
                    vec![format!("parse failed: {err}")],
                    false,
                )
            },
        };

    let mut indicators: Vec<Indicator> = Vec::new();
    let mut seen: BTreeSet<String> = BTreeSet::new();

    // ── Critical: AMSI-bypass keyword anywhere in deobfuscated strings ──
    for kw in BLACKLIST_KEYWORDS {
        if string_set.iter().any(|s| s.contains(kw))
            && seen.insert(format!("kw:{kw}"))
        {
            indicators.push(Indicator {
                kind: "BlacklistedKeyword".into(),
                severity: "Critical",
                description: format!("AMSI-bypass keyword recovered: '{kw}'"),
            });
        }
    }

    // ── Critical: token endswith a blacklisted suffix (e.g. emsi.dll → amsi.dll) ──
    for suffix in BLACKLIST_KEYWORDS_ENDSWITH {
        if string_set.iter().any(|s| s.ends_with(suffix))
            && seen.insert(format!("suffix:{suffix}"))
        {
            indicators.push(Indicator {
                kind: "BlacklistedSuffix".into(),
                severity: "Critical",
                description: format!("Token ending in '{suffix}' detected"),
            });
        }
    }

    // ── Critical: AMSI-bypass function ──
    for fn_name in BLACKLIST_FUNCTIONS {
        if commands_and_methods.iter().any(|s| s.contains(fn_name))
            && seen.insert(format!("fn:{fn_name}"))
        {
            indicators.push(Indicator {
                kind: "BlacklistedFunction".into(),
                severity: "Critical",
                description: format!("Suspicious function reference: '{fn_name}'"),
            });
        }
    }

    // ── High: telemetry types (Reflection.Assembly etc.) ──
    for ty in TELEMETRY_TYPES {
        if ttypes.iter().any(|s| s.contains(ty)) && seen.insert(format!("ty:{ty}")) {
            indicators.push(Indicator {
                kind: "TelemetryType".into(),
                severity: "High",
                description: format!("Reflection-adjacent type: '{ty}'"),
            });
        }
    }

    // ── Medium: telemetry strings (clr.dll, GetProcAddress, ...) ──
    for s in TELEMETRY_STRINGS {
        if string_set.iter().any(|t| t.contains(s)) && seen.insert(format!("ts:{s}")) {
            indicators.push(Indicator {
                kind: "TelemetryString".into(),
                severity: "Medium",
                description: format!("Suspicious string reference: '{s}'"),
            });
        }
    }

    // ── Medium: telemetry functions (Invoke, Add-Type, Frombase64string, ...) ──
    for f in TELEMETRY_FUNCTIONS {
        if commands_and_methods.iter().any(|s| s.contains(f))
            && seen.insert(format!("tf:{f}"))
        {
            indicators.push(Indicator {
                kind: "TelemetryFunction".into(),
                severity: "Medium",
                description: format!("Suspicious function: '{f}'"),
            });
        }
    }

    // ── Medium: PSv2 downgrade (powershell -Version 2) ──
    if ps_v2 {
        indicators.push(Indicator {
            kind: "PsV2Downgrade".into(),
            severity: "High",
            description: "powershell.exe invoked with -Version 2 (CLM bypass)".into(),
        });
    }

    let (status, confidence) = score(&indicators);
    let is_amsi_bypass = status == "AMSI BYPASS";

    ScanResult {
        file: file.into(),
        engine: "ps-parser/1.0.1",
        status,
        confidence,
        amsi_bypass: AmsiBypassReport {
            is_amsi_bypass,
            confidence_score: confidence,
            indicators,
        },
        deobfuscated,
        parse_errors,
    }
}

fn detect_psv2(tokens: &[Token]) -> bool {
    for tok in tokens {
        if let Token::Command(cmd) = tok
            && cmd.name().eq_ignore_ascii_case("powershell")
        {
            let args = cmd.args();
            for (i, a) in args.iter().enumerate() {
                if a.eq_ignore_ascii_case("-version")
                    && args.get(i + 1).map(|v| v.trim()) == Some("2")
                {
                    return true;
                }
            }
        }
    }
    false
}

fn score(indicators: &[Indicator]) -> (&'static str, u32) {
    let mut score: u32 = 0;
    let mut has_critical = false;
    for ind in indicators {
        let inc = match ind.severity {
            "Critical" => {
                has_critical = true;
                30
            },
            "High" => 15,
            "Medium" => 5,
            _ => 2,
        };
        score = score.saturating_add(inc);
    }
    score = score.min(100);

    let status = if has_critical {
        score = score.max(70);
        "AMSI BYPASS"
    } else if !indicators.is_empty() {
        "Suspicious"
    } else {
        "Clean"
    };

    (status, score)
}
