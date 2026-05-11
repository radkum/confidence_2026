using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;

namespace PSParser;

public class FeatureVector
{
    public Dictionary<string, double> Features { get; }

    private static readonly string[] FeatureOrder = {
        // Group A: entropy & encoding
        "entropy", "base64_ratio", "base64_count", "hex_string_count",
        // Group B: fragmentation
        "string_concat_count", "backtick_count", "format_operator_count",
        "char_cast_count", "avg_identifier_length",
        // Group C: suspicious APIs (on deobfuscated)
        "reflection_api_count", "memory_api_count", "network_api_count",
        "amsi_string_count", "iex_count", "credential_api_count",
        // Group D: structural
        "line_count", "avg_line_length", "max_line_length",
        "comment_ratio", "unique_token_ratio"
    };

    public string[] Names => FeatureOrder;
    public double[] Values => FeatureOrder.Select(n => Features.GetValueOrDefault(n, 0.0)).ToArray();

    public FeatureVector(Dictionary<string, double> features)
    {
        Features = features;
        // Sanitize: no NaN or Infinity
        foreach (var key in features.Keys.ToList())
            if (!double.IsFinite(features[key])) features[key] = 0.0;
    }

    public string ToCsvHeader() => string.Join(",", FeatureOrder);
    public string ToCsvRow() => string.Join(",", Values.Select(v => v.ToString("F4")));
}

public static class FeatureExtractor
{
    // Regexes
    private static readonly Regex ReBase64 = new(@"[A-Za-z0-9+/]{20,}={0,2}", RegexOptions.Compiled);
    private static readonly Regex ReHex    = new(@"0x[0-9A-Fa-f]{2,}", RegexOptions.Compiled);
    private static readonly Regex ReConcat = new(@"""[^""]*""\s*\+\s*""[^""]*""", RegexOptions.Compiled);
    private static readonly Regex ReBacktick = new(@"`[^`]", RegexOptions.Compiled);
    private static readonly Regex ReFmt    = new(@"-f\s+['""]", RegexOptions.Compiled);
    private static readonly Regex ReCharCast = new(@"\[char\]\s*(?:0x[0-9a-fA-F]+|\d+)", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex ReIdent  = new(@"\b[A-Za-z_]\w{2,}\b", RegexOptions.Compiled);

    private static readonly string[] ReflectionApis = {
        "Assembly.Load", "GetType(", "InvokeMember", "GetMethod", ".Invoke("
    };
    private static readonly string[] MemoryApis = {
        "VirtualProtect", "WriteProcessMemory", "VirtualAlloc",
        "Marshal.Write", "Marshal.Read"
    };
    private static readonly string[] NetworkApis = {
        "Invoke-WebRequest", "WebClient", "Net.Http",
        "DownloadString", "DownloadFile", "iwr ", "curl "
    };
    private static readonly string[] AmsiStrings = {
        "amsi", "AmsiScan", "amsiContext", "amsiInitFailed"
    };
    private static readonly string[] IexPatterns = {
        "Invoke-Expression", "IEX ", "IEX(", ". ("
    };
    private static readonly string[] CredentialApis = {
        "mimikatz", "sekurlsa", "lsass", "DPAPI", "credential",
        "Invoke-Mimikatz"
    };

    public static FeatureVector Extract(string originalSource, string? deobfuscatedSource = null)
    {
        deobfuscatedSource ??= originalSource;
        var f = new Dictionary<string, double>();

        var lines = originalSource.Split('\n');

        // Group A
        f["entropy"] = ShannonEntropy(originalSource);
        var b64matches = ReBase64.Matches(originalSource);
        f["base64_count"] = b64matches.Count;
        f["base64_ratio"] = originalSource.Length > 0
            ? (double)b64matches.Sum(m => m.Length) / originalSource.Length : 0;
        f["hex_string_count"] = ReHex.Matches(originalSource).Count;

        // Group B
        f["string_concat_count"] = ReConcat.Matches(originalSource).Count;
        f["backtick_count"] = ReBacktick.Matches(originalSource).Count;
        f["format_operator_count"] = ReFmt.Matches(originalSource).Count;
        f["char_cast_count"] = ReCharCast.Matches(originalSource).Count;
        var idents = ReIdent.Matches(originalSource);
        f["avg_identifier_length"] = idents.Count > 0
            ? idents.Average(m => (double)m.Length) : 0;

        // Group C (on deobfuscated)
        f["reflection_api_count"]  = CountOccurrences(deobfuscatedSource, ReflectionApis);
        f["memory_api_count"]      = CountOccurrences(deobfuscatedSource, MemoryApis);
        f["network_api_count"]     = CountOccurrences(deobfuscatedSource, NetworkApis);
        f["amsi_string_count"]     = CountOccurrences(deobfuscatedSource, AmsiStrings);
        f["iex_count"]             = CountOccurrences(deobfuscatedSource, IexPatterns);
        f["credential_api_count"]  = CountOccurrences(deobfuscatedSource, CredentialApis);

        // Group D
        f["line_count"] = lines.Length;
        f["avg_line_length"] = lines.Length > 0 ? lines.Average(l => (double)l.Length) : 0;
        f["max_line_length"] = lines.Length > 0 ? lines.Max(l => (double)l.Length) : 0;
        var commentLines = lines.Count(l => l.TrimStart().StartsWith("#"));
        f["comment_ratio"] = lines.Length > 0 ? (double)commentLines / lines.Length : 0;
        var tokens = originalSource.Split(new[]{ ' ','\t','\n','\r','(',')','{','}',';' },
            StringSplitOptions.RemoveEmptyEntries);
        f["unique_token_ratio"] = tokens.Length > 0
            ? (double)tokens.Distinct(StringComparer.OrdinalIgnoreCase).Count() / tokens.Length : 0;

        return new FeatureVector(f);
    }

    private static double ShannonEntropy(string s)
    {
        if (s.Length == 0) return 0;
        var freq = new Dictionary<char, int>();
        foreach (var c in s)
            freq[c] = freq.GetValueOrDefault(c, 0) + 1;
        double entropy = 0;
        foreach (var count in freq.Values)
        {
            double p = (double)count / s.Length;
            entropy -= p * Math.Log2(p);
        }
        return entropy;
    }

    private static double CountOccurrences(string source, string[] patterns)
    {
        return patterns.Sum(p =>
        {
            int count = 0, idx = 0;
            while ((idx = source.IndexOf(p, idx, StringComparison.OrdinalIgnoreCase)) >= 0)
            { count++; idx += p.Length; }
            return count;
        });
    }
}
