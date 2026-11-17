using System.Globalization;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.RegularExpressions;

const int BucketCount = 1024;
const long SuppressedValue = -1;
const string ExpectedHeader = "SNOMED_Concept_ID\tDescription\tUsage\tActive_at_Start\tActive_at_End";

if (args.Length != 2)
{
    Console.Error.WriteLine("Usage: dotnet run --project Tools/SnomedUsageShardGenerator -- <source-directory> <output-directory>");
    return 1;
}

var sourceDirectory = Path.GetFullPath(args[0]);
var outputDirectory = Path.GetFullPath(args[1]);

if (!Directory.Exists(sourceDirectory))
{
    Console.Error.WriteLine($"Source directory does not exist: {sourceDirectory}");
    return 1;
}

try
{
    var sourceFiles = FindAndValidateSourceFiles(sourceDirectory);
    var periods = sourceFiles.Select(file => file.Period).ToArray();
    var concepts = ReadConcepts(sourceFiles, periods.Length);

    Directory.CreateDirectory(outputDirectory);
    var versionDirectory = Path.Combine(outputDirectory, periods[^1]);
    Directory.CreateDirectory(versionDirectory);

    WriteShards(versionDirectory, concepts, periods.Length);
    WriteManifest(outputDirectory, periods, concepts);

    var rowCount = concepts.Values.Sum(concept => concept.PresentCount);
    var suppressedCount = concepts.Values.Sum(concept => concept.Usage.Count(value => value == SuppressedValue));

    Console.WriteLine($"Generated {BucketCount:N0} shards for {concepts.Count:N0} concepts and {rowCount:N0} source rows.");
    Console.WriteLine($"Periods: {periods[0]} through {periods[^1]}; suppressed values: {suppressedCount:N0}.");
    Console.WriteLine($"Output: {outputDirectory}");
    return 0;
}
catch (Exception exception)
{
    Console.Error.WriteLine(exception.Message);
    return 1;
}

