//! AMSI-bypass detector backed by ps-parser.
//!
//! Strategy:
//!   1. Run the script through ps-parser. The crate evaluates `+`
//!      concatenations, format operator (`-f`), char casts, the
//!      `[Convert]::FromBase64String` pipeline, etc. and emits the
//!      `deobfuscated()` reconstruction along with structured token sets
//!      (strings, types, methods).
//!   2. Build a single lowercased haystack from `raw_source` and
//!      `deobfuscated`; substring-match it against the pattern tables in
//!      `patterns`.
//!   3. Second pass over ps-parser's token sets to catch tokens whose
//!      surface form was reconstructed by the parser and never appeared
//!      in the raw source.
//!   4. Combo bonuses (amsi.dll + VirtualProtect, Add-Type + amsi.dll, ...)
//!      and scoring follow the algorithm in PsParser's
//!      `AmsiBypassReport.RecalculateScore`.

use std::collections::{BTreeSet, HashSet};

use ps_parser::{PowerShellSession, Token, Variables};
use serde::Serialize;

use crate::deob;
use crate::patterns::*;

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
    // ── 1. ps-parser pass (best effort) ──────────────────────────────────
    let mut session = PowerShellSession::new().with_variables(Variables::env());

    let (string_set, methods_lower, types_lower, mut deobfuscated, parse_errors) =
        match session.parse_script(source) {
            Ok(sr) => {
                let toks = sr.tokens();
                let s: BTreeSet<String> = toks.lowercased_string_set().into_iter().collect();
                let m: BTreeSet<String> = toks
                    .methods_and_commands()
                    .iter()
                    .map(|s| s.to_ascii_lowercase())
                    .collect();
                let t: BTreeSet<String> = toks
                    .ttypes()
                    .iter()
                    .map(|s| s.to_ascii_lowercase())
                    .collect();
                let mut d = sr.deobfuscated();
                if d.len() > 4000 {
                    d.truncate(4000);
                    d.push_str("\n...[truncated]");
                }
                let errs: Vec<String> = sr.errors().iter().map(|e| e.to_string()).collect();
                (s, m, t, d, errs)
            },
            Err(err) => (
                BTreeSet::new(),
                BTreeSet::new(),
                BTreeSet::new(),
                String::new(),
                vec![format!("parse failed: {err}")],
            ),
        };

    let psv2_via_tokens = match session.parse_script(source) {
        Ok(sr) => detect_psv2(&sr.tokens().all()),
        Err(_) => false,
    };

    // ── 2. Haystack: raw source + deobfuscated text, both lowercased ─────
    let raw_lower = source.to_ascii_lowercase();
    if deobfuscated.is_empty() {
        // Parser refused -- deob is empty; still keep field non-null in JSON.
        deobfuscated = String::new();
    }
    let deob_lower = deobfuscated.to_ascii_lowercase();

    // ── Recursive base64 deobfuscation: catches .NET DLL payloads embedded
    //    via [Reflection.Assembly]::Load([Convert]::FromBase64String("...")) ─
    let mut b64_haystack = String::new();
    deob::scan_recursive(source, |decoded| {
        b64_haystack.push_str(decoded);
        b64_haystack.push('\n');
    });
    let b64_lower = b64_haystack.to_ascii_lowercase();

    let contains_any = |needle: &str| {
        raw_lower.contains(needle) || deob_lower.contains(needle) || b64_lower.contains(needle)
    };

    let mut indicators: Vec<Indicator> = Vec::new();
    let mut seen: HashSet<String> = HashSet::new();

    // ── 3. Pattern tables (Critical / High / Medium) ─────────────────────
    let push_pattern = |inds: &mut Vec<Indicator>,
                        seen: &mut HashSet<String>,
                        p: &Pattern,
                        suffix: &str| {
        let key = format!("{}:{}", p.kind, p.needle);
        if seen.insert(key) {
            inds.push(Indicator {
                kind: p.kind.into(),
                severity: p.severity,
                description: if suffix.is_empty() {
                    p.description.into()
                } else {
                    format!("{} ({suffix})", p.description)
                },
            });
        }
    };

    for p in STRING_INDICATORS {
        if contains_any(p.needle)
            || string_set.iter().any(|s| s.contains(p.needle))
        {
            push_pattern(&mut indicators, &mut seen, p, "");
        }
    }

    for p in RAW_SOURCE_INDICATORS {
        if contains_any(p.needle)
            || string_set.iter().any(|s| s.contains(p.needle))
            || methods_lower.iter().any(|s| s.contains(p.needle))
            || types_lower.iter().any(|s| s.contains(p.needle))
        {
            push_pattern(&mut indicators, &mut seen, p, "");
        }
    }

    for api in MEMORY_PATCH_APIS {
        if contains_any(api) {
            let key = format!("MemoryPatch:{api}");
            if seen.insert(key) {
                indicators.push(Indicator {
                    kind: "MemoryPatch".into(),
                    severity: "High",
                    description: format!("{api} call detected -- possible memory-patching bypass"),
                });
            }
        }
    }

    // ── 4. Token-set telemetry (Medium severity backstop) ────────────────
    for t in TELEMETRY_TYPES {
        if types_lower.iter().any(|s| s.contains(t)) {
            let key = format!("TelemetryType:{t}");
            if seen.insert(key) {
                indicators.push(Indicator {
                    kind: "TelemetryType".into(),
                    severity: "Medium",
                    description: format!("Reflection-adjacent type recovered: '{t}'"),
                });
            }
        }
    }
    for s in TELEMETRY_STRINGS {
        if string_set.iter().any(|t| t.contains(s)) {
            let key = format!("TelemetryString:{s}");
            if seen.insert(key) {
                indicators.push(Indicator {
                    kind: "TelemetryString".into(),
                    severity: "Medium",
                    description: format!("Suspicious string reference: '{s}'"),
                });
            }
        }
    }
    for f in TELEMETRY_FUNCTIONS {
        if methods_lower.iter().any(|s| s.contains(f)) {
            let key = format!("TelemetryFunction:{f}");
            if seen.insert(key) {
                indicators.push(Indicator {
                    kind: "TelemetryFunction".into(),
                    severity: "Medium",
                    description: format!("Suspicious function: '{f}'"),
                });
            }
        }
    }

    // ── 5. Combination indicators (Critical) ─────────────────────────────
    if contains_any("writeallbytes") && contains_any("amsi.dll")
        && seen.insert("combo:writeallbytes+amsi.dll".into())
    {
        indicators.push(Indicator {
            kind: "AmsiDllHijack".into(),
            severity: "Critical",
            description: "WriteAllBytes with amsi.dll path -- writing fake AMSI DLL to disk (DLL hijack bypass)".into(),
        });
    }
    if contains_any("amsi.dll") && contains_any("amsiopensession")
        && seen.insert("combo:amsi.dll+amsiopensession".into())
    {
        indicators.push(Indicator {
            kind: "MemoryPatch".into(),
            severity: "Critical",
            description: "amsi.dll + AmsiOpenSession -- patching session function to bypass scanning".into(),
        });
    }
    if contains_any("amsi.dll") && contains_any("virtualprotect")
        && seen.insert("combo:amsi.dll+virtualprotect".into())
    {
        indicators.push(Indicator {
            kind: "MemoryPatch".into(),
            severity: "Critical",
            description: "amsi.dll + VirtualProtect -- memory patching AMSI function in loaded DLL".into(),
        });
    }
    if contains_any("cachedgrouppolicysettings") && contains_any("scriptblocklogging")
        && seen.insert("combo:cachedgps+sbl".into())
    {
        indicators.push(Indicator {
            kind: "LoggingBypass".into(),
            severity: "Critical",
            description: "cachedGroupPolicySettings + ScriptBlockLogging -- script block logging explicitly disabled".into(),
        });
    }
    if contains_any("add-type") {
        for api in MEMORY_PATCH_APIS {
            if contains_any(api)
                && seen.insert(format!("combo:add-type+{api}"))
            {
                indicators.push(Indicator {
                    kind: "AddTypeInjection".into(),
                    severity: "Critical",
                    description: format!(
                        "Add-Type C# injection with {api} -- inline C# used to patch AMSI"
                    ),
                });
            }
        }
        if contains_any("amsi.dll")
            && seen.insert("combo:add-type+amsi.dll".into())
        {
            indicators.push(Indicator {
                kind: "AddTypeInjection".into(),
                severity: "Critical",
                description: "Add-Type combined with amsi.dll reference -- C# loading/patching AMSI".into(),
            });
        }
    }

    // ── 6. PSv2 downgrade ────────────────────────────────────────────────
    if psv2_via_tokens
        || raw_lower.contains("-version 2")
        || raw_lower.contains("-version  2")
    {
        if seen.insert("PSv2Downgrade".into()) {
            indicators.push(Indicator {
                kind: "PSv2Downgrade".into(),
                severity: "Critical",
                description: "PowerShell v2 downgrade -- PS v2 has no AMSI support".into(),
            });
        }
    }

    // ── 7. Score + status ────────────────────────────────────────────────
    let (status, confidence) = score(&indicators);
    let kinds: HashSet<&str> = indicators.iter().map(|i| i.kind.as_str()).collect();
    let has_critical = indicators.iter().any(|i| i.severity == "Critical");
    let has_amsi_specific = AMSI_SPECIFIC_KINDS.iter().any(|k| kinds.contains(k));
    let is_amsi_bypass = has_critical || (confidence >= 60 && has_amsi_specific);

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
                if (a.eq_ignore_ascii_case("-version") || a.eq_ignore_ascii_case("-v"))
                    && args.get(i + 1).map(|v| v.trim()) == Some("2")
                {
                    return true;
                }
            }
        }
    }
    false
}

