using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace PSParser;

/// <summary>
/// Statically folds string expressions to their literal value.
/// Handles direct literals and + concatenations of literals.
/// </summary>
public static class StringFolder
{
    /// <summary>
    /// Tries to fold an expression to a literal string value.
    /// Pass <paramref name="vars"/> (mapping $name → value) to enable constant propagation
    /// across variable assignments, e.g. $a="Ams"; $b="iSc"; $a+$b → "AmsiSc".
    /// </summary>
    public static string? TryFold(Expression? expr, Dictionary<string, string>? vars = null)
    {
        if (expr is StringLiteral str)
            return StripQuotes(str.Value);

        if (expr is VariableReference varRef && vars != null &&
            vars.TryGetValue(varRef.Name, out var known))
            return known;

        if (expr is BinaryExpression { Operator: "+" } bin)
        {
            var left  = TryFold(bin.Left, vars);
            var right = TryFold(bin.Right, vars);
            if (left != null && right != null) return left + right;
            if (left  != null) return left;
            if (right != null) return right;
        }

        return null;
    }

    private static string StripQuotes(string s)
    {
        if (s.Length >= 2 && (s[0] == '"' || s[0] == '\'') && s[^1] == s[0])
            return s[1..^1];
        return s;
    }
}

/// <summary>
/// Detects AMSI bypass attempts in PowerShell.
/// Combines AST visitor pattern with raw source scanning to handle obfuscated code.
/// </summary>
public class AmsiBypassDetector : IAstVisitor
{
    public AmsiBypassReport Report { get; } = new();

    // (pattern, indicatorType, severity)
    private static readonly (string Pattern, string Type, string Severity)[] StringIndicators =
    {
        ("System.Management.Automation.AmsiUtils", "ReflectionBypass", "Critical"),
        ("amsiInitFailed",  "ReflectionBypass", "Critical"),
        ("amsiContext",     "ReflectionBypass", "Critical"),
        ("AmsiScanBuffer",  "MemoryPatch",      "Critical"),
        ("AmsiInitialize",  "MemoryPatch",      "Critical"),
        ("amsiSession",     "ReflectionBypass", "Critical"),
        ("amsi.dll",        "AmsiDll",          "High"),
        ("AmsiOpenSession", "ApiCall",          "High"),
        ("AmsiCloseSession","ApiCall",          "High"),
    };

    private static readonly string[] MemoryPatchApis =
        { "VirtualProtect", "WriteProcessMemory", "VirtualAlloc" };

    // Patterns found in raw source (type names, method calls — not necessarily in quotes)
    private static readonly (string Pattern, string Type, string Severity, string Desc)[] RawSourceIndicators =
    {
        // Script block smuggling
        ("ScriptBlockAst]::new",
            "ScriptBlockSmuggling", "Critical",
            "ScriptBlockAst constructed manually — spoofed extent hides payload from AMSI"),
        (".GetScriptBlock()",
            "ScriptBlockSmuggling", "High",
            "GetScriptBlock() converts manipulated AST to executable block, bypassing AMSI scan"),
        // Hardware breakpoint bypass
        ("AMSI_RESULT_CLEAN",
            "HardwareBreakpoint", "Critical",
            "AMSI_RESULT_CLEAN constant used — hardware breakpoint intercepts AmsiScanBuffer and returns clean"),
        ("AddVectoredExceptionHandler",
            "HardwareBreakpoint", "Critical",
            "AddVectoredExceptionHandler sets hardware breakpoint on AmsiScanBuffer to intercept scan"),
        // Script block / provider logging disable
        ("cachedGroupPolicySettings",
            "LoggingBypass", "High",
            "cachedGroupPolicySettings modified — disables PowerShell script block logging"),
        ("System.Management.Automation.Utils",
            "LoggingBypass", "High",
            "System.Management.Automation.Utils accessed via reflection — used to modify logging/policy settings"),
    };

