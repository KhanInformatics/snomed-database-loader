using System.Globalization;
using System.Reflection;
using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.JSInterop;
using StaticBlazorSnomed.Pages;
using StaticBlazorSnomed.Services;
using Syncfusion.Blazor;

CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("en-GB");
var outputDirectory = Path.GetFullPath("..");
var services = new ServiceCollection();
services.AddLogging();
services.AddSingleton(new AzureFunctionService(new HttpClient(new PreviewDataHandler(Path.Combine(outputDirectory, "usage-data.json")))));
services.AddSingleton<IJSRuntime, PreviewJs>();
services.AddSingleton<NavigationManager, PreviewNavigation>();
services.AddSyncfusionBlazor();
var activator = new PreviewActivator();
services.AddSingleton<IComponentActivator>(activator);
await using var provider = services.BuildServiceProvider();
await using var renderer = new HtmlRenderer(provider, provider.GetRequiredService<ILoggerFactory>());
await renderer.Dispatcher.InvokeAsync(async () =>
{
    var output = await renderer.RenderComponentAsync<UsageViewerSyncFu>();
    var page = activator.Page!;
    typeof(UsageViewerSyncFu).GetField("searchCodes", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(page, "88551000000109, 968191000000100");
    await (Task)typeof(UsageViewerSyncFu).GetMethod("SearchUsageData", BindingFlags.Instance | BindingFlags.NonPublic)!.Invoke(page, null)!;
    typeof(ComponentBase).GetMethod("StateHasChanged", BindingFlags.Instance | BindingFlags.NonPublic)!.Invoke(page, null);
    var html = output.ToHtmlString();
    if (!html.Contains("Results: 2 result(s) found") || !html.Contains("6,656,430") || !html.Contains("570,300"))
        throw new InvalidOperationException("Expected live usage results were not rendered.");
    var document = """
        <!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Compact usage viewer — rendered component preview</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
        <link href="https://cdn.syncfusion.com/blazor/29.2.10/styles/bootstrap5.css" rel="stylesheet">
        <link href="http://127.0.0.1:5198/css/app.css" rel="stylesheet">
        <link href="http://127.0.0.1:5198/StaticBlazorSnomed.styles.css" rel="stylesheet">
        </head><body>
        """ + html + "</body></html>";
    await File.WriteAllTextAsync(Path.Combine(outputDirectory, "preview.html"), document);
    await File.WriteAllTextAsync(Path.Combine(outputDirectory, "desktop.html"), "<!doctype html><html><head><title>Desktop layout preview</title><style>body{margin:0;width:1440px}iframe{border:0;width:1440px;height:650px}</style></head><body><iframe src='preview.html' title='Desktop usage viewer'></iframe></body></html>");
    Console.WriteLine("Rendered actual Razor component with both live usage results; saved preview.html and desktop.html.");
});

sealed class PreviewDataHandler(string path) : HttpMessageHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
        new(System.Net.HttpStatusCode.OK) { Content = new StringContent(await File.ReadAllTextAsync(path, cancellationToken), System.Text.Encoding.UTF8, "application/json") };
}
sealed class PreviewActivator : IComponentActivator
{
    public UsageViewerSyncFu? Page { get; private set; }
    public IComponent CreateInstance(Type type)
    {
        var instance = (IComponent)Activator.CreateInstance(type)!;
        if (instance is UsageViewerSyncFu page) Page = page;
        return instance;
    }
}
sealed class PreviewJs : IJSRuntime
{
    public ValueTask<TValue> InvokeAsync<TValue>(string identifier, object?[]? args) => ValueTask.FromResult(default(TValue)!);
    public ValueTask<TValue> InvokeAsync<TValue>(string identifier, CancellationToken token, object?[]? args) => InvokeAsync<TValue>(identifier, args);
}
sealed class PreviewNavigation : NavigationManager
{
    public PreviewNavigation() => Initialize("http://127.0.0.1:5199/", "http://127.0.0.1:5199/preview.html");
    protected override void NavigateToCore(string uri, bool forceLoad) { }
}
