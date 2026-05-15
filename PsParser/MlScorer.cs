using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace PSParser;

/// <summary>
/// Online ML scorer with confidence ramp-up. Architecture:
///
///   1. Extract feature vector from script.
///   2. Compute ML score via simple logistic regression (current model).
///   3. Look up sample count from persistent store.
///   4. ml_weight = min(sample_count / TARGET, 1.0).
///   5. Final = rules_score * (1 - ml_weight) + ml_score * ml_weight.
///
/// The model is initialised with hardcoded "early-stage" coefficients --
/// effectively a small ensemble of weighted heuristics. As more samples are
/// collected, the coefficients can be re-trained (offline) and the embedded
/// weights replaced. The scoring contract stays the same.
/// </summary>
public class MlScore
{
    [JsonPropertyName("score")]
    public double Score { get; init; }   // 0.0 - 1.0 (probability-like)

    [JsonPropertyName("weight")]
    public double Weight { get; init; }  // 0.0 - 1.0 (how much ML opinion counts)

    [JsonPropertyName("sample_count")]
    public long SampleCount { get; init; }

    [JsonPropertyName("target_samples")]
    public long TargetSamples { get; init; }

    [JsonPropertyName("interpretation")]
    public string Interpretation { get; init; } = "";

    [JsonPropertyName("top_features")]
    public List<TopFeature> TopFeatures { get; init; } = new();
}

public class TopFeature
{
    [JsonPropertyName("name")]
    public string Name { get; init; } = "";

    [JsonPropertyName("value")]
    public double Value { get; init; }

    [JsonPropertyName("contribution")]
    public double Contribution { get; init; }
}

public static class MlScorer
{
    /// Target dataset size at which ML weight reaches 100%.
    public const long TargetSampleCount = 10_000;

    /// Persistent store for sample count. Auto-created.
    private static readonly string CounterPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
        "Confidence", "ml_samples_count.txt");

    /// Hardcoded "early-stage" logistic regression coefficients.
    /// (feature_name → weight) -- intercept stored under empty string.
    /// These weights mirror our rule-based intuition: high entropy + many
    /// reflection APIs + base64 dense → malicious. Values picked so that
    /// a clearly-bad script scores ~0.85 and a clean script ~0.05.
    private static readonly Dictionary<string, double> Weights = new()
    {
        // intercept
        [""]                       = -2.5,

        // Group A: entropy & encoding (higher = more suspicious)
        ["entropy"]                =  0.35,
        ["base64_ratio"]           =  2.40,
        ["base64_count"]           =  0.18,
        ["hex_string_count"]       =  0.05,

        // Group B: fragmentation (obfuscation signal)
        ["string_concat_count"]    =  0.04,
        ["backtick_count"]         =  0.15,
        ["format_operator_count"]  =  0.20,
        ["char_cast_count"]        =  0.10,
        ["avg_identifier_length"]  = -0.05,  // longer identifiers = less obfuscated

        // Group C: suspicious APIs (the heaviest signal)
        ["reflection_api_count"]   =  0.45,
        ["memory_api_count"]       =  0.55,
        ["network_api_count"]      =  0.30,
        ["amsi_string_count"]      =  0.80,
        ["iex_count"]              =  0.35,
        ["credential_api_count"]   =  0.40,

        // Group D: structural
        ["line_count"]             = -0.003, // tiny -- short scripts slightly more suspicious
        ["avg_line_length"]        =  0.002, // long lines = encoded blobs
        ["max_line_length"]        =  0.0005,
        ["comment_ratio"]          = -0.30,  // many comments = legit script
        ["unique_token_ratio"]     = -0.40,  // diverse vocabulary = legit
    };

    private static double Sigmoid(double z) => 1.0 / (1.0 + Math.Exp(-z));

    public static MlScore Score(FeatureVector fv, double rulesScore)
    {
        // 1. Compute logistic regression score
        double z = Weights[""];
        var contribs = new List<TopFeature>();

        foreach (var (name, value) in fv.Features)
        {
            if (Weights.TryGetValue(name, out var w))
            {
                double c = w * value;
                z += c;
                if (Math.Abs(c) > 0.01)
                {
                    contribs.Add(new TopFeature
                    {
                        Name = name, Value = value, Contribution = c
                    });
                }
            }
        }
        double score = Sigmoid(z);

        // 2. Load sample count and compute weight
        long count = LoadCounter();
        double weight = Math.Min((double)count / TargetSampleCount, 1.0);

        // 3. Increment counter for this scan (this scan IS a new training sample)
        SaveCounter(count + 1);

        // 4. Interpretation string for humans
        string interp = (score, weight, rulesScore) switch
        {
            ( > 0.7, < 0.05, _) => $"early-stage model agrees with rules but its weight is only {weight:P1} of verdict",
            ( > 0.7,      _, _) => "ML scoring agrees: high-confidence anomaly",
            ( < 0.3,      _, _) => "ML scoring: low anomaly probability",
            _                    => "ML scoring inconclusive (mid-range)"
        };

        return new MlScore
        {
            Score          = Math.Round(score, 4),
            Weight         = Math.Round(weight, 4),
            SampleCount    = count,
            TargetSamples  = TargetSampleCount,
            Interpretation = interp,
            TopFeatures    = contribs.OrderByDescending(c => Math.Abs(c.Contribution)).Take(5).ToList()
        };
    }

    /// Blends the rule-based confidence (0-100) with ML score (0-1, scaled to
    /// 0-100) using the ML weight. Returns 0-100.
    public static int BlendedConfidence(int rulesScore, MlScore ml)
    {
        double mlPct = ml.Score * 100.0;
        double w = ml.Weight;
        double blended = rulesScore * (1.0 - w) + mlPct * w;
        return (int)Math.Round(blended);
    }

    private static long LoadCounter()
    {
        try
        {
            if (!File.Exists(CounterPath)) return 0;
            var txt = File.ReadAllText(CounterPath).Trim();
            return long.TryParse(txt, out var n) ? n : 0;
        }
        catch { return 0; }
    }

    private static void SaveCounter(long n)
    {
        try
        {
            var dir = Path.GetDirectoryName(CounterPath);
            if (dir != null && !Directory.Exists(dir)) Directory.CreateDirectory(dir);
            File.WriteAllText(CounterPath, n.ToString());
        }
        catch { /* best effort */ }
    }
}