    private readonly HashSet<string> _seen = new(StringComparer.OrdinalIgnoreCase);
    // Constant propagation: tracks $var = "literal" assignments seen during AST walk
    private readonly Dictionary<string, string> _variables = new(StringComparer.OrdinalIgnoreCase);

    // ── raw source scan ──────────────────────────────────────────────────────

    /// <summary>
    /// Scans raw PowerShell source for AMSI patterns.
    /// Works even when the parser cannot handle the syntax (e.g. [Ref].Assembly...).
    /// Call this before or after visiting the AST.
    /// </summary>
    public void ScanSource(string source)
    {
        // 0. Scan full raw source text directly for every StringIndicator.
        //    Catches bare-word AMSI names in C# here-strings and unquoted PS arguments.
        ScanRawText(source);

        // 1. Find all string literals and +concatenations, fold, check
        foreach (var s in ExtractFoldedStrings(source))
            CheckValue(s, "string in source");

        // 2. Try to decode any base64 segments (≥20 chars)
        foreach (Match m in Regex.Matches(source, @"[A-Za-z0-9+/]{20,}={0,2}"))
        {
            var decoded = TryBase64Decode(m.Value);
            if (decoded != null)
                CheckValue(decoded, $"base64 decoded ({m.Value[..Math.Min(20, m.Value.Length)]}...)");
        }

        // 3. Check for reversed strings (unloadobfuscated technique):
        //    a quoted string that when reversed contains AMSI keywords
        foreach (Match m in Regex.Matches(source, @"""([^""]{15,})"""))
        {
            var rev = new string(m.Groups[1].Value.Reverse().ToArray());
            if (rev.Contains("amsi", StringComparison.OrdinalIgnoreCase))
                CheckValue(rev, "reversed string");
        }

        // 4. Variable-based concatenation: $a="Ams"; $b="iSc"; $a+$b → "AmsiScanBuffer"
        foreach (var s in ExtractVariableFoldedStrings(source))
            CheckValue(s, "variable-concatenated string");

        // 5. Detect memory-patching API calls in raw source
        foreach (var api in MemoryPatchApis)
        {
            if (source.Contains(api, StringComparison.OrdinalIgnoreCase))
                FlagApi(api, "MemoryPatch", "High",
                    $"{api} call detected — possible memory-patching bypass");
        }

        // 6. Raw-source keyword indicators: type names and method calls (not in quotes)
        foreach (var (pattern, type, severity, desc) in RawSourceIndicators)
        {
            if (source.Contains(pattern, StringComparison.OrdinalIgnoreCase))
                FlagApi(pattern, type, severity, desc);
        }

        // 7. DLL hijack combination: WriteAllBytes + amsi.dll = writing fake AMSI DLL
        if (source.Contains("WriteAllBytes", StringComparison.OrdinalIgnoreCase) &&
            source.Contains("amsi.dll", StringComparison.OrdinalIgnoreCase))
            FlagApi("WriteAllBytes+amsi.dll", "AmsiDllHijack", "Critical",
                "WriteAllBytes with amsi.dll path — writing fake AMSI DLL to disk (DLL hijack bypass)");

        // 8. PowerShell v2 downgrade — PS v2 has no AMSI
        if (Regex.IsMatch(source, @"powershell.*-v(ersion)?\s*2", RegexOptions.IgnoreCase))
            FlagApi("powershell -version 2", "PSv2Downgrade", "Critical",
                "PowerShell v2 downgrade — PS v2 has no AMSI support");

        // 9. ROT±1 char-shift cipher (CLR hooking: each char shifted by 1).
        //    Use [^"\r\n] to prevent matching across here-string boundaries.
        foreach (Match m in Regex.Matches(source, @"""([^""\r\n]{8,})"""))
        {
            var s = m.Groups[1].Value;
            var minus1 = new string(s.Select(c => (char)(c - 1)).ToArray());
            if (minus1.Contains("amsi", StringComparison.OrdinalIgnoreCase))
                CheckValue(minus1, "char-shifted string (ROT-1)");
            var plus1 = new string(s.Select(c => (char)(c + 1)).ToArray());
            if (plus1.Contains("amsi", StringComparison.OrdinalIgnoreCase))
                CheckValue(plus1, "char-shifted string (ROT+1)");
        }

        // 10. String .replace() chain evaluation: 'hello, world'.replace(...) → 'amsi.dll'
        var chainValues = ExtractReplaceChainStrings(source);
        foreach (var s in chainValues)
            CheckValue(s, "replace-chain string");
        // Also check pairwise concatenations from chain results ($string2+$string3 → AmsiScanBuffer)
        for (var i = 0; i < chainValues.Count; i++)
            for (var j = 0; j < chainValues.Count; j++)
                if (i != j && chainValues[i].Length + chainValues[j].Length <= 60)
                    CheckValue(chainValues[i] + chainValues[j], "replace-chain concat");

        // 11. Combination indicators: amsi.dll loaded + AMSI function targeted = clear bypass
        if (source.Contains("amsi.dll", StringComparison.OrdinalIgnoreCase))
        {
            if (source.Contains("AmsiOpenSession", StringComparison.OrdinalIgnoreCase))
                FlagApi("amsi.dll+AmsiOpenSession", "MemoryPatch", "Critical",
                    "amsi.dll + AmsiOpenSession — patching session function to bypass scanning");
            if (source.Contains("VirtualProtect", StringComparison.OrdinalIgnoreCase))
                FlagApi("amsi.dll+VirtualProtect", "MemoryPatch", "Critical",
                    "amsi.dll loaded + VirtualProtect — memory patching AMSI function in loaded DLL");
        }

        // 12. Script block logging explicitly disabled: cachedGroupPolicySettings + ScriptBlockLogging
        if (source.Contains("cachedGroupPolicySettings", StringComparison.OrdinalIgnoreCase) &&
            source.Contains("ScriptBlockLogging", StringComparison.OrdinalIgnoreCase))
            FlagApi("cachedGroupPolicySettings+ScriptBlockLogging", "LoggingBypass", "Critical",
                "cachedGroupPolicySettings + ScriptBlockLogging — PowerShell script block logging explicitly disabled");

        // 14. Execute FromBase64String("...") calls and inspect the decoded content.
        //     Catches .NET DLL payloads loaded via [Reflection.Assembly]::Load(...)
        var b64CallRx = new Regex(@"FromBase64String\s*\(\s*""([^""]+)""\s*\)", RegexOptions.IgnoreCase);
        foreach (Match b64m in b64CallRx.Matches(source))
        {
            var decodedDll = TryBase64Decode(b64m.Groups[1].Value);
            if (decodedDll != null)
                CheckValue(decodedDll, "FromBase64String decoded");
        }

        // 15. PowerShell -f format operator: reconstruct strings built via "{N}{M}" -f args
        //     Catches obfuscation like "{6}{3}{1}..." -f 'Util','A',... → "System.Management..."
        foreach (var fmtResult in ExtractFormatStringResults(source))
            CheckValue(fmtResult, "-f format operator result");
    }