/// Score model ported from `AmsiBypassReport.RecalculateScore`:
///   - Critical: 40, High: 20, Medium: 10, Low: 5
///   - Combo bonuses on type co-occurrence
///   - 0.6x penalty if no AMSI-specific kind and base > 30
///   - Clamp to [0, 100]
///   - Status: AMSI BYPASS if any Critical OR (>=60 and AMSI-specific kind)
fn score(indicators: &[Indicator]) -> (&'static str, u32) {
    let mut base: i32 = indicators
        .iter()
        .map(|i| match i.severity {
            "Critical" => 40,
            "High" => 20,
            "Medium" => 10,
            _ => 5,
        })
        .sum();

    let kinds: HashSet<&str> = indicators.iter().map(|i| i.kind.as_str()).collect();

    if kinds.contains("ReflectionBypass") && kinds.contains("MemoryPatch") {
        base += 20;
    }
    if kinds.contains("MemoryPatch") && kinds.contains("AmsiDll") {
        base += 15;
    }
    if kinds.contains("LoggingBypass") && kinds.contains("ReflectionBypass") {
        base += 15;
    }
    if kinds.contains("ScriptBlockSmuggling") && kinds.contains("ReflectionBypass") {
        base += 20;
    }

    let has_amsi_specific = AMSI_SPECIFIC_KINDS.iter().any(|k| kinds.contains(k));
    if !has_amsi_specific && base > 30 {
        base = (base as f64 * 0.6) as i32;
    }

    let confidence = base.clamp(0, 100) as u32;

    let has_critical = indicators.iter().any(|i| i.severity == "Critical");
    let status = if has_critical || (confidence >= 60 && has_amsi_specific) {
        "AMSI BYPASS"
    } else if !indicators.is_empty() {
        "Suspicious"
    } else {
        "Clean"
    };
    (status, confidence)
}
