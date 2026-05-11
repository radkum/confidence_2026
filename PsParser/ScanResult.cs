using System.Text.Json;
using System.Text.Json.Serialization;

namespace PSParser;

/// <summary>
/// Unified result for a single file scan, emitted as JSON when --json is active.
/// </summary>
public class ScanResult
{
    private static readonly JsonSerializerOptions s_indented = new() { WriteIndented = true  };
    private static readonly JsonSerializerOptions s_compact  = new() { WriteIndented = false };

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

    public string ToJson(bool indented = true) =>
        JsonSerializer.Serialize(this, indented ? s_indented : s_compact);
}
