using System.Collections.Generic;
using System.Text.Json.Serialization;
using PSParser;

namespace PSParser;

[JsonSerializable(typeof(AmsiBypassReport))]
[JsonSerializable(typeof(AmsiIndicator))]
[JsonSerializable(typeof(ObfuscationReport))]
[JsonSerializable(typeof(ObfuscationIndicator))]
[JsonSerializable(typeof(ScanResult))]
[JsonSerializable(typeof(List<ScanResult>))]
[JsonSerializable(typeof(CSharpScanResult))]
[JsonSerializable(typeof(CSharpBlock))]
[JsonSerializable(typeof(CSharpIndicator))]
[JsonSerializable(typeof(List<CSharpBlock>))]
[JsonSerializable(typeof(List<CSharpIndicator>))]
internal sealed partial class AppJsonContext : JsonSerializerContext { }