    // ── string extraction helpers ────────────────────────────────────────────

    /// Scans the full raw source text for each StringIndicator.
    /// Catches bare-word AMSI names that aren't inside quoted strings
    /// (e.g. C# code inside PS here-strings, unquoted function arguments).
    private void ScanRawText(string source)
    {
        foreach (var (pattern, type, severity) in StringIndicators)
        {
            if (!source.Contains(pattern, StringComparison.OrdinalIgnoreCase)) continue;
            var idx   = source.IndexOf(pattern, StringComparison.OrdinalIgnoreCase);
            var start = Math.Max(0, idx - 20);
            var len   = Math.Min(source.Length - start, pattern.Length + 40);
            var ctx   = source[start..(start + len)].Replace('\n', ' ').Replace('\r', ' ');
            var key   = $"{type}:{pattern.ToLowerInvariant()}";
            if (_seen.Add(key))
                Report.AddIndicator(new AmsiIndicator
                {
                    Type        = type,
                    Severity    = severity,
                    Description = $"'{pattern}' detected in raw source",
                    MatchedValue = ctx
                });
        }
    }

    /// <summary>
    /// Evaluates $var = 'init'; $var = $var.replace('x','y') chains in source order.
    /// Catches patterns like: $s='hello, world'; $s=$s.replace('he','a')... → 'amsi.dll'
    /// </summary>
    private static List<string> ExtractReplaceChainStrings(string source)
    {
        var vars = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        // Collect all init and replace operations in source order
        var initRx    = new Regex(@"\$(\w+)\s*=\s*(?:'([^']*)'|""([^""]*)"")\s*$",
                                  RegexOptions.Multiline);
        var replaceRx = new Regex(
            @"\$(\w+)\s*=\s*\$(\w+)\s*\.\s*replace\s*\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)",
            RegexOptions.IgnoreCase);

        var ops = new List<(int Pos, bool IsInit, string Var, string Src, string A, string B)>();
        foreach (Match m in initRx.Matches(source))
            ops.Add((m.Index, true, m.Groups[1].Value, "",
                m.Groups[2].Success ? m.Groups[2].Value : m.Groups[3].Value, ""));
        foreach (Match m in replaceRx.Matches(source))
            ops.Add((m.Index, false, m.Groups[1].Value, m.Groups[2].Value,
                m.Groups[3].Value, m.Groups[4].Value));

        ops.Sort((a, b) => a.Pos.CompareTo(b.Pos));

        foreach (var (_, isInit, var, src, a, b) in ops)
        {
            if (isInit)
                vars[var] = a;
            else if (string.Equals(var, src, StringComparison.OrdinalIgnoreCase) &&
                     vars.TryGetValue(var, out var val))
                vars[var] = val.Replace(a, b);
        }

        return [.. vars.Values];
    }

