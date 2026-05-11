using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace PSParser;

// ── Output records ───────────────────────────────────────────────────────────

/// <summary>
/// A C# code block extracted from a PowerShell Add-Type call.
/// </summary>
public record CSharpBlock(
    string Content,     // extracted C# source
    int    LineNumber,  // 1-based line in the PS script where Add-Type appears
    bool   IsDynamic    // true when the type definition comes from a variable ($var)
);

/// <summary>
/// A suspicious pattern found inside a C# block.
/// </summary>
public record CSharpIndicator(
    string Type,         // e.g. "PInvokeKernel32", "MarshalWriteIntPtr"
    string Severity,     // Critical / High / Medium
    string Description,
    string MatchedValue, // the portion of the C# source that matched
    int    BlockIndex    // 0-based index into CSharpScanResult.Blocks
);

/// <summary>
/// Result of scanning a PowerShell script for Add-Type C# blocks.
/// </summary>
public record CSharpScanResult(
    List<CSharpBlock>     Blocks,
    List<CSharpIndicator> Indicators
);

// ── Detector ─────────────────────────────────────────────────────────────────

/// <summary>
/// Extracts C# code blocks from PowerShell Add-Type calls and statically analyses
/// them for suspicious P/Invoke, memory-manipulation, AMSI, and reflective-loading
/// patterns.  No code is executed — analysis is pure string / regex matching.
/// </summary>
public static class CSharpDetector
{
    // ── Extraction regexes ───────────────────────────────────────────────────

    // Add-Type @"..."@  (double-quoted here-string)
    private static readonly Regex HereStringDouble = new(
        @"Add-Type\s+@""(.*?)""@",
        RegexOptions.IgnoreCase | RegexOptions.Singleline);

    // Add-Type @'...'@  (single-quoted here-string)
    private static readonly Regex HereStringSingle = new(
        @"Add-Type\s+@'(.*?)'@",
        RegexOptions.IgnoreCase | RegexOptions.Singleline);

    // Add-Type -TypeDefinition "..."  (inline double-quoted string)
    private static readonly Regex InlineDouble = new(
        @"Add-Type\s+-TypeDefinition\s+""((?:[^""\\]|\\.)*)""",
        RegexOptions.IgnoreCase | RegexOptions.Singleline);

    // Add-Type -TypeDefinition '...'  (inline single-quoted string)
    private static readonly Regex InlineSingle = new(
        @"Add-Type\s+-TypeDefinition\s+'([^']*)'",
        RegexOptions.IgnoreCase | RegexOptions.Singleline);

    // Add-Type -TypeDefinition $variable  (dynamic — can't analyse statically)
    private static readonly Regex DynamicVariable = new(
        @"Add-Type\s+-TypeDefinition\s+(\$\w+)",
        RegexOptions.IgnoreCase | RegexOptions.Singleline);

    // ── Detection patterns ───────────────────────────────────────────────────

