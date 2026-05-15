//! Pattern tables ported from `PsParser/AmsiBypassDetector.cs`.
//!
//! All needles are stored lowercased so callers must lowercase the
//! haystack once before matching.

pub struct Pattern {
    pub needle: &'static str,
    pub kind: &'static str,
    pub severity: &'static str,
    pub description: &'static str,
}

/// AMSI identifier strings. Match anywhere in haystack -- raw source,
/// ps-parser deobfuscated output, or ps-parser folded string set.
pub const STRING_INDICATORS: &[Pattern] = &[
    Pattern {
        needle: "system.management.automation.amsiutils",
        kind: "ReflectionBypass",
        severity: "Critical",
        description: "System.Management.Automation.AmsiUtils referenced -- reflection bypass",
    },
    Pattern {
        needle: "amsiinitfailed",
        kind: "ReflectionBypass",
        severity: "Critical",
        description: "amsiInitFailed field -- flipped to disable AMSI scanning",
    },
    Pattern {
        needle: "amsicontext",
        kind: "ReflectionBypass",
        severity: "Critical",
        description: "amsiContext field -- session struct tampering",
    },
    Pattern {
        needle: "amsiscanbuffer",
        kind: "MemoryPatch",
        severity: "Critical",
        description: "AmsiScanBuffer -- entry point patched in memory",
    },
    Pattern {
        needle: "amsiinitialize",
        kind: "MemoryPatch",
        severity: "Critical",
        description: "AmsiInitialize -- init function patched",
    },
    Pattern {
        needle: "amsisession",
        kind: "ReflectionBypass",
        severity: "Critical",
        description: "amsiSession field -- session struct tampering",
    },
    Pattern {
        needle: "amsi.dll",
        kind: "AmsiDll",
        severity: "High",
        description: "amsi.dll reference",
    },
    Pattern {
        needle: "amsiopensession",
        kind: "ApiCall",
        severity: "High",
        description: "AmsiOpenSession API call",
    },
    Pattern {
        needle: "amsiclosesession",
        kind: "ApiCall",
        severity: "High",
        description: "AmsiCloseSession API call",
    },
];

/// Memory-patching Win32 / Marshal APIs. Match raw source case-insensitively.
pub const MEMORY_PATCH_APIS: &[&str] =
    &["virtualprotect", "writeprocessmemory", "virtualalloc"];

