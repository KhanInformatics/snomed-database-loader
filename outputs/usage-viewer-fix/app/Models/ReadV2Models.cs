namespace StaticBlazorSnomed.Models;

public class ReadV2Concept
{
    public string ReadCode { get; set; } = "";
    public string PreferredTerm { get; set; } = "";
    public string Status { get; set; } = "";
    public int Children { get; set; }
    public int Level { get; set; }
    public long ConType { get; set; }
    public bool IsActive => Status == "C";
    public string StatusDescription => Status switch
    {
        "C" => "Current",
        "O" => "Obsolete",
        _ => "Unknown"
    };
}

public class ReadV2Term
{
    public string ReadCode { get; set; } = "";
    public string TermId { get; set; } = "";
    public string TermType { get; set; } = "";
    public string Term30 { get; set; } = "";
    public string Term60 { get; set; } = "";
    public string Term198 { get; set; } = "";
    public string TermStatus { get; set; } = "";
    public bool IsPreferred => TermType == "P";
    public string TermTypeDescription => TermType switch
    {
        "P" => "Preferred",
        "S" => "Synonym",
        _ => "Unknown"
    };
}

public class ReadV2TreeNode
{
    public string ReadCode { get; set; } = "";
    public string ParentCode { get; set; } = "";
    public string PreferredTerm { get; set; } = "";
    public string Status { get; set; } = "";
    public int ChildCount { get; set; }
    public bool HasChildren => ChildCount > 0;
    public string ListOrder { get; set; } = "";
    public int Depth { get; set; }
    public bool IsActive => Status == "C";
}

public class ReadV2ConceptDetail
{
    public string ReadCode { get; set; } = "";
    public string PreferredTerm { get; set; } = "";
    public string Status { get; set; } = "";
    public int Children { get; set; }
    public int Level { get; set; }
    public long ConType { get; set; }
    public bool IsActive => Status == "C";
    public string StatusDescription => Status switch
    {
        "C" => "Current",
        "O" => "Obsolete",
        _ => "Unknown"
    };
    public List<ReadV2Term> Terms { get; set; } = new();
    public List<ReadV2TreeNode> Parents { get; set; } = new();
    public List<ReadV2TreeNode> DirectChildren { get; set; } = new();
    public List<ReadV2Mapping> Mappings { get; set; } = new();
}

public class ReadV2Mapping
{
    public string ReadCode { get; set; } = "";
    public string TargetCode { get; set; } = "";
    public string TargetDescription { get; set; } = "";
    public string TargetSystem { get; set; } = "";
    public string MapStatus { get; set; } = "";
    public string MapBlock { get; set; } = "";
    public string MapElement { get; set; } = "";
    public string MapReference { get; set; } = "";
    public string AdditionFlag { get; set; } = "";
}

public class ReadV2Chapter
{
    public string ReadCode { get; set; } = "";
    public string PreferredTerm { get; set; } = "";
    public int ViewId { get; set; }
}

public class ReadV2SearchResult
{
    public string ReadCode { get; set; } = "";
    public string PreferredTerm { get; set; } = "";
    public string MatchedTerm { get; set; } = "";
    public string TermId { get; set; } = "";
    public string MatchType { get; set; } = "";
    public string Status { get; set; } = "";
    public string Chapter { get; set; } = "";
    public bool HasMappings { get; set; }
    public bool IsActive => Status == "C";
    public string StatusDescription => Status switch
    {
        "C" => "Current",
        "O" => "Obsolete",
        _ => "Unknown"
    };
}

public class ReadV2SearchResponse
{
    public List<ReadV2SearchResult> Results { get; set; } = new();
    public int TotalCount { get; set; }
    public double SearchTimeMs { get; set; }
    public string SearchTerm { get; set; } = "";
    public string SearchType { get; set; } = "";
    public bool IsTruncated { get; set; }
}

public class SearchAuditEntry
{
    public int Id { get; set; }
    public DateTime Timestamp { get; set; }
    public string SearchTerm { get; set; } = "";
    public string SearchType { get; set; } = "";
    public int ResultCount { get; set; }
    public double SearchTimeMs { get; set; }
    public string? ClientIp { get; set; }
}
