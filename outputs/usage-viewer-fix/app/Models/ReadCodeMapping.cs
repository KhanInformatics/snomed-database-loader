using System.Text.Json.Serialization;

namespace StaticBlazorSnomed.Models
{
    /// <summary>
    /// Represents a Read code to SNOMED CT mapping result
    /// </summary>
    public class ReadCodeMapping
    {
        [JsonPropertyName("readCode")]
        public string ReadCode { get; set; } = string.Empty;

        [JsonPropertyName("termCode")]
        public string TermCode { get; set; } = string.Empty;

        [JsonPropertyName("conceptId")]
        public string ConceptId { get; set; } = string.Empty;

        [JsonPropertyName("descriptionId")]
        public string DescriptionId { get; set; } = string.Empty;

        [JsonPropertyName("isAssured")]
        public bool IsAssured { get; set; }

        [JsonPropertyName("mapType")]
        public string MapType { get; set; } = string.Empty;

        [JsonPropertyName("readTerm")]
        public string? ReadTerm { get; set; }

        [JsonPropertyName("snomedTerm")]
        public string? SnomedTerm { get; set; }

        [JsonPropertyName("conceptStatus")]
        public string? ConceptStatus { get; set; }

        [JsonPropertyName("inactivationDate")]
        public string? InactivationDate { get; set; }

        [JsonPropertyName("conceptIsActive")]
        public bool ConceptIsActive { get; set; }

        [JsonPropertyName("activeReplacements")]
        public List<ReplacementConcept> ActiveReplacements { get; set; } = new();
    }

    /// <summary>
    /// Represents a replacement concept for an inactive SNOMED CT concept
    /// </summary>
    public class ReplacementConcept
    {
        [JsonPropertyName("conceptId")]
        public string ConceptId { get; set; } = string.Empty;

        [JsonPropertyName("term")]
        public string? Term { get; set; }

        [JsonPropertyName("isActive")]
        public bool IsActive { get; set; }
    }

    /// <summary>
    /// Search result containing all mappings for the requested Read codes
    /// </summary>
    public class ReadCodeSearchResult
    {
        [JsonPropertyName("summary")]
        public ReadCodeSearchSummary Summary { get; set; } = new();

        [JsonPropertyName("mappings")]
        public List<ReadCodeMapping> Mappings { get; set; } = new();

        // Convenience properties to access summary data
        public double SearchTimeSeconds => Summary.SearchTimeSeconds;
        public int TotalMappings => Summary.TotalMappings;
        public int UniqueReadCodes => Summary.UniqueReadCodes;
        public int UniqueSnomedConcepts => Summary.UniqueSnomedConcepts;
    }

    /// <summary>
    /// Summary information for a Read code search
    /// </summary>
    public class ReadCodeSearchSummary
    {
        [JsonPropertyName("searchTimeSeconds")]
        public double SearchTimeSeconds { get; set; }

        [JsonPropertyName("totalMappings")]
        public int TotalMappings { get; set; }

        [JsonPropertyName("uniqueReadCodes")]
        public int UniqueReadCodes { get; set; }

        [JsonPropertyName("uniqueSnomedConcepts")]
        public int UniqueSnomedConcepts { get; set; }
    }
}