    // (regex pattern, type, severity, description)
    private static readonly (Regex Pattern, string Type, string Severity, string Description)[] DetectionRules =
    [
        // P/Invoke: kernel32 memory-manipulation APIs
        (new Regex(@"DllImport\s*\(\s*""kernel32(?:\.dll)?""\s*\)[\s\S]{0,500}?(VirtualProtect|WriteProcessMemory|VirtualAlloc|CreateThread)",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "PInvokeKernel32", "Critical",
         "DllImport(kernel32) with dangerous memory API — typical shellcode injection or AMSI patching"),

        // P/Invoke: ntdll direct NT calls
        (new Regex(@"DllImport\s*\(\s*""ntdll(?:\.dll)?""\s*\)",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "PInvokeNtdll", "Critical",
         "DllImport(ntdll) detected — direct NT syscall bypasses user-mode hooks"),

        // Delegate via function pointer (vtable / CLR hook manipulation)
        (new Regex(@"Marshal\.GetDelegateForFunctionPointer",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "MarshalGetDelegate", "Critical",
         "Marshal.GetDelegateForFunctionPointer — vtable manipulation or CLR hook bypass"),

        // Memory read/write via Marshal (e.g. patching AmsiScanBuffer in-process)
        (new Regex(@"Marshal\.(ReadIntPtr|WriteIntPtr|ReadInt32|WriteInt32|ReadByte|WriteByte)",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "MarshalMemoryAccess", "High",
         "Marshal memory read/write — direct in-process memory manipulation"),

        // Reflective assembly loading from byte array
        (new Regex(@"Assembly\.Load\s*\(\s*(?:new\s+byte|Convert\.FromBase64|\$?\w+\s*,|\[)",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "ReflectiveLoad", "Critical",
         "Assembly.Load(byte[]) — reflective loading of a .NET assembly from memory"),

        // Unmanaged function pointer delegate attribute
        (new Regex(@"\[UnmanagedFunctionPointer",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "UnmanagedFunctionPointer", "High",
         "[UnmanagedFunctionPointer] attribute — defines delegate for unmanaged callback"),

        // AMSI-specific: context / init / scan strings
        (new Regex(@"amsiContext|amsiInitFailed|AmsiScan|amsiSession",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "AmsiString", "Critical",
         "AMSI-related identifier found in C# code — direct AMSI manipulation"),

        // AMSI-specific: GetProcAddress + GetModuleHandle in same block (load + resolve)
        (new Regex(@"GetProcAddress[\s\S]{0,300}?GetModuleHandle|GetModuleHandle[\s\S]{0,300}?GetProcAddress",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "AmsiGetProcAddress", "Critical",
         "GetProcAddress + GetModuleHandle in the same C# block — resolving and patching a loaded DLL function"),

        // AMSI interface GUID
        (new Regex(@"b2bdfe59-e9c5-4a66-9e5e-d41b02f73d17",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "AmsiGuid", "Critical",
         "IAmsiStream GUID (b2bdfe59-...) detected — direct AMSI COM interface manipulation"),

        // Generic "amsi" string anywhere in C# code
        (new Regex(@"""[^""]*amsi[^""]*""",
            RegexOptions.IgnoreCase | RegexOptions.Singleline),
         "AmsiStringLiteral", "High",
         "String literal containing 'amsi' in C# code"),
    ];

    // ── Public API ───────────────────────────────────────────────────────────

    /// <summary>
    /// Scans <paramref name="powerShellSource"/> for Add-Type C# blocks and
    /// analyses each block for suspicious patterns.
    /// </summary>
    public static CSharpScanResult Scan(string powerShellSource)
    {
        var blocks     = ExtractBlocks(powerShellSource);
        var indicators = new List<CSharpIndicator>();

        for (int i = 0; i < blocks.Count; i++)
        {
            var block = blocks[i];
            if (block.IsDynamic)
            {
                // Dynamic source — flag as medium, can't do deeper analysis
                indicators.Add(new CSharpIndicator(
                    "DynamicTypeDefinition", "Medium",
                    "Add-Type -TypeDefinition from a variable — content cannot be analysed statically",
                    "$variable", i));
                continue;
            }

            foreach (var (pattern, type, severity, description) in DetectionRules)
            {
                var m = pattern.Match(block.Content);
                if (!m.Success) continue;

                var matched = m.Value.Length > 120
                    ? m.Value[..120] + "..."
                    : m.Value;

                // Deduplicate within the same block: same type only once
                bool duplicate = false;
                foreach (var existing in indicators)
                {
                    if (existing.BlockIndex == i && existing.Type == type)
                    { duplicate = true; break; }
                }
                if (duplicate) continue;

                indicators.Add(new CSharpIndicator(type, severity, description, matched, i));
            }
        }

        return new CSharpScanResult(blocks, indicators);
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private static List<CSharpBlock> ExtractBlocks(string source)
    {
        var blocks = new List<CSharpBlock>();

        void AddBlock(Match m, int contentGroup, bool dynamic)
        {
            int line = CountLines(source, m.Index);
            var content = dynamic ? m.Groups[contentGroup].Value : m.Groups[contentGroup].Value;
            blocks.Add(new CSharpBlock(content, line, dynamic));
        }

        foreach (Match m in HereStringDouble.Matches(source))
            AddBlock(m, 1, false);

        foreach (Match m in HereStringSingle.Matches(source))
            AddBlock(m, 1, false);

        foreach (Match m in InlineDouble.Matches(source))
            AddBlock(m, 1, false);

        foreach (Match m in InlineSingle.Matches(source))
            AddBlock(m, 1, false);

        foreach (Match m in DynamicVariable.Matches(source))
        {
            int line = CountLines(source, m.Index);
            blocks.Add(new CSharpBlock(m.Groups[1].Value, line, IsDynamic: true));
        }

        return blocks;
    }

    /// Returns the 1-based line number of character at <paramref name="index"/>.
    private static int CountLines(string source, int index)
    {
        int line = 1;
        for (int i = 0; i < index && i < source.Length; i++)
            if (source[i] == '\n') line++;
        return line;
    }
}
