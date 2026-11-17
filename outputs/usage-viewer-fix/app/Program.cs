using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using StaticBlazorSnomed;
using StaticBlazorSnomed.Services;
using Syncfusion.Blazor;
using Syncfusion.Licensing;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

// Register Syncfusion license - REPLACE WITH YOUR ACTUAL LICENSE KEY
SyncfusionLicenseProvider.RegisterLicense("MzkwNDIwOUAzMjM5MmUzMDJlMzAzYjMyMzkzYk92ZnZTVFpVWVFOMlQyQXFTeGcwbS9yV20wb0hXTzZRc0lvdVpneUNTQ1k9");

builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

builder.Services.AddScoped(sp => new HttpClient { BaseAddress = new Uri(builder.HostEnvironment.BaseAddress) });
builder.Services.AddScoped<AzureFunctionService>();
builder.Services.AddScoped<SnomedUsageStaticDataService>();
builder.Services.AddScoped<ReadV2ApiService>();
builder.Services.AddSyncfusionBlazor();

await builder.Build().RunAsync();