    /// <summary>
    /// Source-level constant propagation: resolves $var assignments to literals,
    /// then folds any variable+variable or variable+literal concatenations.
    /// Catches patterns like: $a="Ams"; $b="iSc"; ... GetBytes($a+$b+$c+$d)
    /// </summary>
    private static List<string> ExtractVariableFoldedStrings(string source)
    {
        var vars = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        // Collect $var = "literal" or $var = 'literal'
        var assignRx = new Regex(@"\$(\w+)\s*=\s*(?:'([^']*)'|""([^""]*)"")");
        foreach (Match m in assignRx.Matches(source))
        {
            var name = "$" + m.Groups[1].Value;
            var val  = m.Groups[2].Success ? m.Groups[2].Value : m.Groups[3].Value;
            vars[name] = val;
        }

        if (vars.Count == 0) return [];

        var results = new List<string>();

        // Find expressions that mix $vars and/or literals joined by +
        var concatRx = new Regex(
            @"(?:\$\w+|'[^']*'|""[^""]*"")(?:\s*\+\s*(?:\$\w+|'[^']*'|""[^""]*""))+");
        foreach (Match m in concatRx.Matches(source))
        {
            var parts = Regex.Matches(m.Value, @"\$(\w+)|'([^']*)'|""([^""]*)""");
            var sb = new StringBuilder();
            var hasVar      = false;
            var allResolved = true;

            foreach (Match p in parts)
            {
                if (p.Groups[1].Success) // $variable
                {
                    hasVar = true;
                    if (vars.TryGetValue("$" + p.Groups[1].Value, out var v))
                        sb.Append(v);
                    else { allResolved = false; break; }
                }
                else // quoted literal
                {
                    sb.Append(p.Groups[2].Success ? p.Groups[2].Value : p.Groups[3].Value);
                }
            }

            if (hasVar && allResolved && sb.Length > 0)
                results.Add(sb.ToString());
        }

        return results;
    }

