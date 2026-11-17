using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;
using StaticBlazorSnomed.Models;

namespace StaticBlazorSnomed.Services;

public sealed class ReadV2ApiService
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;

    public ReadV2ApiService(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;

        var configuredUrl = configuration["ReadV2Api:BaseUrl"];
        if (string.IsNullOrWhiteSpace(configuredUrl))
        {
            configuredUrl = "/api/readv2/";
        }

        _baseUrl = BuildAbsoluteBaseUrl(configuredUrl);
    }

    public string BaseUrl => _baseUrl;
    public string? LastError { get; private set; }

    public void ClearError() => LastError = null;

    public Task<List<ReadV2Chapter>> GetChaptersAsync(CancellationToken cancellationToken = default) =>
        GetOrDefaultAsync("chapters", new List<ReadV2Chapter>(), cancellationToken);

    public Task<ReadV2ApiResult<List<ReadV2Chapter>>> TryGetChaptersAsync(
        CancellationToken cancellationToken = default) =>
        RequestAsync("chapters", new List<ReadV2Chapter>(), cancellationToken);

    public Task<List<ReadV2TreeNode>> GetChildrenAsync(
        string parentCode,
        CancellationToken cancellationToken = default) =>
        GetOrDefaultAsync(
            $"children/{Uri.EscapeDataString(parentCode)}",
            new List<ReadV2TreeNode>(),
            cancellationToken);

    public Task<ReadV2ApiResult<List<ReadV2TreeNode>>> TryGetChildrenAsync(
        string parentCode,
        CancellationToken cancellationToken = default) =>
        RequestAsync(
            $"children/{Uri.EscapeDataString(parentCode)}",
            new List<ReadV2TreeNode>(),
            cancellationToken);

    public Task<List<ReadV2TreeNode>> GetParentsAsync(
        string readCode,
        CancellationToken cancellationToken = default) =>
        GetOrDefaultAsync(
            $"parents/{Uri.EscapeDataString(readCode)}",
            new List<ReadV2TreeNode>(),
            cancellationToken);

    public Task<List<ReadV2TreeNode>> GetAncestorsAsync(
        string readCode,
        CancellationToken cancellationToken = default) =>
        GetOrDefaultAsync(
            $"ancestors/{Uri.EscapeDataString(readCode)}",
            new List<ReadV2TreeNode>(),
            cancellationToken);

    public Task<ReadV2ApiResult<List<ReadV2TreeNode>>> TryGetAncestorsAsync(
        string readCode,
        CancellationToken cancellationToken = default) =>
        RequestAsync(
            $"ancestors/{Uri.EscapeDataString(readCode)}",
            new List<ReadV2TreeNode>(),
            cancellationToken);

    public Task<ReadV2ConceptDetail?> GetConceptDetailAsync(
        string readCode,
        CancellationToken cancellationToken = default) =>
        GetOrDefaultAsync<ReadV2ConceptDetail?>(
            $"concept/{Uri.EscapeDataString(readCode)}",
            null,
            cancellationToken);

    public Task<ReadV2ApiResult<ReadV2ConceptDetail?>> TryGetConceptDetailAsync(
        string readCode,
        CancellationToken cancellationToken = default) =>
        RequestAsync<ReadV2ConceptDetail?>(
            $"concept/{Uri.EscapeDataString(readCode)}",
            null,
            cancellationToken);

    public Task<ReadV2SearchResponse> SearchAsync(
        string query,
        string searchType = "keyword",
        bool? activeOnly = null,
        string? chapter = null,
        bool? mappedOnly = null,
        int maxResults = 200,
        CancellationToken cancellationToken = default)
        => GetOrDefaultAsync(
            BuildSearchPath(query, searchType, activeOnly, chapter, mappedOnly, maxResults, 500),
            new ReadV2SearchResponse
            {
                SearchTerm = query,
                SearchType = searchType
            },
            cancellationToken);

    public Task<ReadV2ApiResult<ReadV2SearchResponse>> TrySearchAsync(
        string query,
        string searchType = "keyword",
        bool? activeOnly = null,
        string? chapter = null,
        bool? mappedOnly = null,
        int maxResults = 200,
        CancellationToken cancellationToken = default) =>
        RequestAsync(
            BuildSearchPath(query, searchType, activeOnly, chapter, mappedOnly, maxResults, 500),
            new ReadV2SearchResponse
            {
                SearchTerm = query,
                SearchType = searchType
            },
            cancellationToken);

    public string GetExportUrl(
        string query,
        string searchType = "keyword",
        bool? activeOnly = null,
        string? chapter = null,
        bool? mappedOnly = null,
        int maxResults = 500)
    {
        var parameters = new List<string>
        {
            $"q={Uri.EscapeDataString(query)}",
            $"type={Uri.EscapeDataString(searchType)}",
            $"max={Math.Clamp(maxResults, 1, 5000)}"
        };

        if (activeOnly.HasValue)
        {
            parameters.Add($"activeOnly={activeOnly.Value.ToString().ToLowerInvariant()}");
        }

        if (!string.IsNullOrWhiteSpace(chapter))
        {
            parameters.Add($"chapter={Uri.EscapeDataString(chapter)}");
        }

        if (mappedOnly.HasValue)
        {
            parameters.Add($"mappedOnly={mappedOnly.Value.ToString().ToLowerInvariant()}");
        }

        return BuildUrl($"search/export?{string.Join("&", parameters)}");
    }

    public Task<Dictionary<string, int>> GetStatsAsync(CancellationToken cancellationToken = default) =>
        GetOrDefaultAsync("stats", new Dictionary<string, int>(), cancellationToken);

    public Task<ReadV2ApiResult<Dictionary<string, int>>> TryGetStatsAsync(
        CancellationToken cancellationToken = default) =>
        RequestAsync("stats", new Dictionary<string, int>(), cancellationToken);

    public Task<List<SearchAuditEntry>> GetAuditLogAsync(
        int count = 50,
        CancellationToken cancellationToken = default) =>
        GetOrDefaultAsync(
            $"audit?count={Math.Clamp(count, 1, 200)}",
            new List<SearchAuditEntry>(),
            cancellationToken);

    private async Task<T> GetOrDefaultAsync<T>(
        string relativeUrl,
        T defaultValue,
        CancellationToken cancellationToken)
    {
        var result = await RequestAsync(relativeUrl, defaultValue, cancellationToken);
        LastError = result.Error;
        return result.Value;
    }

    private async Task<ReadV2ApiResult<T>> RequestAsync<T>(
        string relativeUrl,
        T defaultValue,
        CancellationToken cancellationToken)
    {
        try
        {
            using var response = await _httpClient.GetAsync(BuildUrl(relativeUrl), cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var error = response.StatusCode switch
                {
                    HttpStatusCode.BadRequest => "The READ v2 request was not valid.",
                    HttpStatusCode.NotFound => "The requested READ v2 record could not be found.",
                    _ when (int)response.StatusCode >= 500 => "The READ v2 data service is unavailable.",
                    _ => "The READ v2 data service could not complete the request."
                };

                return new ReadV2ApiResult<T>(defaultValue, error);
            }

            var value = await response.Content.ReadFromJsonAsync<T>(cancellationToken: cancellationToken);
            return new ReadV2ApiResult<T>(value ?? defaultValue, null);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            var error = exception switch
            {
                HttpRequestException => "The READ v2 data service is unavailable.",
                TaskCanceledException => "The READ v2 data service took too long to respond.",
                _ => "The READ v2 data service returned an unexpected response."
            };

            return new ReadV2ApiResult<T>(defaultValue, error);
        }
    }

    private static string BuildSearchPath(
        string query,
        string searchType,
        bool? activeOnly,
        string? chapter,
        bool? mappedOnly,
        int maxResults,
        int maximum)
    {
        var parameters = new List<string>
        {
            $"q={Uri.EscapeDataString(query)}",
            $"type={Uri.EscapeDataString(searchType)}",
            $"max={Math.Clamp(maxResults, 1, maximum)}"
        };

        if (activeOnly.HasValue)
        {
            parameters.Add($"activeOnly={activeOnly.Value.ToString().ToLowerInvariant()}");
        }

        if (!string.IsNullOrWhiteSpace(chapter))
        {
            parameters.Add($"chapter={Uri.EscapeDataString(chapter)}");
        }

        if (mappedOnly.HasValue)
        {
            parameters.Add($"mappedOnly={mappedOnly.Value.ToString().ToLowerInvariant()}");
        }

        return $"search?{string.Join("&", parameters)}";
    }

    private string BuildAbsoluteBaseUrl(string configuredUrl)
    {
        if (Uri.TryCreate(configuredUrl, UriKind.Absolute, out var absolute))
        {
            return EnsureTrailingSlash(absolute.ToString());
        }

        var appBaseUrl = _httpClient.BaseAddress
            ?? throw new InvalidOperationException("The application HTTP client has no base address.");
        return EnsureTrailingSlash(new Uri(appBaseUrl, configuredUrl.TrimStart('/')).ToString());
    }

    private string BuildUrl(string relativeUrl) =>
        $"{_baseUrl}{relativeUrl.TrimStart('/')}";

    private static string EnsureTrailingSlash(string value) =>
        value.EndsWith("/", StringComparison.Ordinal) ? value : $"{value}/";
}

public sealed record ReadV2ApiResult<T>(T Value, string? Error)
{
    public bool IsSuccess => Error is null;
}
