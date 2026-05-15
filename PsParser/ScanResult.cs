using System.Text.Json;
using System.Text.Json.Serialization;

namespace PSParser;

/// <summary>
/// Unified result for a single file scan, emitted as JSON when --json is active.
/// </summary>
public class ScanResult
{
    private static readonly JsonSerializerOptions s_indented = new()
    {
        WriteIndented = true,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };
    private static readonly JsonSerializerOptions s_compact = new()
    {
        WriteIndented = false,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    [JsonPropertyName("file")]
    public string File { get; init; } = "";

    [JsonPropertyName("status")]
    public string Status { get; init; } = "";

    [JsonPropertyName("confidence")]
    public int Confidence { get; init; }

    [JsonPropertyName("obfuscation")]
    public ObfuscationReport? Obfuscation { get; init; }

    [JsonPropertyName("amsi_bypass")]
    public AmsiBypassReport? AmsiBypass { get; init; }

    [JsonPropertyName("csharp")]
    public CSharpScanResult? CSharp { get; init; }

    [JsonPropertyName("ml")]
    public MlScore? Ml { get; init; }

    /// <summary>
    /// Serializes to JSON.
    /// Uses reflection-based serialization for regular builds.
    /// For NativeAOT publish, use AppJsonContext.Default.ScanResult instead:
    ///   JsonSerializer.Serialize(this, AppJsonContext.Default.ScanResult)
    /// </summary>
    public string ToJson(bool indented = true) =>
        JsonSerializer.Serialize(this, indented ? s_indented : s_compact);
}