    private static List<string> ExtractFoldedStrings(string source)
    {
        var results = new List<string>();

        // Match sequences of single/double-quoted strings joined by +
        // e.g.  'amsiInit'+'Failed'  or  "System.Management."+"Automation.AmsiUtils"
        var seqPattern = new Regex(
            @"(?:(?:'[^']*'|""[^""]*"")\s*\+\s*)*(?:'[^']*'|""[^""]*"")");

        foreach (Match m in seqPattern.Matches(source))
        {
            var parts = Regex.Matches(m.Value, @"'([^']*)'|""([^""]*)""");
            var sb = new StringBuilder();
            foreach (Match p in parts)
                sb.Append(p.Groups[1].Success ? p.Groups[1].Value : p.Groups[2].Value);
            if (sb.Length > 0)
                results.Add(sb.ToString());
        }

        return results;
    }

    // ── PowerShell -f format operator evaluator ─────────────────────────────

    /// Finds all "{N}" -f args expressions in source and returns the evaluated strings.
    private static List<string> ExtractFormatStringResults(string source)
    {
        var results = new List<string>();
        var fmtRx = new Regex(@"""([^""\r\n]*\{\d+\}[^""\r\n]*)""\s*-[fF]\s*", RegexOptions.IgnoreCase);
        foreach (Match m in fmtRx.Matches(source))
        {
            var fmt     = m.Groups[1].Value;
            var argsStr = CaptureArgsString(source, m.Index + m.Length);
            if (argsStr.Length == 0) continue;
            var argList = SplitTopLevelCommas(argsStr);
            var args    = argList.Select(a => (object)(EvalPSExpr(a) ?? "")).ToArray();
            try { results.Add(string.Format(fmt, args)); }
            catch { }
        }
        return results;
    }

    /// Captures the args string starting at 'start', stopping at unmatched ')' or end-of-statement.
    private static string CaptureArgsString(string source, int start)
    {
        var sb = new StringBuilder();
        int depth = 0;
        bool inS = false, inD = false;
        for (int i = start; i < source.Length; i++)
        {
            char c = source[i];
            if (!inS && !inD)
            {
                if      (c == '(') depth++;
                else if (c == ')') { if (depth == 0) break; depth--; }
                else if (c == '\'') inS = true;
                else if (c == '"')  inD = true;
                else if (depth == 0 && (c == ';' || c == '\n')) break;
            }
            else if (inS && c == '\'') inS = false;
            else if (inD && c == '"')  inD = false;
            sb.Append(c);
        }
        return sb.ToString().Trim();
    }

    /// Evaluates a PS string expression: handles literals, + concat, and -f format operator.
    private static string? EvalPSExpr(string s)
    {
        s = s.Trim();
        if (s.Length == 0) return null;

        while (IsFullyWrapped(s))
            s = s[1..^1].Trim();
        if (s.Length == 0) return null;

        // -f has lower precedence than +; find it first
        int fIdx = FindFmtOp(s);
        if (fIdx >= 0)
        {
            var fmtStr = EvalPSExpr(s[..fIdx]);
            if (fmtStr == null) return null;
            var argList = SplitTopLevelCommas(CaptureArgsString(s, fIdx + 2));
            var args    = argList.Select(a => (object)(EvalPSExpr(a) ?? "")).ToArray();
            try { return string.Format(fmtStr, args); }
            catch { return null; }
        }

        int plusIdx = FindTopLevelChar(s, '+');
        if (plusIdx >= 0)
        {
            var left  = EvalPSExpr(s[..plusIdx]);
            var right = EvalPSExpr(s[(plusIdx + 1)..]);
            if (left != null && right != null) return left + right;
            return left ?? right;
        }

        if (s.Length >= 2)
        {
            if (s[0] == '"'  && s[^1] == '"')  return s[1..^1];
            if (s[0] == '\'' && s[^1] == '\'') return s[1..^1];
        }
        return null;
    }

    private static bool IsFullyWrapped(string s)
    {
        if (s.Length < 2 || s[0] != '(') return false;
        int depth = 0;
        bool inS = false, inD = false;
        for (int i = 0; i < s.Length; i++)
        {
            char c = s[i];
            if (!inS && !inD)
            {
                if      (c == '(')  depth++;
                else if (c == ')')  { if (--depth == 0) return i == s.Length - 1; }
                else if (c == '\'') inS = true;
                else if (c == '"')  inD = true;
            }
            else if (inS && c == '\'') inS = false;
            else if (inD && c == '"')  inD = false;
        }
        return false;
    }

    // Returns index of top-level -f operator (case-insensitive), or -1.
    private static int FindFmtOp(string s)
    {
        int depth = 0;
        bool inS = false, inD = false;
        for (int i = 0; i < s.Length - 1; i++)
        {
            char c = s[i];
            if (!inS && !inD)
            {
                if      (c == '(')  depth++;
                else if (c == ')')  depth--;
                else if (c == '\'') inS = true;
                else if (c == '"')  inD = true;
                else if (depth == 0 && c == '-' && char.ToLowerInvariant(s[i + 1]) == 'f')
                {
                    int after = i + 2;
                    if (after >= s.Length || !char.IsLetterOrDigit(s[after]))
                        return i;
                }
            }
            else if (inS && c == '\'') inS = false;
            else if (inD && c == '"')  inD = false;
        }
        return -1;
    }

    // Returns index of first top-level occurrence of target, or -1.
    private static int FindTopLevelChar(string s, char target)
    {
        int depth = 0;
        bool inS = false, inD = false;
        for (int i = 0; i < s.Length; i++)
        {
            char c = s[i];
            if (!inS && !inD)
            {
                if      (c == '(')  depth++;
                else if (c == ')')  depth--;
                else if (c == '\'') inS = true;
                else if (c == '"')  inD = true;
                else if (depth == 0 && c == target) return i;
            }
            else if (inS && c == '\'') inS = false;
            else if (inD && c == '"')  inD = false;
        }
        return -1;
    }

    private static List<string> SplitTopLevelCommas(string s)
    {
        var parts = new List<string>();
        int depth = 0, start = 0;
        bool inS = false, inD = false;
        for (int i = 0; i < s.Length; i++)
        {
            char c = s[i];
            if (!inS && !inD)
            {
                if      (c == '(')  depth++;
                else if (c == ')')  depth--;
                else if (c == '\'') inS = true;
                else if (c == '"')  inD = true;
                else if (depth == 0 && c == ',') { parts.Add(s[start..i].Trim()); start = i + 1; }
            }
            else if (inS && c == '\'') inS = false;
            else if (inD && c == '"')  inD = false;
        }
        parts.Add(s[start..].Trim());
        return parts;
    }

    private static string? TryBase64Decode(string s)
    {
        try
        {
            var bytes   = Convert.FromBase64String(s);
            var decoded = Encoding.UTF8.GetString(bytes);
            if (!decoded.Any(c => c < 32 && c != '\n' && c != '\r' && c != '\t'))
                return decoded;
            if (bytes.Length > 512 * 1024) return null;
            var ascii = Encoding.ASCII.GetString(bytes);
            // .NET DLL binaries store string literals as UTF-16LE in the #US section.
            // Decode as Unicode and strip control chars to surface those strings.
            var utf16 = new string(Encoding.Unicode.GetString(bytes).Where(c => c >= 0x20).ToArray());
            return ascii + "\n" + utf16;
        }
        catch { return null; }
    }

    // ── indicator helpers ────────────────────────────────────────────────────

    private void CheckValue(string value, string context)
    {
        foreach (var (pattern, type, severity) in StringIndicators)
        {
            if (!value.Contains(pattern, StringComparison.OrdinalIgnoreCase))
                continue;

            var key = $"{type}:{pattern.ToLowerInvariant()}";
            if (_seen.Add(key))
            {
                Report.AddIndicator(new AmsiIndicator
                {
                    Type        = type,
                    Severity    = severity,
                    Description = $"'{pattern}' detected in {context}",
                    MatchedValue = value.Length > 100 ? value[..100] + "..." : value
                });
            }
        }
    }

    private void FlagApi(string api, string type, string severity, string description)
    {
        var key = $"{type}:{api.ToLowerInvariant()}";
        if (_seen.Add(key))
        {
            Report.AddIndicator(new AmsiIndicator
            {
                Type        = type,
                Severity    = severity,
                Description = description,
                MatchedValue = api
            });
        }
    }

    // ── IAstVisitor ──────────────────────────────────────────────────────────

    public void VisitStringLiteral(StringLiteral node)
    {
        var v = StringFolder.TryFold(node);
        if (v != null) CheckValue(v, "string literal");
    }

    public void VisitBinaryExpression(BinaryExpression node)
    {
        if (node.Operator == "+")
        {
            // Pass _variables so $a+"iSc" resolves when $a was assigned earlier
            var folded = StringFolder.TryFold(node, _variables);
            if (folded != null) CheckValue(folded, "concatenated string");
        }
        node.Left?.Accept(this);
        node.Right?.Accept(this);
    }

    public void VisitFunctionCall(FunctionCall node)
    {
        var name = node.FunctionName;

        // Check for AMSI-related Win32 API calls
        if (name.Equals("LoadLibrary", StringComparison.OrdinalIgnoreCase) ||
            name.Equals("GetProcAddress", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var arg in node.Arguments)
            {
                var val = StringFolder.TryFold(arg);
                if (val != null) CheckValue(val, $"{name}() argument");
            }
        }

        if (MemoryPatchApis.Contains(name, StringComparer.OrdinalIgnoreCase))
            FlagApi(name, "MemoryPatch", "High",
                $"{name} call detected — possible memory-patching bypass");

        foreach (var arg in node.Arguments)
            arg?.Accept(this);
    }

    public void VisitNumberLiteral(NumberLiteral node) { }
    public void VisitBooleanLiteral(BooleanLiteral node) { }
    public void VisitVariableReference(VariableReference node) { }

    public void VisitPipelineExpression(PipelineExpression node)
    {
        foreach (var s in node.Segments) s?.Accept(this);
    }

    public void VisitExpressionStatement(ExpressionStatement node)
        => node.Expression?.Accept(this);

    public void VisitAssignmentStatement(AssignmentStatement node)
    {
        // Constant propagation: if RHS folds to a literal, remember it for later
        var val = StringFolder.TryFold(node.Value, _variables);
        if (val != null)
            _variables[node.VariableName] = val;

        node.Value?.Accept(this);
    }

    public void VisitIfStatement(IfStatement node)
    {
        node.Condition?.Accept(this);
        foreach (var s in node.ThenBranch) s?.Accept(this);
        foreach (var s in node.ElseBranch) s?.Accept(this);
    }

    public void VisitFunctionDefinition(FunctionDefinition node)
    {
        foreach (var s in node.Body) s?.Accept(this);
    }

    public void VisitScriptBlock(ScriptBlock node)
    {
        foreach (var s in node.Statements) s?.Accept(this);
    }
}

public class AmsiIndicator
{
    public string Type         { get; set; } = "";
    public string Severity     { get; set; } = "";
    public string Description  { get; set; } = "";
    public string MatchedValue { get; set; } = "";
}

public class AmsiBypassReport
{
    public List<AmsiIndicator> Indicators   { get; } = new();
    public bool                IsAmsiBypass => Indicators.Any(i => i.Severity == "Critical");
    public int                 ConfidenceScore { get; private set; }

    public void AddIndicator(AmsiIndicator ind)
    {
        Indicators.Add(ind);
        ConfidenceScore = Math.Min(100, Indicators.Sum(i => i.Severity switch
        {
            "Critical" => 40,
            "High"     => 20,
            "Medium"   => 10,
            _          => 5
        }));
    }

    public override string ToString()
    {
        var sb = new StringBuilder();
        sb.AppendLine($"AMSI Bypass: {(IsAmsiBypass ? "*** DETECTED ***" : "Not detected")}");
        sb.AppendLine($"Confidence : {ConfidenceScore}/100");
        sb.AppendLine($"Indicators : {Indicators.Count}");
        foreach (var i in Indicators)
            sb.AppendLine($"  [{i.Severity}] {i.Type}: {i.Description}");
        return sb.ToString();
    }
}
