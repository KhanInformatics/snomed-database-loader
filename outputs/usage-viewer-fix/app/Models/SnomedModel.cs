using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace StaticBlazorSnomed.Models
{
    public class SnomedModel
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("term")]
        public string Term { get; set; } = string.Empty;

        [JsonPropertyName("description")]
        public string Description { get; set; } = string.Empty;

        [JsonPropertyName("conceptId")]
        public string ConceptId { get; set; } = string.Empty;

        [JsonPropertyName("synonyms")]
        public string[] Synonyms { get; set; } = Array.Empty<string>();

        [JsonPropertyName("fsn")]
        public string FullySpecifiedName { get; set; } = string.Empty;

        [JsonPropertyName("active")]
        public bool IsActive { get; set; } = true;

        [JsonPropertyName("module")]
        public string Module { get; set; } = string.Empty;

        [JsonPropertyName("definitionStatus")]
        public string DefinitionStatus { get; set; } = string.Empty;
    }

    public class SnomedSearchRequest
    {
        [Required(ErrorMessage = "Search term is required")]
        [MinLength(2, ErrorMessage = "Search term must be at least 2 characters")]
        public string SearchTerm { get; set; } = string.Empty;
        
        [Range(1, 500, ErrorMessage = "Max results must be between 1 and 500")]
        public int MaxResults { get; set; } = 50;
        
        public string? Language { get; set; } = "en";
        public bool ActiveOnly { get; set; } = true;
    }

    public class SnomedSearchResponse
    {
        public List<SnomedModel> Results { get; set; } = new();
        public int TotalCount { get; set; }
        public bool HasMore { get; set; }
    }

    public class SnomedUsageData
    {
        [JsonPropertyName("SNOMED_Concept_ID")]
        public string ConceptId { get; set; } = string.Empty;

        [JsonPropertyName("Description")]
        public string Procedure { get; set; } = string.Empty;

        [JsonPropertyName("Geographic_Coverage")]
        public string GeographicCoverage { get; set; } = string.Empty;

        // Properties for each year from the Azure Function response
        [JsonPropertyName("2024-25_Usage")]
        public long Usage_2024_25 { get; set; }

        [JsonPropertyName("2023-24_Usage")]
        public long Usage_2023_24 { get; set; }

        [JsonPropertyName("2022-23_Usage")]
        public long Usage_2022_23 { get; set; }

        [JsonPropertyName("2021-22_Usage")]
        public long Usage_2021_22 { get; set; }

        [JsonPropertyName("2020-21_Usage")]
        public long Usage_2020_21 { get; set; }

        [JsonPropertyName("2019-20_Usage")]
        public long Usage_2019_20 { get; set; }

        [JsonPropertyName("2018-19_Usage")]
        public long Usage_2018_19 { get; set; }

        [JsonPropertyName("2017-18_Usage")]
        public long Usage_2017_18 { get; set; }

        [JsonPropertyName("2016-17_Usage")]
        public long Usage_2016_17 { get; set; }

        [JsonPropertyName("2015-16_Usage")]
        public long Usage_2015_16 { get; set; }

        [JsonPropertyName("2014-15_Usage")]
        public long Usage_2014_15 { get; set; }

        [JsonPropertyName("2013-14_Usage")]
        public long Usage_2013_14 { get; set; }

        [JsonPropertyName("2012-13_Usage")]
        public long Usage_2012_13 { get; set; }

        [JsonPropertyName("2011-12_Usage")]
        public long Usage_2011_12 { get; set; }
    }

    public class UsageSearchRequest
    {
        [Required(ErrorMessage = "At least one SNOMED CT code is required")]
        public string SnomedCodes { get; set; } = string.Empty;
    }

    public class ClusterSearchResult
    {
        [JsonPropertyName("Cluster_ID")]
        public string ClusterId { get; set; } = string.Empty;

        [JsonPropertyName("Cluster_Description")]
        public string ClusterDescription { get; set; } = string.Empty;

        [JsonPropertyName("SNOMED_code")]
        public string SnomedCode { get; set; } = string.Empty;

        [JsonPropertyName("SNOMED_code_description")]
        public string SnomedCodeDescription { get; set; } = string.Empty;

        [JsonPropertyName("PCD_Refset_ID")]
        public string PcdRefsetId { get; set; } = string.Empty;
    }

    /// <summary>
    /// Model for NHS API response from GetSnomedCodeFromNHSAPI Azure Function
    /// </summary>
    public class NHSSnomedResponse
    {
        [JsonPropertyName("snomedCode")]
        public string SnomedCode { get; set; } = string.Empty;

        [JsonPropertyName("conceptId")]
        public string ConceptId { get; set; } = string.Empty;

        [JsonPropertyName("fullySpecifiedName")]
        public string FullySpecifiedName { get; set; } = string.Empty;

        [JsonPropertyName("term")]
        public string Term { get; set; } = string.Empty;

        [JsonPropertyName("source")]
        public string Source { get; set; } = string.Empty;

        [JsonPropertyName("timestamp")]
        public DateTime Timestamp { get; set; }

        [JsonPropertyName("rawResponse")]
        public string RawResponse { get; set; } = string.Empty;

        [JsonPropertyName("error")]
        public bool? Error { get; set; }

        [JsonPropertyName("errorMessage")]
        public string? ErrorMessage { get; set; }
    }

    /// <summary>
    /// Model for SNOMED CT hierarchy node used in tree visualization
    /// </summary>
    public class SnomedHierarchyNode
    {
        [JsonPropertyName("conceptId")]
        public string ConceptId { get; set; } = string.Empty;

        [JsonPropertyName("term")]
        public string Term { get; set; } = string.Empty;

        [JsonPropertyName("fsn")]
        public string FullySpecifiedName { get; set; } = string.Empty;

        [JsonPropertyName("isActive")]
        public bool IsActive { get; set; } = true;

        [JsonPropertyName("depth")]
        public int Depth { get; set; }

        [JsonPropertyName("parentId")]
        public string? ParentId { get; set; }

        [JsonPropertyName("hasChildren")]
        public bool HasChildren { get; set; }

        [JsonPropertyName("childCount")]
        public int ChildCount { get; set; }
    }

    /// <summary>
    /// Response model for SNOMED CT hierarchy queries
    /// </summary>
    public class SnomedHierarchyResponse
    {
        [JsonPropertyName("rootConcept")]
        public SnomedHierarchyNode? RootConcept { get; set; }

        [JsonPropertyName("ancestors")]
        public List<SnomedHierarchyNode> Ancestors { get; set; } = new();

        [JsonPropertyName("descendants")]
        public List<SnomedHierarchyNode> Descendants { get; set; } = new();

        [JsonPropertyName("directParents")]
        public List<SnomedHierarchyNode> DirectParents { get; set; } = new();

        [JsonPropertyName("directChildren")]
        public List<SnomedHierarchyNode> DirectChildren { get; set; } = new();

        [JsonPropertyName("totalAncestorCount")]
        public int TotalAncestorCount { get; set; }

        [JsonPropertyName("totalDescendantCount")]
        public int TotalDescendantCount { get; set; }

        [JsonPropertyName("error")]
        public string? Error { get; set; }
    }
}
