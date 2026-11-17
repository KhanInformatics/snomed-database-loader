using System.Collections.Concurrent;
using System.Net;
using System.Text;
using StaticBlazorSnomed.Services;
using Xunit;

namespace StaticBlazorSnomed.Tests;

public sealed class SnomedUsageStaticDataServiceTests
{
    private const string ManifestPath = "/data/snomed-usage/manifest.json";
    private const string ShardPath = "/data/snomed-usage/test-data/0000.json";
    private const string ConceptId = "698065002";
    private const string ManifestJson = """
        {"schemaVersion":1,"datasetVersion":"test-data","geographicCoverage":"England",
         "periods":["2022-23","2023-24"],"bucketCount":1,"hashAlgorithm":"fnv1a32"}
        """;
    private const string ShardJson = """
        {"698065002":["Acid reflux (finding)",1234,5678]}
        """;

    [Fact]
    public async Task Manifest404CanBeRetriedByTheNextSearch()
    {
        using var handler = new StubHandler((path, attempt, _) => Task.FromResult(
            path == ManifestPath && attempt == 1
                ? new HttpResponseMessage(HttpStatusCode.NotFound)
                : Json(path == ManifestPath ? ManifestJson : ShardJson)));
        using var client = CreateClient(handler);
        var service = new SnomedUsageStaticDataService(client);

        var error = await Assert.ThrowsAsync<HttpRequestException>(() => service.GetUsageDataAsync(ConceptId));
        Assert.Equal(HttpStatusCode.NotFound, error.StatusCode);

        AssertUsage(await service.GetUsageDataAsync(ConceptId));
        Assert.Equal(2, handler.Count(ManifestPath));
        Assert.Equal(1, handler.Count(ShardPath));
    }

    [Theory]
    [InlineData(HttpStatusCode.NotFound)]
    [InlineData(HttpStatusCode.ServiceUnavailable)]
    public async Task FailedShardCanBeRetriedWithoutReloadingTheManifest(HttpStatusCode status)
    {
        using var handler = new StubHandler((path, attempt, _) => Task.FromResult(
            path == ShardPath && attempt == 1
                ? new HttpResponseMessage(status)
                : Json(path == ManifestPath ? ManifestJson : ShardJson)));
        using var client = CreateClient(handler);
        var service = new SnomedUsageStaticDataService(client);

        var error = await Assert.ThrowsAsync<HttpRequestException>(() => service.GetUsageDataAsync(ConceptId));
        Assert.Equal(status, error.StatusCode);

        AssertUsage(await service.GetUsageDataAsync(ConceptId));
        AssertUsage(await service.GetUsageDataAsync(ConceptId));
        Assert.Equal(1, handler.Count(ManifestPath));
        Assert.Equal(2, handler.Count(ShardPath));
    }

    [Fact]
    public async Task SuccessfulManifestAndShardAreCachedAcrossSearches()
    {
        using var handler = new StubHandler((path, _, _) => Task.FromResult(
            Json(path == ManifestPath ? ManifestJson : ShardJson)));
        using var client = CreateClient(handler);
        var service = new SnomedUsageStaticDataService(client);

        var manifest = await service.GetManifestAsync();
        AssertUsage(await service.GetUsageDataAsync(ConceptId));
        AssertUsage(await service.GetUsageDataAsync($"{ConceptId}, {ConceptId}"));

        Assert.Same(manifest, await service.GetManifestAsync());
        Assert.Equal(1, handler.Count(ManifestPath));
        Assert.Equal(1, handler.Count(ShardPath));
    }

    [Fact]
    public async Task ConcurrentManifestRequestsShareOneLoad()
    {
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var handler = new StubHandler(async (_, _, cancellationToken) =>
        {
            await release.Task.WaitAsync(cancellationToken);
            return Json(ManifestJson);
        });
        using var client = CreateClient(handler);
        var service = new SnomedUsageStaticDataService(client);

        var requests = Enumerable.Range(0, 20).Select(_ => service.GetManifestAsync()).ToArray();
        Assert.Equal(1, handler.Count(ManifestPath));
        release.SetResult();
        var manifests = await Task.WhenAll(requests);

        Assert.All(manifests, manifest => Assert.Same(manifests[0], manifest));
        Assert.Equal(1, handler.Count(ManifestPath));
    }

    [Fact]
    public async Task ConcurrentSearchesShareOneShardLoad()
    {
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var handler = new StubHandler(async (path, _, cancellationToken) =>
        {
            if (path == ManifestPath)
            {
                return Json(ManifestJson);
            }

            await release.Task.WaitAsync(cancellationToken);
            return Json(ShardJson);
        });
        using var client = CreateClient(handler);
        var service = new SnomedUsageStaticDataService(client);

        var requests = Enumerable.Range(0, 20).Select(_ => service.GetUsageDataAsync(ConceptId)).ToArray();
        Assert.Equal(1, handler.Count(ShardPath));
        release.SetResult();
        var results = await Task.WhenAll(requests);

        Assert.All(results, AssertUsage);
        Assert.Equal(1, handler.Count(ManifestPath));
        Assert.Equal(1, handler.Count(ShardPath));
    }

    [Theory]
    [InlineData(ManifestPath)]
    [InlineData(ShardPath)]
    public async Task CanceledLoadCanBeRetried(string canceledPath)
    {
        using var handler = new StubHandler((path, attempt, _) =>
            path == canceledPath && attempt == 1
                ? Task.FromCanceled<HttpResponseMessage>(new CancellationToken(canceled: true))
                : Task.FromResult(Json(path == ManifestPath ? ManifestJson : ShardJson)));
        using var client = CreateClient(handler);
        var service = new SnomedUsageStaticDataService(client);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => service.GetUsageDataAsync(ConceptId));

        AssertUsage(await service.GetUsageDataAsync(ConceptId));
        Assert.Equal(2, handler.Count(canceledPath));
    }

    private static void AssertUsage(IReadOnlyList<Models.SnomedUsageResult> results)
    {
        var result = Assert.Single(results);
        Assert.Equal(ConceptId, result.ConceptId);
        Assert.Equal("Acid reflux (finding)", result.Description);
        Assert.Equal("England", result.GeographicCoverage);
        Assert.Equal(new long[] { 1234, 5678 }, result.Usage);
    }

    private static HttpClient CreateClient(HttpMessageHandler handler) =>
        new(handler) { BaseAddress = new Uri("https://usage.test/") };

    private static HttpResponseMessage Json(string json) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(json, Encoding.UTF8, "application/json")
    };

    private sealed class StubHandler(
        Func<string, int, CancellationToken, Task<HttpResponseMessage>> respond) : HttpMessageHandler
    {
        private readonly ConcurrentDictionary<string, int> _requestCounts = new(StringComparer.Ordinal);

        public int Count(string path) => _requestCounts.GetValueOrDefault(path);

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var path = request.RequestUri!.AbsolutePath;
            var attempt = _requestCounts.AddOrUpdate(path, 1, (_, count) => count + 1);
            return respond(path, attempt, cancellationToken);
        }
    }
}
