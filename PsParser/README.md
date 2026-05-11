# PowerShell Parser (C#) - String Interpolation Support

Lightweight PowerShell parser w C# z wsparciem dla **string interpolation**, **obfuscation detection** i **safe string deobfuscation**.

## Features

### 1. **String Interpolation Handling**
Obsługuje wszystkie formy interpolacji w PowerShelu:
- `$variable` - Proste referencje do zmiennych
- `${variable}` - Zmienne z nawiasami
- `$(expression)` - Wyrażenia w nawiasach klamrowych
- Zagnieżdżone interpolacje

```csharp
// Przykład
string code = @"""Hello $name, result is $(Get-Process | Select Count)""";
```

### 2. **AST (Abstract Syntax Tree) Parser**
Buduje kompletne AST z:
- Tokenizer (lexical analysis)
- Parser (syntactic analysis)
- Support dla: string literals, variables, functions, pipelines, if/for/foreach, itd.

### 3. **Safe String Evaluation**
Bezpieczne rozwijanie stringów **BEZ** execution:
- Base64 decoding
- Multi-layer obfuscation unwrapping
- Native .NET utilities (gzip, URL decode)
- Timeout protection

### 4. **Obfuscation Detection**
Identyfikuje techniki obfuscacji:
- Base64 encoding w interpolacji
- String concatenation patterns
- Suspicious function calls (IEX, Invoke-WebRequest, New-Object)
- Łańcuchy kodowania (Base64 of Base64)

## Architecture

```
Source Code
    ↓
PSTokenizer (Lexical Analysis)
    ↓
List<Token>
    ↓
PSParser (Syntactic Analysis)
    ↓
AST (Abstract Syntax Tree)
    ↓
ObfuscationDetector (Visitor Pattern)
    ↓
ObfuscationReport (Suspicion Score + Indicators)
```

## Usage Examples

### Example 1: Parse Basic Script

```csharp
using PSParser;

string code = @"""
$message = 'Hello World'
Write-Host $message
""";

var parser = PSParser.PSParser.FromSource(code);
var ast = parser.Parse();

Console.WriteLine($"Statements: {ast.Statements.Count}");
```

### Example 2: Detect Obfuscation

```csharp
string obfuscatedCode = @"IEX ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('QwBtAGQA')))";

var parser = PSParser.PSParser.FromSource(obfuscatedCode);
var ast = parser.Parse();

var detector = new ObfuscationDetector();
ast.Accept(detector);

Console.WriteLine(detector.Report);
// Output:
// Suspicion Score: 8.50/10
// Indicators Found: 3
//   [High] SuspiciousFunction: Invoke-Expression
//   [High] Base64Encoding: ...
//   [Medium] StringConcatenation: ...
```

### Example 3: Deobfuscate Nested Encoding

```csharp
string layer3Base64 = "VkdGeWRHbGpiMjUwWldOMFUzbHZibmR2Ymk5bGVHRnRjR3hsBg==";

var evaluator = new StringEvaluator();
var layers = evaluator.DeobfuscateNestedEncoding(layer3Base64);

foreach (var (i, layer) in layers.Select((x, i) => (i, x)))
{
    Console.WriteLine($"Layer {i}: {layer}");
}
```

### Example 4: String Interpolation Extraction

```csharp
var stringLiteral = new StringLiteral
{
    Value = @"""Hello $name, age is $(GetAge $id)""",
    IsExpandable = true
};

var segments = parser.ExtractInterpolationSegments(stringLiteral.Value);

foreach (var segment in segments)
{
    Console.WriteLine($"{segment.Type}: {segment.Content}");
}
// Output:
// text: Hello 
// variable: $name
// text: , age is 
// expression: GetAge $id
```

## Supported PowerShell Constructs

### Literals
- Strings (single quote, double quote with interpolation)
- Numbers (integers, decimals)
- Booleans ($true, $false)

### Variables
- Simple: `$varName`
- Complex: `${var Name}` with spaces

### Operators
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparison: `-eq`, `-ne`, `-lt`, `-gt`, `-le`, `-ge`
- Logical: `-and`, `-or`, `-not`
- String: `-match`, `-like`, `-contains`
- Bitwise: `-band`, `-bor`, `-bxor`, `-bnot`, `-shl`, `-shr`

### Statements
- Assignment: `$var = value`
- If/Else: `if (condition) { } else { }`
- Function definition: `function name { }`
- Pipeline: `cmd1 | cmd2 | cmd3`

### String Interpolation
- Variables: `"Hello $name"`
- Expressions: `"Result: $(Get-Process)"`
- Nested: `"$($var + $other)"`

## Obfuscation Techniques Detected

| Technique | Detection | Severity |
|-----------|-----------|----------|
| Base64 Encoding | Regex pattern matching | High |
| String Concatenation | Binary + operator | Medium |
| Invoke-Expression | Function name check | High |
| Multiple encoding layers | Recursive decoding | High |
| Suspicious functions (IEX, iwr, New-Object) | Whitelist check | High |

## Performance

- **Tokenization**: ~100K tokens/sec
- **Parsing**: ~50K statements/sec
- **String deobfuscation**: Instant (max 100 iterations)
- **Memory**: ~500KB base + AST size

## Security Considerations

⚠️ **NO CODE EXECUTION** - Parser nigdy nie wykonuje kodu PowerShela

- String evaluation jest czystą statyczną analizą
- Base64 decode ma limit rozmiaru (100KB)
- Regex patterns mają timeout
- Gzip decompression ma limit rozmiaru (1MB)
- Multi-layer unwrapping ma limit iteracji (100)

## Integration with ramsi-rs

Używać w ramsi-rs dla:
1. **Feature extraction**: AST complexity, entropy, obfuscation patterns
2. **Pre-processing**: Deobfuscate before ML analysis
3. **Reporting**: Detailed obfuscation breakdown w alerts

```rust
// pseudo-code
let csharp_output = run_csharp_parser(script);
let features = extract_features(csharp_output.ast);
let obfuscation_score = calculate_ml_score(features);
```

## Building & Testing

### Requirements
- .NET 8.0 SDK or later
- C# 11.0+

### Build
```bash
dotnet build
dotnet run --project PSParserDemo
```

### Run Tests
```bash
dotnet test
```

## Future Enhancements

- [ ] Support dla WMI syntax
- [ ] Dynamic script block analysis
- [ ] Reflection pattern detection
- [ ] AMSI bypass detection rules
- [ ] Performance optimization (IL generation)
- [ ] .NET assembly decompilation support

## License

Included w projekcie ramsi-rs

## Author

Radosław Kumorek
