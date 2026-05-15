using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace PSParser;

/// <summary>
/// Safe string evaluator - rozwijanie stringów bez execution
/// </summary>
public class StringEvaluator
{
    private readonly Dictionary<string, string> _variables = new(StringComparer.OrdinalIgnoreCase);
    private const int MaxStringLength = 100_000;
    private const int MaxIterations = 100;

    public void SetVariable(string name, string value)
    {
        _variables[name] = value;
    }

    /// <summary>
    /// Bezpiecznie rozwijamy expandowalny string
    /// </summary>
    public string EvaluateExpandableString(StringLiteral stringLiteral)
    {
        if (!stringLiteral.IsExpandable)
            return UnquoteString(stringLiteral.Value);

        var result = new StringBuilder();

        foreach (var segment in stringLiteral.InterpolationSegments)
        {
            if (segment.Type == "text")
            {
                result.Append(segment.Content);
            }
            else if (segment.Type == "variable")
            {
                string varName = segment.Content.StartsWith("$") ? segment.Content[1..] : segment.Content;

                if (_variables.TryGetValue(varName, out var value))
                {
                    segment.EvaluatedValue = value;
                    result.Append(value);
                }
                else
                {
                    // Variable nie istnieje - zostaw placeholder
                    segment.EvaluatedValue = $"${{{varName}}}";
                }
            }
        }

        return result.ToString();
    }

    /// <summary>
    /// Usuwamy cudzysłowy z stringa
    /// </summary>
    private string UnquoteString(string value)
    {
        if ((value.StartsWith("\"") && value.EndsWith("\"")) ||
            (value.StartsWith("'") && value.EndsWith("'")))
        {
            return value[1..^1];
        }
        return value;
    }