/// Raw-source patterns: type names, method calls, registry paths -- not
/// necessarily inside string literals.
pub const RAW_SOURCE_INDICATORS: &[Pattern] = &[
    // ── Script block smuggling ───────────────────────────────────────
    Pattern {
        needle: "scriptblockast]::new",
        kind: "ScriptBlockSmuggling",
        severity: "Critical",
        description:
            "ScriptBlockAst constructed manually -- spoofed extent hides payload from AMSI",
    },
    Pattern {
        needle: ".getscriptblock()",
        kind: "ScriptBlockSmuggling",
        severity: "High",
        description:
            "GetScriptBlock() converts manipulated AST to executable block, bypassing AMSI scan",
    },
    // ── Hardware breakpoint bypass ───────────────────────────────────
    Pattern {
        needle: "amsi_result_clean",
        kind: "HardwareBreakpoint",
        severity: "Critical",
        description:
            "AMSI_RESULT_CLEAN constant -- hardware breakpoint intercepts AmsiScanBuffer to return clean",
    },
    Pattern {
        needle: "addvectoredexceptionhandler",
        kind: "HardwareBreakpoint",
        severity: "Critical",
        description:
            "AddVectoredExceptionHandler sets hardware breakpoint on AmsiScanBuffer to intercept scan",
    },
    // ── Script block / provider logging disable ──────────────────────
    Pattern {
        needle: "cachedgrouppolicysettings",
        kind: "LoggingBypass",
        severity: "High",
        description:
            "cachedGroupPolicySettings -- modified to disable PowerShell script block logging",
    },
    Pattern {
        needle: "system.management.automation.utils",
        kind: "LoggingBypass",
        severity: "High",
        description:
            "System.Management.Automation.Utils accessed via reflection -- modifies logging/policy settings",
    },
    // ── ETW bypass ───────────────────────────────────────────────────
    Pattern {
        needle: "psetwlogprovider",
        kind: "EtwBypass",
        severity: "Critical",
        description:
            "PSEtwLogProvider accessed via reflection -- disables PowerShell ETW event tracing",
    },
    Pattern {
        needle: "etwprovider",
        kind: "EtwBypass",
        severity: "High",
        description: "etwProvider field access -- used to null ETW provider and suppress logging",
    },
    Pattern {
        needle: "system.management.automation.tracing",
        kind: "EtwBypass",
        severity: "High",
        description: "System.Management.Automation.Tracing namespace accessed -- ETW manipulation",
    },
    // ── WLDP bypass ──────────────────────────────────────────────────
    Pattern {
        needle: "wldpquerydynamiccodetrust",
        kind: "WldpBypass",
        severity: "Critical",
        description:
            "WldpQueryDynamicCodeTrust hook -- bypasses Windows Lockdown Policy dynamic code trust",
    },
    Pattern {
        needle: "wldpisclassinapprovedlist",
        kind: "WldpBypass",
        severity: "High",
        description: "WldpIsClassInApprovedList hook -- bypasses WLDP class allowlist check",
    },
    // ── AMSI provider enumeration (reconnaissance) ──────────────────
    Pattern {
        needle: "software\\microsoft\\amsi\\providers",
        kind: "AmsiProviderEnum",
        severity: "Critical",
        description:
            "Enumerates AMSI providers registry -- typical reconnaissance before vtable/DLL patching",
    },
    Pattern {
        needle: "hklm:\\software\\microsoft\\amsi",
        kind: "AmsiProviderEnum",
        severity: "Critical",
        description: "HKLM AMSI registry path access -- no legitimate use; AMSI provider lookup",
    },
    // ── COM / vtable manipulation ────────────────────────────────────
    Pattern {
        needle: "dllgetclassobject",
        kind: "ComManipulation",
        severity: "High",
        description:
            "Direct DllGetClassObject invocation -- used to obtain raw AMSI provider COM objects",
    },
    Pattern {
        needle: "getdelegateforfunctionpointer",
        kind: "ComManipulation",
        severity: "High",
        description: "Marshal.GetDelegateForFunctionPointer -- used in vtable hijacking",
    },
    Pattern {
        needle: "writeintptr",
        kind: "VtableManipulation",
        severity: "Critical",
        description: "WriteIntPtr -- writes raw pointers (vtable entry override)",
    },
    Pattern {
        needle: "readintptr",
        kind: "VtableManipulation",
        severity: "High",
        description: "ReadIntPtr -- reads pointers from arbitrary memory (vtable walking)",
    },
    Pattern {
        needle: "allochglobal",
        kind: "VtableManipulation",
        severity: "High",
        description: "AllocHGlobal -- allocates raw memory; often used to construct fake vtables",
    },
    Pattern {
        needle: "unmanagedfunctionpointer",
        kind: "ComManipulation",
        severity: "High",
        description:
            "UnmanagedFunctionPointer attribute -- declares delegate for arbitrary native function",
    },
];

/// AMSI-specific indicator types. Used by the scorer: if a script has any
/// indicator of these kinds, the 0.6x penalty for "no AMSI specific" is
/// not applied, and `is_amsi_bypass` triggers at confidence >= 60.
pub const AMSI_SPECIFIC_KINDS: &[&str] = &[
    "ReflectionBypass",
    "MemoryPatch",
    "AmsiDll",
    "AmsiDllHijack",
    "ScriptBlockSmuggling",
    "HardwareBreakpoint",
    "PSv2Downgrade",
    "AddTypeInjection",
    "EtwBypass",
    "WldpBypass",
    "AmsiProviderEnum",
];

/// Token-set rules: matched against ps-parser's lowercased token sets.
/// These are less precise than `RAW_SOURCE_INDICATORS` but catch tokens
/// recovered through deobfuscation that the raw source did not literally
/// contain.
pub const TELEMETRY_TYPES: &[&str] = &[
    "reflection.assembly",
    "system.management.automation.pstypename",
];

pub const TELEMETRY_STRINGS: &[&str] = &[
    "clr.dll",
    "getmodulehandle",
    "getprocaddress",
    "microsoft.win32.unsafenativemethods",
    "system.reflection.bindingflags",
    "system.dll",
];

pub const TELEMETRY_FUNCTIONS: &[&str] = &[
    "add-type",
    "alloc",
    "base64",
    "bypass",
    "create",
    "crypto",
    "cryptor",
    "define",
    "deflatestream",
    "dllimport",
    "dynamicassembly",
    "emit",
    "encodedcommand",
    "execute",
    "expandstring",
    "free",
    "frombase64string",
    "getassemblies",
    "getasynckeystate",
    "getconstructor",
    "getmethod",
    "getmodule",
    "gettype",
    "iex",
    "invoke",
    "iocontrol",
    "method",
    "privileges",
    "remotethread",
    "run",
    "security",
    "start",
    "token",
    "virtual",
];
