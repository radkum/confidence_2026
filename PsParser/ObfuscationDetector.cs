using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
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
}

/// <summary>
/// Detektor obfuscacji - identyfikuje techniki ukrycia
/// </summary>
public class ObfuscationDetector : IAstVisitor
{
    public ObfuscationReport Report { get; private set; } = new();

    public void VisitStringLiteral(StringLiteral node)
    {
        if (!node.IsExpandable)
            return;

        // Check for Base64
        foreach (var segment in node.InterpolationSegments)
        {
            if (segment.Type == "variable")
            {
                var evaluator = new StringEvaluator();
                string decoded = evaluator.TryDecodeBase64(segment.Content);
                if (decoded != null)
                {
                    Report.AddIndicator(new ObfuscationIndicator
                    {
                        Type = "Base64Encoding",
                        Severity = "High",
                        Description = $"Base64 encoded content detected in string interpolation: {segment.Content[..Math.Min(20, segment.Content.Length)]}..."
                    });
                }
            }
        }
    }

    public void VisitNumberLiteral(NumberLiteral node) { }

    public void VisitBooleanLiteral(BooleanLiteral node) { }

    public void VisitVariableReference(VariableReference node) { }

    public void VisitBinaryExpression(BinaryExpression node)
    {
        // String concatenation can be obfuscation
        if (node.Operator == "+")
        {
            Report.AddIndicator(new ObfuscationIndicator
            {
                Type = "StringConcatenation",
                Severity = "Medium",
                Description = "String concatenation detected - possible obfuscation technique"
            });
        }

        node.Left?.Accept(this);
        node.Right?.Accept(this);
    }

    public void VisitFunctionCall(FunctionCall node)
    {
        // Check for suspicious functions
        var suspiciousFunctions = new[] { "Invoke-Expression", "IEX", "Invoke-WebRequest", "iwr", "New-Object" };

        if (suspiciousFunctions.Contains(node.FunctionName, StringComparer.OrdinalIgnoreCase))
        {
            Report.AddIndicator(new ObfuscationIndicator
            {
                Type = "SuspiciousFunction",
                Severity = "High",
                Description = $"Suspicious function call: {node.FunctionName}"
            });
        }

        // Recursively check arguments
        foreach (var arg in node.Arguments)
        {
            arg?.Accept(this);
        }
    }

    public void VisitPipelineExpression(PipelineExpression node)
    {
        foreach (var segment in node.Segments)
        {
            segment?.Accept(this);
        }
    }

    public void VisitExpressionStatement(ExpressionStatement node)
    {
        node.Expression?.Accept(this);
    }

    public void VisitAssignmentStatement(AssignmentStatement node)
    {
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
    public string Type { get; set; }
    public string Severity { get; set; } // Low, Medium, High, Critical
    public string Description { get; set; }
}

public class ObfuscationReport
{
    public List<ObfuscationIndicator> Indicators { get; } = new();
    public double SuspicionScore { get; private set; }

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
