using System.Globalization;
using System.Net;
using System.Reflection;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;
using StaticBlazorSnomed.Models;
using StaticBlazorSnomed.Pages;
using StaticBlazorSnomed.Services;
using Syncfusion.Blazor;

CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("en-GB");
var root = Path.GetFullPath(args.FirstOrDefault() ?? "outputs/usage-viewer-fix/publish/wwwroot");
var checks = 0;
using var handler = new PublishedFilesHandler(root);
using var client = new HttpClient(handler) { BaseAddress = new Uri("https://usage.test/") };
var usage = new SnomedUsageStaticDataService(client);
var manifest = await usage.GetManifestAsync();
var acid = await usage.GetUsageDataAsync("698065002");
Check(acid.Count == 1 && acid[0].Usage[^1] == 199790, "Published acid reflux record: latest usage 199,790");
Check((await usage.GetUsageDataAsync(string.Join(',', manifest.TopConceptIds))).Count == 100, "All top 100 concepts load from published shards");
Check((await usage.GetUsageDataAsync(" , \n")).Count == 0, "Empty query returns no service results");

var services = new ServiceCollection();
services.AddLogging();
services.AddSingleton(usage);
services.AddSingleton<IJSRuntime, NoOpJsRuntime>();
services.AddSingleton<NavigationManager, TestNavigationManager>();
services.AddSyncfusionBlazor();
var activator = new CapturingActivator();
services.AddSingleton<IComponentActivator>(activator);
await using var provider = services.BuildServiceProvider();
await using var renderer = new HtmlRenderer(provider, provider.GetRequiredService<ILoggerFactory>());
await renderer.Dispatcher.InvokeAsync(async () =>
{
    var output = await renderer.RenderComponentAsync<UsageViewerSyncFu>();
    var page = activator.Page!;
    Check(!output.ToHtmlString().Contains("No usage data found"), "Initial rendered page has no premature no-data message");
    await Search("698065002");
    var html = output.ToHtmlString();
    Check(html.Contains("Acid reflux (finding)") && html.Contains("199,790") && html.Contains("Results: 1 result(s) found"), "Actual Razor component renders screenshot search results");
    Check(html.IndexOf("<th>2024-25</th>", StringComparison.Ordinal) < html.IndexOf("<th>2011-12</th>", StringComparison.Ordinal), "Reporting columns render newest first");
    await Search("00000000000000000000000");
    html = output.ToHtmlString();
    Check(html.Contains("No usage data found") && !html.Contains("alert-danger"), "Successful empty search renders only no-data message");
    await Search("invalid-code");
    html = output.ToHtmlString();
    Check(html.Contains("Invalid SNOMED CT code(s)") && !html.Contains("No usage data found"), "Invalid search renders validation without no-data message");
    await Search("");
    html = output.ToHtmlString();
    Check(html.Contains("Please enter at least one SNOMED CT code.") && !html.Contains("No usage data found"), "Blank search renders validation without no-data message");
    var formattedSuppressed = Method("FormatNumber").Invoke(page, [manifest.SuppressedValue]);
    Check(Equals(formattedSuppressed, "*"), "Published suppression sentinel formats as an asterisk");

    async Task Search(string codes)
    {
        typeof(UsageViewerSyncFu).GetField("searchCodes", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(page, codes);
        await (Task)Method("SearchUsageData").Invoke(page, null)!;
        typeof(ComponentBase).GetMethod("StateHasChanged", BindingFlags.Instance | BindingFlags.NonPublic)!.Invoke(page, null);
    }
});

using var failedHandler = new PublishedFilesHandler(root) { FailFirstManifest = true };
using var failedClient = new HttpClient(failedHandler) { BaseAddress = new Uri("https://usage.test/") };
var failedServices = new ServiceCollection();
failedServices.AddLogging();
failedServices.AddSingleton(new SnomedUsageStaticDataService(failedClient));
failedServices.AddSingleton<IJSRuntime, NoOpJsRuntime>();
failedServices.AddSingleton<NavigationManager, TestNavigationManager>();
failedServices.AddSyncfusionBlazor();
var failedActivator = new CapturingActivator();
failedServices.AddSingleton<IComponentActivator>(failedActivator);
await using var failedProvider = failedServices.BuildServiceProvider();
await using var failedRenderer = new HtmlRenderer(failedProvider, failedProvider.GetRequiredService<ILoggerFactory>());
await failedRenderer.Dispatcher.InvokeAsync(async () =>
{
    var output = await failedRenderer.RenderComponentAsync<UsageViewerSyncFu>();
    var html = output.ToHtmlString();
    Check(html.Contains("The usage data could not be loaded.") && !html.Contains("No usage data found"), "Manifest 404 renders error without misleading no-data message");
    var page = failedActivator.Page!;
    typeof(UsageViewerSyncFu).GetField("searchCodes", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(page, "698065002");
    await (Task)Method("SearchUsageData").Invoke(page, null)!;
    typeof(ComponentBase).GetMethod("StateHasChanged", BindingFlags.Instance | BindingFlags.NonPublic)!.Invoke(page, null);
    html = output.ToHtmlString();
    Check(html.Contains("199,790") && !html.Contains("The usage data could not be loaded.") && !html.Contains("No usage data found"), "Search after manifest 404 recovers in same actual Razor component");
});
Console.WriteLine($"PASS: {checks} published-data and Razor-render smoke checks.");

void Check(bool condition, string description)
{
    if (!condition) throw new InvalidOperationException("FAIL: " + description);
    checks++;
    Console.WriteLine("PASS: " + description);
}

static MethodInfo Method(string name) => typeof(UsageViewerSyncFu).GetMethod(name, BindingFlags.Instance | BindingFlags.NonPublic)!;

sealed class PublishedFilesHandler(string root) : HttpMessageHandler
{
    public bool FailFirstManifest { get; init; }
    private int _manifestRequests;

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var relative = request.RequestUri!.AbsolutePath.TrimStart('/');
        if (relative.EndsWith("manifest.json", StringComparison.Ordinal) && Interlocked.Increment(ref _manifestRequests) == 1 && FailFirstManifest)
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        var path = Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar));
        return Task.FromResult(File.Exists(path)
            ? new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(File.ReadAllText(path), System.Text.Encoding.UTF8, "application/json") }
            : new HttpResponseMessage(HttpStatusCode.NotFound));
    }
}

sealed class CapturingActivator : IComponentActivator
{
    public UsageViewerSyncFu? Page { get; private set; }
    public IComponent CreateInstance(Type componentType)
    {
        var instance = (IComponent)Activator.CreateInstance(componentType)!;
        if (instance is UsageViewerSyncFu page) Page = page;
        return instance;
    }
}

sealed class NoOpJsRuntime : IJSRuntime
{
    public ValueTask<TValue> InvokeAsync<TValue>(string identifier, object?[]? args) => ValueTask.FromResult(default(TValue)!);
    public ValueTask<TValue> InvokeAsync<TValue>(string identifier, CancellationToken cancellationToken, object?[]? args) => ValueTask.FromResult(default(TValue)!);
}

sealed class TestNavigationManager : NavigationManager
{
    public TestNavigationManager() => Initialize("https://usage.test/", "https://usage.test/usage-viewer-syncfusion");
    protected override void NavigateToCore(string uri, bool forceLoad) { }
}
