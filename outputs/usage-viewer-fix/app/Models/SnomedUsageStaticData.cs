using System.Text.Json.Serialization;

namespace StaticBlazorSnomed.Models;

public sealed class SnomedUsageManifest
{
    [JsonPropertyName("schemaVersion")]
    public int SchemaVersion { get; set; }

    [JsonPropertyName("datasetVersion")]
    public string DatasetVersion { get; set; } = string.Empty;

    [JsonPropertyName("geographicCoverage")]
    public string GeographicCoverage { get; set; } = string.Empty;

    [JsonPropertyName("periods")]
    public List<string> Periods { get; set; } = [];

    [JsonPropertyName("bucketCount")]
    public int BucketCount { get; set; }

    [JsonPropertyName("hashAlgorithm")]
    public string HashAlgorithm { get; set; } = string.Empty;

    [JsonPropertyName("suppressedValue")]
    public long SuppressedValue { get; set; }

    [JsonPropertyName("noUsageValue")]
    public long NoUsageValue { get; set; }

    [JsonPropertyName("topConceptIds")]
    public List<string> TopConceptIds { get; set; } = [];
}

public sealed class SnomedUsageResult
{
    public string ConceptId { get; init; } = string.Empty;

    public string Description { get; init; } = string.Empty;

    public string GeographicCoverage { get; init; } = string.Empty;

    /// <summary>
    /// Usage values in the same chronological order as the manifest periods.
    /// Zero means no published usage; the manifest's negative sentinel means 1-4 was suppressed.
    /// </summary>
    public long[] Usage { get; init; } = [];
}
