using System;
using System.Runtime.InteropServices;
using System.Text;

namespace PSParser;

/// <summary>
/// Native API exported for use by the Rust AMSI provider via FFI.
/// Compile with NativeAOT (dotnet publish -r win-x64 -c Release -p:PublishAot=true -p:NativeLib=Shared)
/// to produce PSParser.dll callable from C/Rust without .NET runtime.
/// </summary>
public static class NativeApi
{
    /// <summary>
    /// Scans a PowerShell script for AMSI bypass patterns.
    /// </summary>
    /// <param name="scriptUtf8">Pointer to UTF-8 encoded script content.</param>
    /// <param name="scriptLen">Length of script in bytes.</param>
    /// <param name="outJson">Caller-provided output buffer for JSON result.</param>
    /// <param name="outJsonLen">Size of output buffer in bytes.</param>
    /// <returns>Number of bytes written to outJson, or -1 if buffer too small.</returns>
    [UnmanagedCallersOnly(EntryPoint = "psparser_scan")]
    public static unsafe int PsParserScan(
        byte* scriptUtf8,
        int   scriptLen,
        byte* outJson,
        int   outJsonLen)
    {
        try
        {
            if (scriptUtf8 == null || scriptLen <= 0 || outJson == null || outJsonLen <= 0)
                return -1;

            var script = Encoding.UTF8.GetString(scriptUtf8, scriptLen);

            var detector = new AmsiBypassDetector();
            detector.ScanSource(script);

            // Also run AST walk if parseable
            try
            {
                var ast = PSParser.FromSource(script).Parse();
                ast.Accept(detector);
            }
            catch { /* unsupported syntax — ScanSource covers it */ }

            // Build compact JSON result using AOT-safe source-generated serializer
            var report = detector.Report;
            var json   = System.Text.Json.JsonSerializer.Serialize(
                             report, AppJsonContext.Default.AmsiBypassReport);
            var bytes  = Encoding.UTF8.GetBytes(json);

            if (bytes.Length >= outJsonLen)
                return -1;

            bytes.CopyTo(new Span<byte>(outJson, outJsonLen));
            outJson[bytes.Length] = 0; // null terminator
            return bytes.Length;
        }
        catch
        {
            return -1;
        }
    }

    /// <summary>
    /// Returns the version string of PSParser.
    /// Useful for verifying the DLL loaded correctly.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "psparser_version")]
    public static unsafe int PsParserVersion(byte* outBuf, int outBufLen)
    {
        try
        {
            const string version = "PSParser/1.0 NativeAOT";
            var bytes = Encoding.UTF8.GetBytes(version);
            if (bytes.Length >= outBufLen) return -1;
            bytes.CopyTo(new Span<byte>(outBuf, outBufLen));
            outBuf[bytes.Length] = 0;
            return bytes.Length;
        }
        catch { return -1; }
    }
}
