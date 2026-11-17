using System.Globalization;
using System.Net;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;
using StaticBlazorSnomed.Models;
using StaticBlazorSnomed.Pages;
using StaticBlazorSnomed.Services;
using Syncfusion.Blazor;
using Syncfusion.Blazor.Inputs;

CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("en-GB");
var checks = 0;
using var handler = new SqlApiHandler();
using var client = new HttpClient(handler);
var api = new AzureFunctionService(client);
var services = new ServiceCollection();
services.AddLogging();
services.AddSingleton(api);
var js = new CapturingJsRuntime();
services.AddSingleton<IJSRuntime>(js);
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
    Check(handler.Requests.Count == 0 && !output.ToHtmlString().Contains("No usage data found"), "Initial page needs no static manifest or API request");

    await Search("698065002");
    var html = output.ToHtmlString();
    Check(html.Contains("Acid reflux (finding)") && html.Contains("199,790") && html.Contains("Results: 1 result(s) found"), "SQL response for screenshot code renders latest usage");
    Check(handler.Requests[^1].AbsolutePath == "/api/getsnomeddata" && handler.Requests[^1].Query == "?codes=698065002", "Search uses the existing SQL Azure Function endpoint");
    Check(html.Contains("(England)") && html.Contains("usage-cell\">*</span>"), "SQL geographic coverage and numeric suppression sentinel render");
    Check(html.IndexOf("<th>2024-25</th>", StringComparison.Ordinal) < html.IndexOf("<th>2011-12</th>", StringComparison.Ordinal), "Reporting columns render newest first");

    Method("SetExampleCodes").Invoke(page, [UsageViewerSyncFu.ExampleType.TopUsed2024]);
    var topCodes = (string)Field("searchCodes").GetValue(page)!;
    Check(topCodes.Split(',').Distinct().Count() == 100, "Historical top-100 SQL search template is preserved");

    handler.ResponseJson = "[]";
    await Search("00000000000000000000000");
    html = output.ToHtmlString();
    Check(html.Contains("No usage data found") && !html.Contains("alert-danger"), "Successful empty SQL response renders only no-data message");

    handler.Reset();
    await Search("698065002");
    handler.Status = HttpStatusCode.NotFound;
    handler.ResponseJson = "Internal diagnostic details must not appear in the UI";
    await Search("698065002");
    html = output.ToHtmlString();
    Check(html.Contains("The usage data could not be loaded. Please try again.") && !html.Contains("No usage data found") && !html.Contains("Results: 1") && !html.Contains("Internal diagnostic"), "API 404 renders readable error, clears stale results, and excludes no-data");
    handler.Reset();
    await Search("698065002");
    html = output.ToHtmlString();
    Check(html.Contains("199,790") && !html.Contains("The usage data could not be loaded") && !html.Contains("No usage data found"), "Same page retries the SQL API successfully after 404");

    var beforeInvalid = handler.Requests.Count;
    await Search("invalid-code");
    html = output.ToHtmlString();
    Check(html.Contains("Invalid SNOMED CT code(s)") && !html.Contains("No usage data found") && !html.Contains("Results: 1") && handler.Requests.Count == beforeInvalid, "Invalid input validates locally and clears stale results");
    await Search(" , ; \n");
    html = output.ToHtmlString();
    Check(html.Contains("Please enter at least one SNOMED CT code.") && !html.Contains("No usage data found") && handler.Requests.Count == beforeInvalid, "Blank and separator-only input validates without a request");

    await Search("698065002 ; 1022541000000102\n698065002");
    Check(Uri.UnescapeDataString(handler.Requests[^1].Query) == "?codes=698065002,1022541000000102", "Input event tracks and normalizes multiple codes before searching");

    handler.Gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
    var pendingSearch = InvokeSearch();
    Render();
    html = output.ToHtmlString();
    Check(Regex.IsMatch(html, "<button[^>]*disabled[^>]*>\\s*CLEAR", RegexOptions.Singleline) && !html.Contains("Results: 1") && !html.Contains("No usage data found"), "Loading disables clear and hides previous results and no-data message");
    var duringLoad = handler.Requests.Count;
    await InvokeSearch();
    Check(handler.Requests.Count == duringLoad, "Duplicate search during loading does not start another API request");
    handler.Gate.SetResult();
    await pendingSearch;
    handler.Gate = null;
    Render();

    handler.ResponseJson = JsonSerializer.Serialize(new[] { new SnomedUsageData
    {
        ConceptId = "698065002", Procedure = "Acid reflux, \"quoted\"\r\nfinding",
        GeographicCoverage = "England, UK", Usage_2024_25 = 199790, Usage_2023_24 = -1
    }});
    await Search("698065002");
    CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("de-DE");
    await (Task)Method("ExportToCsv").Invoke(page, null)!;
    CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("en-GB");
    var csv = (string)js.LastArguments![1]!;
    Check(js.LastIdentifier == "downloadFile" && csv.StartsWith("SNOMED CT Code,Procedure,Geographic Coverage,2024-25,2023-24"), "CSV preserves geographic coverage and newest-first headers");
    Check(csv.Contains("\"Acid reflux, \"\"quoted\"\"\r\nfinding\",\"England, UK\",199790,*,0") && !csv.Contains("199.790"), "CSV escapes quotes, commas, and newlines and uses invariant numeric values");
    Check(handler.Requests.All(uri => uri.Host == "snomed-viewer-function.azurewebsites.net" && uri.AbsolutePath == "/api/getsnomeddata"), "All data requests use SQL API; none request static files");
    Method("ClearData").Invoke(page, null);
    Render();
    html = output.ToHtmlString();
    Check(!html.Contains("Results: 1") && !html.Contains("No usage data found") && !html.Contains("alert-danger"), "Clear returns the page to its initial state");

    async Task Search(string codes)
    {
        Method("OnSearchCodesInput").Invoke(page, [new TextAreaInputEventArgs { Value = codes }]);
        await InvokeSearch();
        Render();
    }

    Task InvokeSearch() => (Task)Method("SearchUsageData").Invoke(page, null)!;
    void Render() => typeof(ComponentBase).GetMethod("StateHasChanged", BindingFlags.Instance | BindingFlags.NonPublic)!.Invoke(page, null);
});

