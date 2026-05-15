//! AMSI-bypass keyword sets.
//!
//! Mirrors the lists in `ramsi-com/src/ramsi/keywords.rs` but kept here as
//! plain `&[&str]` slices (lowercased at compile time by being authored in
//! lowercase) so this crate stays free of macro dependencies.
//!
//! All comparisons MUST be performed against lowercased token sets returned
//! by `ps_parser::ScriptResult::tokens().lowercased_string_set()` and friends.

pub const BLACKLIST_KEYWORDS: &[&str] = &[
    "amsi.dll",
    "amsiinitfailed",
    "amsi/providers",
    "amsi/providers/",
    "amsi/providers\\",
    "amsi\\providers",
    "amsi\\providers/",
    "amsi\\providers\\",
    "amsienable",
    "amsiscanbuffer",
    "amsiutils",
    "invoke-mimikatz",
    "system.management.automation.amsiutils",
    "system.management.automation.utils",
];

pub const BLACKLIST_KEYWORDS_ENDSWITH: &[&str] = &["amsi.dll"];

pub const BLACKLIST_FUNCTIONS: &[&str] = &["amsiinitialize"];

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