    /// <summary>
    /// Próbujemy dekodować łańcuchy Base64
    /// </summary>
    public string TryDecodeBase64(string input)
    {
        try
        {
            // Check if looks like Base64
            if (input.Length % 4 != 0)
                return null;

            if (!Regex.IsMatch(input, @"^[A-Za-z0-9+/]*={0,2}$"))
                return null;

            byte[] data = Convert.FromBase64String(input);
            string result = Encoding.UTF8.GetString(data);

            // Validate that result looks reasonable
            if (result.Length > MaxStringLength)
                return null;

            return result;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Rozwijamy zagnieżdżone kodowanie (Base64 -> Base64 -> ...)
    /// </summary>
    public List<string> DeobfuscateNestedEncoding(string input)
    {
        var results = new List<string> { input };
        string current = input;
        int iterations = 0;

        while (iterations < MaxIterations)
        {
            string decoded = TryDecodeBase64(current);

            if (decoded == null)
                break;

            // Check if it's actually valid text or more encoding
            if (decoded.Equals(current, StringComparison.Ordinal))
                break;

            results.Add(decoded);
            current = decoded;
            iterations++;

            // If we hit plaintext that looks like code, stop
            if (HasCodePatterns(decoded))
                break;
        }

        return results;
    }

    private bool HasCodePatterns(string text)
    {
        // Check for PowerShell keywords
        var keywords = new[] { "function", "param", "return", "if", "for", "foreach", "while", "try", "catch" };
        var lowerText = text.ToLower();

        return keywords.Any(k => lowerText.Contains(k));
    }

    // ── Technique 1: [char] cast / char array deobfuscation ─────────────────

    /// <summary>
    /// Evaluates [char]0x41 or [char]65 expressions, returning the character string.
    /// Returns null if the pattern is not recognized or fails.
    /// </summary>
    public static string? TryEvalCharCast(string input)
    {
        try
        {
            input = input.Trim();
            var m = Regex.Match(input, @"^\[char\]\s*(?:0x([0-9a-fA-F]+)|(\d+))$",
                RegexOptions.IgnoreCase);
            if (!m.Success) return null;

            int codePoint = m.Groups[1].Success
                ? Convert.ToInt32(m.Groups[1].Value, 16)
                : int.Parse(m.Groups[2].Value);

            if (codePoint < 0 || codePoint > 0x10FFFF) return null;
            return char.ConvertFromUtf32(codePoint);
        }
        catch { return null; }
    }

    /// <summary>
    /// Evaluates [char[]]@(65,109,115,105) or -join([char[]](65,109,115,105)) style expressions.
    /// Returns the resulting string, or null if pattern is not recognized.
    /// </summary>
    public static string? TryEvalCharArray(string input)
    {
        try
        {
            input = input.Trim();

            // Strip optional leading -join or (-join ... )
            var joinPrefix = Regex.Match(input,
                @"^-join\s*\(?\s*\[char\[\]\]\s*@?\s*\(([^)]+)\)\s*\)?$",
                RegexOptions.IgnoreCase);
            if (joinPrefix.Success)
                return CharArrayFromNumberList(joinPrefix.Groups[1].Value);

            // [char[]]@(65,...) or [char[]](65,...) with optional trailing -join '' / -join ""
            var plain = Regex.Match(input,
                @"^\[char\[\]\]\s*@?\s*\(([^)]+)\)(?:\s*-join\s*(?:''|""\s*""))?$",
                RegexOptions.IgnoreCase);
            if (plain.Success)
                return CharArrayFromNumberList(plain.Groups[1].Value);

            return null;
        }
        catch { return null; }
    }

    private static string? CharArrayFromNumberList(string list)
    {
        try
        {
            var parts = list.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var sb = new StringBuilder();
            foreach (var part in parts)
            {
                int v = part.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
                    ? Convert.ToInt32(part, 16)
                    : int.Parse(part);
                if (v < 0 || v > 0x10FFFF) return null;
                sb.Append(char.ConvertFromUtf32(v));
            }
            return sb.ToString();
        }
        catch { return null; }
    }

    // ── Technique 2: XOR deobfuscation ──────────────────────────────────────

    /// <summary>
    /// Evaluates patterns like:
    ///   $e=@(0x62,0xcc,...); $e|%{[char]($_-bxor 0x03)}
    ///   -join($encoded | % { [char]($_ -bxor $key) })
    /// Returns the decoded string if printable (>80% printable ASCII), else null.
    /// </summary>
    public static string? TryEvalXor(string input)
    {
        try
        {
            // Extract byte array values
            var bytesMatch = Regex.Match(input,
                @"@\s*\(([0-9a-fA-F\s,x]+)\)",
                RegexOptions.IgnoreCase);
            if (!bytesMatch.Success) return null;

            var byteList = bytesMatch.Groups[1].Value
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(s => s.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
                    ? Convert.ToByte(s[2..], 16)
                    : byte.Parse(s))
                .ToArray();

            if (byteList.Length == 0) return null;

            // Extract XOR key — look for -bxor followed by a literal
            var keyMatch = Regex.Match(input,
                @"-bxor\s*(?:0x([0-9a-fA-F]+)|(\d+))",
                RegexOptions.IgnoreCase);
            if (!keyMatch.Success) return null;

            int key = keyMatch.Groups[1].Success
                ? Convert.ToInt32(keyMatch.Groups[1].Value, 16)
                : int.Parse(keyMatch.Groups[2].Value);

            var decoded = new StringBuilder();
            foreach (var b in byteList)
                decoded.Append((char)(b ^ key));

            var result = decoded.ToString();

            // Validate: >80% printable ASCII
            int printable = result.Count(c => c >= 0x20 && c <= 0x7E);
            if (result.Length == 0 || (double)printable / result.Length < 0.8)
                return null;

            return result;
        }
        catch { return null; }
    }

    // ── Technique 3: Unicode/hex escape deobfuscation ───────────────────────

    /// <summary>
    /// Evaluates PowerShell 6+ unicode escape sequences: `u{0041} → 'A'.
    /// Returns null if no such sequences are found.
    /// </summary>
    public static string? TryEvalUnicodeEscape(string input)
    {
        try
        {
            if (!Regex.IsMatch(input, @"`u\{[0-9a-fA-F]+\}", RegexOptions.IgnoreCase))
                return null;

            var result = Regex.Replace(input,
                @"`u\{([0-9a-fA-F]+)\}",
                m =>
                {
                    int codePoint = Convert.ToInt32(m.Groups[1].Value, 16);
                    return char.ConvertFromUtf32(codePoint);
                },
                RegexOptions.IgnoreCase);

            return result;
        }
        catch { return null; }
    }
}

/// <summary>
/// Detektor obfuscacji - identyfikuje techniki ukrycia
/// </summary>
public class ObfuscationDetector : IAstVisitor
{
    public ObfuscationReport Report { get; private set; } = new();

    // Constant propagation: $var → known literal value (populated by VisitAssignmentStatement)
    private readonly Dictionary<string, string> _variables = new(StringComparer.OrdinalIgnoreCase);

    // Deduplication key set for indicators added during AST walk
    private readonly HashSet<string> _seen = new(StringComparer.OrdinalIgnoreCase);

    // ── obfuscation keyword sets ─────────────────────────────────────────────

    private static readonly string[] SuspiciousFunctions =
        { "Invoke-Expression", "IEX", "Invoke-WebRequest", "iwr", "New-Object",
          "Invoke-Command", "Start-Process", "DownloadString", "DownloadFile",
          "EncodedCommand", "FromBase64String", "GetMethod", "Invoke" };

    // ── raw source scan ──────────────────────────────────────────────────────

    /// <summary>
    /// Scans raw PowerShell source for obfuscation patterns independently of the parser.
    /// Should be called before or after AST traversal.
    /// </summary>
    public void ScanSource(string source)
    {
        if (string.IsNullOrEmpty(source)) return;

        ScanBase64Blobs(source);
        ScanCharCasts(source);
        ScanXorPatterns(source);
        ScanUnicodeEscapes(source);
        ScanReversedStrings(source);
        ScanFormatOperator(source);
        ScanReplaceChains(source);
        ScanExcessiveConcatenation(source);
        ScanSuspiciousFunctionCalls(source);
    }

    // ── raw scan helpers ─────────────────────────────────────────────────────

    private void ScanBase64Blobs(string source)
    {
        try
        {
            // Find base64 blobs of at least 20 chars that can be decoded to readable text
            foreach (Match m in Regex.Matches(source, @"[A-Za-z0-9+/]{20,}={0,2}"))
            {
                var decoded = TryBase64Decode(m.Value);
                if (decoded != null)
                    FlagOnce("Base64Encoding", "High",
                        $"Base64-encoded content detected: '{Truncate(m.Value, 40)}' → '{Truncate(decoded, 40)}'",
                        $"Base64Encoding:{m.Value[..Math.Min(20, m.Value.Length)].ToLowerInvariant()}");
            }

            // Explicit FromBase64String("...") calls
            foreach (Match m in Regex.Matches(source,
                @"FromBase64String\s*\(\s*""([^""]+)""\s*\)", RegexOptions.IgnoreCase))
            {
                var decoded = TryBase64Decode(m.Groups[1].Value);
                FlagOnce("Base64Encoding", "High",
                    $"FromBase64String call with literal argument: '{Truncate(m.Groups[1].Value, 40)}'",
                    $"Base64Encoding:fromb64:{m.Groups[1].Value[..Math.Min(20, m.Groups[1].Value.Length)].ToLowerInvariant()}");
            }
        }
        catch { }
    }

    private void ScanCharCasts(string source)
    {
        try
        {
            // Sequences of adjacent [char]N / [char]0xNN joined by + or ,
            var singleMatches = Regex.Matches(source,
                @"\[char\]\s*(?:0x[0-9a-fA-F]+|\d+)", RegexOptions.IgnoreCase);

            if (singleMatches.Count > 0)
            {
                var sb = new StringBuilder();
                int prevEnd = -1;
                int count = 0;

                foreach (Match m in singleMatches)
                {
                    if (prevEnd >= 0)
                    {
                        var gap = source[prevEnd..m.Index];
                        if (!Regex.IsMatch(gap, @"^[\s+,]*$"))
                        {
                            if (sb.Length >= 3)
                            {
                                FlagOnce("CharCastObfuscation", "High",
                                    $"[char] cast sequence ({count} chars) decoded: '{Truncate(sb.ToString(), 60)}'",
                                    $"CharCast:{sb.ToString().ToLowerInvariant()[..Math.Min(30, sb.Length)]}");
                            }
                            sb.Clear();
                            count = 0;
                        }
                    }
                    var ch = StringEvaluator.TryEvalCharCast(m.Value);
                    if (ch != null) { sb.Append(ch); count++; }
                    prevEnd = m.Index + m.Length;
                }

                if (sb.Length >= 3)
                    FlagOnce("CharCastObfuscation", "High",
                        $"[char] cast sequence ({count} chars) decoded: '{Truncate(sb.ToString(), 60)}'",
                        $"CharCast:{sb.ToString().ToLowerInvariant()[..Math.Min(30, sb.Length)]}");
            }

            // [char[]] array expressions
            foreach (Match m in Regex.Matches(source,
                @"(?:-join\s*\(?\s*)?\[char\[\]\]\s*@?\s*\([^)]+\)(?:\s*\))?(?:\s*-join\s*(?:''|""\s*""))?",
                RegexOptions.IgnoreCase))
            {
                var decoded = StringEvaluator.TryEvalCharArray(m.Value);
                if (decoded != null && decoded.Length >= 2)
                    FlagOnce("CharArrayObfuscation", "High",
                        $"[char[]] array expression decoded: '{Truncate(decoded, 60)}'",
                        $"CharArray:{decoded.ToLowerInvariant()[..Math.Min(30, decoded.Length)]}");
            }
        }
        catch { }
    }

    private void ScanXorPatterns(string source)
    {
        try
        {
            // Inline: @(bytes) and -bxor key in same expression
            foreach (Match m in Regex.Matches(source,
                @"@\s*\([0-9a-fA-F\s,x]+\)[^;\r\n]{0,120}-bxor\s*(?:0x[0-9a-fA-F]+|\d+)",
                RegexOptions.IgnoreCase))
            {
                var decoded = StringEvaluator.TryEvalXor(m.Value);
                if (decoded != null)
                    FlagOnce("XorObfuscation", "High",
                        $"XOR-decoded byte array: '{Truncate(decoded, 60)}'",
                        $"XorObf:{decoded.ToLowerInvariant()[..Math.Min(30, decoded.Length)]}");
            }

            // Cross-product: collect all byte arrays and keys in source
            var byteArrays = new List<byte[]>();
            foreach (Match m in Regex.Matches(source,
                @"@\s*\(((?:\s*(?:0x[0-9a-fA-F]+|\d+)\s*,?\s*)+)\)", RegexOptions.IgnoreCase))
            {
                var arr = ParseByteList(m.Groups[1].Value);
                if (arr != null && arr.Length >= 4)
                    byteArrays.Add(arr);
            }

            var xorKeys = new List<int>();
            foreach (Match m in Regex.Matches(source,
                @"-bxor\s*(?:0x([0-9a-fA-F]+)|(\d+))", RegexOptions.IgnoreCase))
            {
                int key = m.Groups[1].Success
                    ? Convert.ToInt32(m.Groups[1].Value, 16)
                    : int.Parse(m.Groups[2].Value);
                if (!xorKeys.Contains(key))
                    xorKeys.Add(key);
            }

            foreach (var arr in byteArrays)
            {
                foreach (var key in xorKeys)
                {
                    var sb = new StringBuilder();
                    foreach (var b in arr) sb.Append((char)(b ^ key));
                    var result = sb.ToString();
                    int printable = result.Count(c => c >= 0x20 && c <= 0x7E);
                    if (result.Length == 0 || (double)printable / result.Length < 0.8) continue;

                    FlagOnce("XorObfuscation", "High",
                        $"XOR-decoded byte array (key=0x{key:X2}): '{Truncate(result, 60)}'",
                        $"XorObf:{result.ToLowerInvariant()[..Math.Min(30, result.Length)]}");
                }
            }
        }
        catch { }
    }

    private void ScanUnicodeEscapes(string source)
    {
        try
        {
            if (!Regex.IsMatch(source, @"`u\{[0-9a-fA-F]+\}", RegexOptions.IgnoreCase))
                return;

            FlagOnce("UnicodeEscapeObfuscation", "Medium",
                "PowerShell `u{NNNN} unicode escape sequences detected",
                "UnicodeEscape:present");

            // Decode sequences and check content
            foreach (Match m in Regex.Matches(source,
                @"(?:`u\{[0-9a-fA-F]+\})+", RegexOptions.IgnoreCase))
            {
                var decoded = StringEvaluator.TryEvalUnicodeEscape(m.Value);
                if (decoded != null && decoded.Length >= 2)
                    FlagOnce("UnicodeEscapeObfuscation", "Medium",
                        $"Unicode escape sequence decoded: '{Truncate(decoded, 60)}'",
                        $"UnicodeEscape:{decoded.ToLowerInvariant()[..Math.Min(30, decoded.Length)]}");
            }
        }
        catch { }
    }

    private void ScanReversedStrings(string source)
    {
        try
        {
            var suspiciousKeywords = new[]
            {
                "invoke", "iex", "bypass", "payload", "shellcode",
                "loadlibrary", "virtualprotect", "writeprocessmemory",
                "reflection", "assembly", "scriptblock", "amsi", "download"
            };

            // "string"[-1..-N] -join '' pattern
            foreach (Match m in Regex.Matches(source,
                @"""([^""\r\n]{6,})""\s*\[-1\s*\.\.-\s*\d+\]", RegexOptions.IgnoreCase))
            {
                var reversed = new string(m.Groups[1].Value.Reverse().ToArray());
                if (suspiciousKeywords.Any(k => reversed.Contains(k, StringComparison.OrdinalIgnoreCase)))
                    FlagOnce("ReversedStringObfuscation", "Medium",
                        $"Reversed string slice detected, decoded: '{Truncate(reversed, 60)}'",
                        $"RevStr:{reversed.ToLowerInvariant()[..Math.Min(30, reversed.Length)]}");
            }

            // Bare quoted strings that reverse to something suspicious
            foreach (Match m in Regex.Matches(source, @"""([^""\r\n]{8,})"""))
            {
                var reversed = new string(m.Groups[1].Value.Reverse().ToArray());
                if (suspiciousKeywords.Any(k => reversed.Contains(k, StringComparison.OrdinalIgnoreCase)))
                    FlagOnce("ReversedStringObfuscation", "Medium",
                        $"Reversed string detected, decoded: '{Truncate(reversed, 60)}'",
                        $"RevStr:{reversed.ToLowerInvariant()[..Math.Min(30, reversed.Length)]}");
            }
        }
        catch { }
    }

    private void ScanFormatOperator(string source)
    {
        try
        {
            // PowerShell -f format operator: "{0}{1}" -f 'foo','bar' → 'foobar'
            // Flag when result contains suspicious content or when format args are split to avoid detection
            var fmtMatches = Regex.Matches(source,
                @"""[^""\r\n]*\{\d+\}[^""\r\n]*""\s*-[fF]\s*", RegexOptions.IgnoreCase);
            if (fmtMatches.Count > 0)
                FlagOnce("FormatOperatorObfuscation", "Medium",
                    $"PowerShell -f format operator used {fmtMatches.Count} time(s) — possible string reconstruction",
                    "FmtOp:present");
        }
        catch { }
    }

    private void ScanReplaceChains(string source)
    {
        try
        {
            // Multiple chained .replace() calls on same variable → string building obfuscation
            var replaceMatches = Regex.Matches(source,
                @"\$\w+\s*=\s*\$\w+\s*\.\s*replace\s*\(", RegexOptions.IgnoreCase);
            if (replaceMatches.Count >= 2)
                FlagOnce("ReplaceChainObfuscation", "Medium",
                    $"Chained .replace() operations ({replaceMatches.Count}) detected — possible string-building obfuscation",
                    "ReplaceChain:present");
        }
        catch { }
    }

    private void ScanExcessiveConcatenation(string source)
    {
        try
        {
            // Count string concatenation operations (quoted literal + quoted literal)
            int concatCount = Regex.Matches(source,
                @"(?:'[^']*'|""[^""]*"")\s*\+\s*(?:'[^']*'|""[^""]*)").Count;
            if (concatCount >= 5)
                FlagOnce("ExcessiveConcatenation", "Medium",
                    $"Excessive string concatenation detected ({concatCount} literal + literal operations)",
                    "ExcessConcat:present");
        }
        catch { }
    }

    private void ScanSuspiciousFunctionCalls(string source)
    {
        try
        {
            foreach (var fn in SuspiciousFunctions)
            {
                if (Regex.IsMatch(source, @"\b" + Regex.Escape(fn) + @"\b", RegexOptions.IgnoreCase))
                    FlagOnce("SuspiciousFunction", "High",
                        $"Suspicious function/command reference: {fn}",
                        $"SuspFn:{fn.ToLowerInvariant()}");
            }
        }
        catch { }
    }

    // ── indicator helpers ────────────────────────────────────────────────────

    private void FlagOnce(string type, string severity, string description, string dedupeKey)
    {
        if (_seen.Add(dedupeKey))
            Report.AddIndicator(new ObfuscationIndicator
            {
                Type        = type,
                Severity    = severity,
                Description = description
            });
    }

    private static string Truncate(string s, int max) =>
        s.Length <= max ? s : s[..max] + "...";

    private static string? TryBase64Decode(string s)
    {
        try
        {
            if (s.Length % 4 != 0) return null;
            if (!Regex.IsMatch(s, @"^[A-Za-z0-9+/]*={0,2}$")) return null;
            var bytes   = Convert.FromBase64String(s);
            var decoded = Encoding.UTF8.GetString(bytes);
            // Reject if too many non-printable chars (binary data)
            int printable = decoded.Count(c => c >= 0x20 || c == '\n' || c == '\r' || c == '\t');
            if (decoded.Length == 0 || (double)printable / decoded.Length < 0.8) return null;
            return decoded;
        }
        catch { return null; }
    }

    private static byte[]? ParseByteList(string list)
    {
        try
        {
            var parts = list.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var result = new List<byte>();
            foreach (var p in parts)
            {
                int v = p.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
                    ? Convert.ToInt32(p, 16)
                    : int.Parse(p);
                if (v < 0 || v > 255) return null;
                result.Add((byte)v);
            }
            return result.Count > 0 ? [.. result] : null;
        }
        catch { return null; }
    }

    // ── IAstVisitor ──────────────────────────────────────────────────────────

    public void VisitStringLiteral(StringLiteral node)
    {
        if (!node.IsExpandable)
            return;

        // Check each interpolation segment for base64-encoded variable content
        foreach (var segment in node.InterpolationSegments)
        {
            if (segment.Type == "variable")
            {
                var decoded = TryBase64Decode(segment.Content);
                if (decoded != null)
                    FlagOnce("Base64Encoding", "High",
                        $"Base64-encoded content in string interpolation: ${segment.Content}",
                        $"Base64Encoding:{segment.Content.ToLowerInvariant()[..Math.Min(20, segment.Content.Length)]}");
            }
        }
    }

    public void VisitNumberLiteral(NumberLiteral node) { }

    public void VisitBooleanLiteral(BooleanLiteral node) { }

    public void VisitVariableReference(VariableReference node) { }

    public void VisitBinaryExpression(BinaryExpression node)
    {
        if (node.Operator == "+")
        {
            // Use StringFolder for constant propagation — only flag if we can fold
            // the whole expression to a non-trivial string built from 3+ parts,
            // which is a strong signal of string-splitting obfuscation.
            var folded = StringFolder.TryFold(node, _variables);
            if (folded != null)
            {
                // Count how many literal/variable leaf nodes contributed
                int parts = CountConcatParts(node);
                if (parts >= 3)
                    FlagOnce("StringConcatenation", "Medium",
                        $"String built from {parts} concatenated parts: '{Truncate(folded, 60)}'",
                        $"StrConcat:{folded.ToLowerInvariant()[..Math.Min(40, folded.Length)]}");
            }
        }

        node.Left?.Accept(this);
        node.Right?.Accept(this);
    }

    /// Counts the number of leaf (non-plus) nodes in a chain of + BinaryExpressions.
    private static int CountConcatParts(Expression? expr)
    {
        if (expr is BinaryExpression { Operator: "+" } bin)
            return CountConcatParts(bin.Left) + CountConcatParts(bin.Right);
        return 1;
    }

    public void VisitFunctionCall(FunctionCall node)
    {
        if (SuspiciousFunctions.Contains(node.FunctionName, StringComparer.OrdinalIgnoreCase))
            FlagOnce("SuspiciousFunction", "High",
                $"Suspicious function call: {node.FunctionName}",
                $"SuspFn:{node.FunctionName.ToLowerInvariant()}");

        foreach (var arg in node.Arguments)
            arg?.Accept(this);
    }

    public void VisitPipelineExpression(PipelineExpression node)
    {
        foreach (var segment in node.Segments)
            segment?.Accept(this);
    }

    public void VisitExpressionStatement(ExpressionStatement node)
    {
        node.Expression?.Accept(this);
    }

    public void VisitAssignmentStatement(AssignmentStatement node)
    {
        // Constant propagation: record literal assignments for later folding
        var val = StringFolder.TryFold(node.Value, _variables);
        if (val != null)
            _variables[node.VariableName] = val;

        node.Value?.Accept(this);
    }

    public void VisitIfStatement(IfStatement node)
    {
        node.Condition?.Accept(this);

        foreach (var stmt in node.ThenBranch)
            stmt?.Accept(this);

        foreach (var stmt in node.ElseBranch)
            stmt?.Accept(this);
    }

    public void VisitFunctionDefinition(FunctionDefinition node)
    {
        foreach (var stmt in node.Body)
            stmt?.Accept(this);
    }

    public void VisitScriptBlock(ScriptBlock node)
    {
        foreach (var stmt in node.Statements)
            stmt?.Accept(this);
    }
}

/// <summary>
/// Raport z analizy obfuscacji
/// </summary>
public class ObfuscationIndicator
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "";

    [JsonPropertyName("severity")]
    public string Severity { get; set; } = ""; // Low, Medium, High, Critical

    [JsonPropertyName("description")]
    public string Description { get; set; } = "";
}

public class ObfuscationReport
{
    private static readonly JsonSerializerOptions s_indented    = new() { WriteIndented = true  };
    private static readonly JsonSerializerOptions s_compact     = new() { WriteIndented = false };

    [JsonPropertyName("suspicion_score")]
    public double SuspicionScore { get; private set; }

    [JsonPropertyName("indicators")]
    public List<ObfuscationIndicator> Indicators { get; } = new();

    public void AddIndicator(ObfuscationIndicator indicator)
    {
        Indicators.Add(indicator);
        CalculateSuspicionScore();
    }

    private void CalculateSuspicionScore()
    {
        int score = 0;

        foreach (var indicator in Indicators)
        {
            score += indicator.Severity switch
            {
                "Low" => 1,
                "Medium" => 3,
                "High" => 5,
                "Critical" => 10,
                _ => 0
            };
        }

        SuspicionScore = Math.Min(10.0, score / 10.0);
    }

    public string ToJson(bool indented = true) =>
        JsonSerializer.Serialize(this, indented ? s_indented : s_compact);

    public override string ToString()
    {
        var sb = new StringBuilder();
        sb.AppendLine($"Suspicion Score: {SuspicionScore:F2}/10");
        sb.AppendLine($"Indicators Found: {Indicators.Count}");

        foreach (var indicator in Indicators)
        {
            sb.AppendLine($"  [{indicator.Severity}] {indicator.Type}: {indicator.Description}");
        }

        return sb.ToString();
    }
}