if (args.Contains("--live"))
{
    using var liveClient = new HttpClient();
    var liveApi = new AzureFunctionService(liveClient);
    var results = await liveApi.GetUsageDataAsync("698065002");
    Check(results.Count == 1 && results[0].ConceptId == "698065002" && results[0].Usage_2024_25 == 199790, "Live SQL API returns acid reflux latest usage 199,790 through real DTO deserialization");
}

Console.WriteLine($"PASS: {checks} SQL API and actual Razor component smoke checks.");
void Check(bool condition, string description)
{
    if (!condition) throw new InvalidOperationException("FAIL: " + description);
    checks++;
    Console.WriteLine("PASS: " + description);
}
static MethodInfo Method(string name) => typeof(UsageViewerSyncFu).GetMethod(name, BindingFlags.Instance | BindingFlags.NonPublic)!;
static FieldInfo Field(string name) => typeof(UsageViewerSyncFu).GetField(name, BindingFlags.Instance | BindingFlags.NonPublic)!;

sealed class SqlApiHandler : HttpMessageHandler
{
    private const string DefaultJson = """
        [{"SNOMED_Concept_ID":"698065002","Description":"Acid reflux (finding)","Geographic_Coverage":"England",
          "2024-25_Usage":199790,"2023-24_Usage":-1,"2022-23_Usage":12345,"2011-12_Usage":123}]
        """;
    public List<Uri> Requests { get; } = [];
    public HttpStatusCode Status { get; set; } = HttpStatusCode.OK;
    public string ResponseJson { get; set; } = DefaultJson;
    public TaskCompletionSource? Gate { get; set; }
    public void Reset() { Status = HttpStatusCode.OK; ResponseJson = DefaultJson; }
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Requests.Add(request.RequestUri!);
        if (Gate is not null) await Gate.Task.WaitAsync(cancellationToken);
        return new HttpResponseMessage(Status) { Content = new StringContent(ResponseJson, Encoding.UTF8, "application/json") };
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
sealed class CapturingJsRuntime : IJSRuntime
{
    public string? LastIdentifier { get; private set; }
    public object?[]? LastArguments { get; private set; }
    public ValueTask<TValue> InvokeAsync<TValue>(string identifier, object?[]? args)
    {
        LastIdentifier = identifier;
        LastArguments = args;
        return ValueTask.FromResult(default(TValue)!);
    }
    public ValueTask<TValue> InvokeAsync<TValue>(string identifier, CancellationToken cancellationToken, object?[]? args) => InvokeAsync<TValue>(identifier, args);
}
sealed class TestNavigationManager : NavigationManager
{
    public TestNavigationManager() => Initialize("https://usage.test/", "https://usage.test/usage-viewer-syncfusion");
    protected override void NavigateToCore(string uri, bool forceLoad) { }
}