static IReadOnlyList<SourceFile> FindAndValidateSourceFiles(string sourceDirectory)
{
    var fileNamePattern = new Regex(
        @"^SNOMED_code_usage_(?<start>\d{4})-(?<end>\d{2})\.txt$",
        RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

    var files = Directory
        .EnumerateFiles(sourceDirectory, "SNOMED_code_usage_*.txt", SearchOption.TopDirectoryOnly)
        .Select(path =>
        {
            var match = fileNamePattern.Match(Path.GetFileName(path));
            if (!match.Success)
            {
                throw new InvalidDataException($"Unexpected source filename: {Path.GetFileName(path)}");
            }

            var startYear = int.Parse(match.Groups["start"].Value, CultureInfo.InvariantCulture);
            var endYear = int.Parse(match.Groups["end"].Value, CultureInfo.InvariantCulture);
            if (endYear != (startYear + 1) % 100)
            {
                throw new InvalidDataException($"Invalid period in filename: {Path.GetFileName(path)}");
            }

            return new SourceFile(path, startYear, $"{startYear:D4}-{endYear:D2}");
        })
        .OrderBy(file => file.StartYear)
        .ToArray();

    if (files.Length == 0)
    {
        throw new InvalidDataException($"No SNOMED usage source files were found in {sourceDirectory}");
    }

    for (var index = 1; index < files.Length; index++)
    {
        if (files[index].StartYear != files[index - 1].StartYear + 1)
        {
            throw new InvalidDataException(
                $"The source periods are not contiguous: {files[index - 1].Period} is followed by {files[index].Period}.");
        }
    }

    return files;
}

static Dictionary<string, ConceptRecord> ReadConcepts(IReadOnlyList<SourceFile> sourceFiles, int periodCount)
{
    var concepts = new Dictionary<string, ConceptRecord>(StringComparer.Ordinal);

    for (var periodIndex = 0; periodIndex < sourceFiles.Count; periodIndex++)
    {
        var sourceFile = sourceFiles[periodIndex];
        using var reader = new StreamReader(sourceFile.Path, detectEncodingFromByteOrderMarks: true);
        var header = reader.ReadLine();
        if (!string.Equals(header, ExpectedHeader, StringComparison.Ordinal))
        {
            throw new InvalidDataException($"Unexpected header in {Path.GetFileName(sourceFile.Path)}.");
        }

        var seenInPeriod = new HashSet<string>(StringComparer.Ordinal);
        var lineNumber = 1;
        var periodRows = 0;

        while (reader.ReadLine() is { } line)
        {
            lineNumber++;
            if (line.Length == 0)
            {
                continue;
            }

            var fields = line.Split('\t');
            if (fields.Length != 5)
            {
                throw new InvalidDataException(
                    $"Expected 5 tab-separated fields in {Path.GetFileName(sourceFile.Path)} at line {lineNumber}, found {fields.Length}.");
            }

            var conceptId = fields[0];
            if (conceptId.Length == 0 || conceptId.Any(character => character is < '0' or > '9'))
            {
                throw new InvalidDataException(
                    $"Invalid concept ID in {Path.GetFileName(sourceFile.Path)} at line {lineNumber}: {conceptId}");
            }

            if (!seenInPeriod.Add(conceptId))
            {
                throw new InvalidDataException(
                    $"Duplicate concept ID {conceptId} in {Path.GetFileName(sourceFile.Path)} at line {lineNumber}.");
            }

            if (fields[3] is not ("0" or "1") || fields[4] is not ("0" or "1"))
            {
                throw new InvalidDataException(
                    $"Invalid active flag for concept {conceptId} in {Path.GetFileName(sourceFile.Path)} at line {lineNumber}.");
            }

            long usage;
            if (fields[2] == "*")
            {
                usage = SuppressedValue;
            }
            else if (!long.TryParse(fields[2], NumberStyles.None, CultureInfo.InvariantCulture, out usage) || usage < 0)
            {
                throw new InvalidDataException(
                    $"Invalid usage value for concept {conceptId} in {Path.GetFileName(sourceFile.Path)} at line {lineNumber}: {fields[2]}");
            }

            if (!concepts.TryGetValue(conceptId, out var concept))
            {
                concept = new ConceptRecord(periodCount);
                concepts.Add(conceptId, concept);
            }

            // Files are processed chronologically, so this retains the most recent published description.
            concept.Description = fields[1];
            concept.Usage[periodIndex] = usage;
            concept.PresentCount++;
            periodRows++;
        }

        Console.WriteLine($"Read {sourceFile.Period}: {periodRows:N0} rows.");
    }

    return concepts;
}

static void WriteShards(
    string versionDirectory,
    IReadOnlyDictionary<string, ConceptRecord> concepts,
    int periodCount)
{
    var buckets = Enumerable.Range(0, BucketCount)
        .Select(_ => new List<KeyValuePair<string, ConceptRecord>>())
        .ToArray();

    foreach (var concept in concepts)
    {
        buckets[GetBucket(concept.Key, BucketCount)].Add(concept);
    }

    var writerOptions = new JsonWriterOptions
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        Indented = false
    };

    for (var bucket = 0; bucket < buckets.Length; bucket++)
    {
        var path = Path.Combine(versionDirectory, $"{bucket:D4}.json");
        using var stream = File.Create(path);
        using var writer = new Utf8JsonWriter(stream, writerOptions);

        writer.WriteStartObject();
        foreach (var concept in buckets[bucket].OrderBy(item => item.Key, StringComparer.Ordinal))
        {
            writer.WritePropertyName(concept.Key);
            writer.WriteStartArray();
            writer.WriteStringValue(concept.Value.Description);
            for (var periodIndex = 0; periodIndex < periodCount; periodIndex++)
            {
                writer.WriteNumberValue(concept.Value.Usage[periodIndex]);
            }
            writer.WriteEndArray();
        }
        writer.WriteEndObject();
    }
}

static void WriteManifest(
    string outputDirectory,
    IReadOnlyList<string> periods,
    IReadOnlyDictionary<string, ConceptRecord> concepts)
{
    var latestPeriodIndex = periods.Count - 1;
    var topConceptIds = concepts
        .OrderByDescending(item => Math.Max(item.Value.Usage[latestPeriodIndex], 0))
        .ThenBy(item => item.Key, StringComparer.Ordinal)
        .Take(100)
        .Select(item => item.Key)
        .ToArray();

    var manifest = new
    {
        schemaVersion = 1,
        datasetVersion = periods[^1],
        geographicCoverage = "England",
        periods,
        bucketCount = BucketCount,
        hashAlgorithm = "fnv1a32",
        suppressedValue = SuppressedValue,
        noUsageValue = 0,
        recordShape = "[latestDescription, usageForEachPeriodInManifestOrder]",
        topConceptIds
    };

    var options = new JsonSerializerOptions
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        WriteIndented = true
    };

    File.WriteAllText(
        Path.Combine(outputDirectory, "manifest.json"),
        JsonSerializer.Serialize(manifest, options) + "\n");
}

static int GetBucket(string conceptId, int bucketCount)
{
    const uint offsetBasis = 2166136261;
    const uint prime = 16777619;

    var hash = offsetBasis;
    foreach (var character in conceptId)
    {
        // SNOMED CT identifiers contain ASCII digits only.
        hash ^= character;
        hash *= prime;
    }

    return (int)(hash % (uint)bucketCount);
}

internal sealed record SourceFile(string Path, int StartYear, string Period);

internal sealed class ConceptRecord(int periodCount)
{
    public string Description { get; set; } = string.Empty;

    public long[] Usage { get; } = new long[periodCount];

    public int PresentCount { get; set; }
}
