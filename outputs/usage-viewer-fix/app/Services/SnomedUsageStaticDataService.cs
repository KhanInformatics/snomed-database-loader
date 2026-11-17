using System.Collections.Concurrent;
using System.Net.Http.Json;
using System.Text.Json;
using StaticBlazorSnomed.Models;

namespace StaticBlazorSnomed.Services;

public sealed class SnomedUsageStaticDataService
{
    private const string DataRoot = "data/snomed-usage";
    private readonly HttpClient _httpClient;
    private readonly ConcurrentDictionary<int, Lazy<Task<Dictionary<string, JsonElement>>>> _shards = new();
    private readonly object _manifestLock = new();
    private Task<SnomedUsageManifest>? _manifestTask;

    public SnomedUsageStaticDataService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public Task<SnomedUsageManifest> GetManifestAsync()
    {
        lock (_manifestLock)
        {
            if (_manifestTask is null || _manifestTask.IsFaulted || _manifestTask.IsCanceled)
            {
                _manifestTask = LoadManifestAsync();
            }

            return _manifestTask;
        }
    }

    public async Task<List<SnomedUsageResult>> GetUsageDataAsync(string snomedCodes)
    {
        var conceptIds = ParseConceptIds(snomedCodes);
        if (conceptIds.Count == 0)
        {
            return [];
        }

        var manifest = await GetManifestAsync();
        var groups = conceptIds
            .GroupBy(conceptId => GetBucket(conceptId, manifest.BucketCount))
            .Select(group => new BucketRequest(group.Key, group.ToArray()))
            .ToArray();

        var loadedGroups = await Task.WhenAll(groups.Select(async group =>
            new LoadedBucket(group.ConceptIds, await GetShardAsync(group.Bucket, manifest))));

        var results = new List<SnomedUsageResult>(conceptIds.Count);
        foreach (var group in loadedGroups)
        {
            foreach (var conceptId in group.ConceptIds)
            {
                if (!group.Records.TryGetValue(conceptId, out var compactRecord))
                {
                    continue;
                }

                results.Add(ReadRecord(conceptId, compactRecord, manifest));
            }
        }

        return results
            .OrderByDescending(result => result.Usage.Sum(value => Math.Max(value, 0)))
            .ThenBy(result => result.ConceptId, StringComparer.Ordinal)
            .ToList();
    }

    private async Task<SnomedUsageManifest> LoadManifestAsync()
    {
        var manifest = await _httpClient.GetFromJsonAsync<SnomedUsageManifest>($"{DataRoot}/manifest.json")
            ?? throw new InvalidDataException("The SNOMED usage manifest was empty.");

        if (manifest.SchemaVersion != 1)
        {
            throw new InvalidDataException($"Unsupported SNOMED usage schema version: {manifest.SchemaVersion}.");
        }

        if (manifest.Periods.Count == 0 || string.IsNullOrWhiteSpace(manifest.DatasetVersion))
        {
            throw new InvalidDataException("The SNOMED usage manifest does not contain any reporting periods.");
        }

        if (manifest.BucketCount <= 0 || !string.Equals(manifest.HashAlgorithm, "fnv1a32", StringComparison.Ordinal))
        {
            throw new InvalidDataException("The SNOMED usage manifest has an unsupported sharding configuration.");
        }

        return manifest;
    }

    private async Task<Dictionary<string, JsonElement>> GetShardAsync(int bucket, SnomedUsageManifest manifest)
    {
        var shard = _shards.GetOrAdd(
            bucket,
            key => new Lazy<Task<Dictionary<string, JsonElement>>>(
                () => LoadShardAsync(key, manifest),
                LazyThreadSafetyMode.ExecutionAndPublication));

        try
        {
            return await shard.Value;
        }
        catch
        {
            // Another caller may already have started a retry. Remove only this failed request.
            ((ICollection<KeyValuePair<int, Lazy<Task<Dictionary<string, JsonElement>>>>>)_shards)
                .Remove(new(bucket, shard));
            throw;
        }
    }

    private async Task<Dictionary<string, JsonElement>> LoadShardAsync(int bucket, SnomedUsageManifest manifest)
    {
        var path = $"{DataRoot}/{manifest.DatasetVersion}/{bucket:D4}.json";
        return await _httpClient.GetFromJsonAsync<Dictionary<string, JsonElement>>(path)
            ?? throw new InvalidDataException($"The SNOMED usage shard {bucket:D4} was empty.");
    }

    private static SnomedUsageResult ReadRecord(
        string conceptId,
        JsonElement compactRecord,
        SnomedUsageManifest manifest)
    {
        if (compactRecord.ValueKind != JsonValueKind.Array ||
            compactRecord.GetArrayLength() != manifest.Periods.Count + 1)
        {
            throw new InvalidDataException($"The static usage record for {conceptId} has an invalid shape.");
        }

        var values = compactRecord.EnumerateArray();
        values.MoveNext();
        var description = values.Current.GetString() ?? string.Empty;
        var usage = new long[manifest.Periods.Count];

        var index = 0;
        while (values.MoveNext())
        {
            usage[index++] = values.Current.GetInt64();
        }

        return new SnomedUsageResult
        {
            ConceptId = conceptId,
            Description = description,
            GeographicCoverage = manifest.GeographicCoverage,
            Usage = usage
        };
    }

    private static List<string> ParseConceptIds(string input)
    {
        var separators = new[] { ',', ';', '\r', '\n', '\t', ' ' };
        var values = input.Split(
            separators,
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        var invalidValues = values
            .Where(value => value.Any(character => character is < '0' or > '9'))
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        if (invalidValues.Length > 0)
        {
            throw new ArgumentException($"Invalid SNOMED CT code(s): {string.Join(", ", invalidValues)}");
        }

        return values.Distinct(StringComparer.Ordinal).ToList();
    }

    internal static int GetBucket(string conceptId, int bucketCount)
    {
        const uint offsetBasis = 2166136261;
        const uint prime = 16777619;

        var hash = offsetBasis;
        foreach (var character in conceptId)
        {
            hash ^= character;
            hash = unchecked(hash * prime);
        }

        return (int)(hash % (uint)bucketCount);
    }

    private sealed record BucketRequest(int Bucket, string[] ConceptIds);

    private sealed record LoadedBucket(
        string[] ConceptIds,
        Dictionary<string, JsonElement> Records);
}
