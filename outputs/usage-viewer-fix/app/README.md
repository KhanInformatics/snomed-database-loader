# SNOMED CT & Clinical Terminology Blazor Application

A modern Blazor WebAssembly application for searching and exploring NHS clinical terminology including SNOMED CT concepts, Read Code mappings, and Primary Care Domain Reference Sets. Built with Syncfusion components and Azure Functions backend.

## 🎯 Purpose

This application provides healthcare professionals, developers, and clinical informaticians with tools to:

- **Search SNOMED CT concepts** using the NHS Ontology API
- **Browse READ v2** concepts, terms, hierarchy and native cross-maps
- **Map Read codes to SNOMED CT** using NHS Digital's assured mappings
- **Explore Primary Care Domain Reference Sets** (PCD Refsets) by cluster ID
- **Execute ECL queries** (Expression Constraint Language) for advanced SNOMED CT searches
- **View SNOMED CT usage statistics** from clinical systems

## ✨ Features

### 🔍 Search Tools

| Feature | Description |
|---------|-------------|
| **SNOMED CT Search** | Search concepts by SCTID using the NHS Ontology API |
| **READ v2 Browser** | Search case-sensitive READ codes and synonyms, browse the hierarchy, and inspect terms and native maps |
| **Read Code Search** | Find SNOMED CT mappings for Read codes (Clinical Terms v2/v3) |
| **Cluster Search** | Search PCD Reference Sets by cluster ID (e.g., ADDISONS_COD, SMOK_COD) |
| **ECL Query** | Execute Expression Constraint Language queries |
| **Advanced Search** | Multi-parameter search with filters |

### 📊 Data Viewers

- **Usage Viewer** - Syncfusion-powered grid for viewing SNOMED CT usage data
- **Test Connection** - Verify Azure Function connectivity

### 🎨 User Interface

- **Responsive Design** - Works on desktop and mobile
- **Syncfusion Blazor Components** - Professional grids, buttons, and inputs
- **Consistent Headers** - Uniform page styling across all tools
- **Export Capability** - CSV/Excel export from data grids

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Blazor WebAssembly                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │   Search    │ │  ReadCode   │ │   Cluster   │  ...      │
│  │   Page      │ │   Search    │ │   Search    │           │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘           │
│         │               │               │                   │
│         └───────────────┼───────────────┘                   │
│                         ▼                                   │
│              ┌──────────────────┐                           │
│              │ AzureFunctionSvc │                           │
│              └────────┬─────────┘                           │
└───────────────────────┼─────────────────────────────────────┘
                        │ HTTPS
                        ▼
            ┌───────────────────────┐
            │   Azure Functions     │
            │  ┌─────────────────┐  │
            │  │ SNOMED Search   │  │
            │  │ ReadCode Lookup │  │
            │  │ Cluster Search  │  │
            │  │ ECL Query       │  │
            │  └─────────────────┘  │
            └───────────┬───────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │  NHS Ontology API /   │
            │  SQL Server Database  │
            └───────────────────────┘
```

## 📁 Project Structure

```
StaticBlazorSnomed/
├── Models/
│   ├── SnomedModel.cs           # SNOMED CT data models
│   └── ReadCodeMapping.cs       # Read Code mapping models
├── Pages/
│   ├── Index.razor              # Home page
│   ├── Search.razor             # SNOMED CT NHS API search
│   ├── ReadV2Browser.razor      # READ v2 search and hierarchy workbench
│   ├── ReadCodeSearch.razor     # Read Code to SNOMED mapping
│   ├── ClusterSearch.razor      # PCD Reference Set search
│   ├── AdvancedSearch.razor     # Multi-parameter search
│   ├── GetSnomedCodesFromECL.razor  # ECL query tool
│   ├── UsageViewerSyncFu.razor  # Usage statistics viewer
│   ├── TestConnection.razor     # Connection testing
│   └── About.razor              # About page
├── Services/
│   ├── AzureFunctionService.cs  # Azure Functions HTTP client
│   └── ReadV2ApiService.cs      # READ v2 terminology API client
├── Shared/
│   ├── MainLayout.razor         # Main layout with sidebar
│   ├── NavMenu.razor            # Navigation menu
│   └── LoadingSpinner.razor     # Loading component
├── wwwroot/
│   ├── index.html               # HTML host page
│   ├── appsettings.json         # Configuration
│   ├── css/app.css              # Custom styles
│   └── js/app.js                # JavaScript utilities
├── Program.cs                   # Application entry point
├── App.razor                    # Root component
└── staticwebapp.config.json     # Azure Static Web App config
```

## 🚀 Getting Started

### Prerequisites

- .NET 8.0 SDK
- Visual Studio 2022 or VS Code
- Azure Functions backend (see Azure Functions Setup)
- Access to the configured READ v2 Azure Function

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/KhanInformatics/StaticBlazorSnomed.git
   cd StaticBlazorSnomed/StaticBlazorSnomed
   ```

2. **Configure Azure Function endpoint**
   
   Update `Services/AzureFunctionService.cs` with your Azure Function URL:
   ```csharp
   private const string AzureFunctionBaseUrl = "https://your-function-app.azurewebsites.net/api/";
   ```

3. **Build and run**
   ```bash
   dotnet build
   dotnet run
   ```

4. **Access the application**
   
   Navigate to `http://localhost:5187`

### READ v2 browser locally

The WebAssembly application never receives SQL credentials or connects directly
to SQL Server. Development and production are configured to use the deployed
READ v2 Azure Function:

```json
"ReadV2Api": {
  "BaseUrl": "https://readv2-browser-function.azurewebsites.net/api/readv2/"
}
```

Run the client from this project with `dotnet run`. The launch profile uses
`http://localhost:5187`, which is allowed by the Function's CORS configuration.
The local SQL Server `READv2` database remains available for backend development,
and the companion .NET 8 Function is in
`..\StaticFunctionSnomed\src\ReadV2AzureFunction`. Native NHS keyword ordering
also requires `dbo.ReadV2KeywordPosting`; create and populate it with the guarded
importer documented in
`..\StaticFunctionSnomed\tools\ReadV2KeywordImporter\README.md`.

### Quick Run Script

```powershell
# From the project directory
.\PowershellScripts\Run.ps1
```

## ⚙️ Azure Functions Setup

The application requires Azure Functions providing these endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/snomed-search` | GET | Search SNOMED CT by term/ID |
| `/api/readcode-search` | GET | Search Read Code mappings |
| `/api/cluster-search` | GET | Search PCD Reference Sets |
| `/api/ecl-query` | POST | Execute ECL queries |
| `/api/readv2/chapters` | GET | Load top-level READ v2 hierarchy chapters |
| `/api/readv2/search` | GET | Search READ v2 terms or an exact case-sensitive code |
| `/api/readv2/concept/{code}` | GET | Load a concept with terms and cross-maps |
| `/api/readv2/children/{code}` | GET | Load direct hierarchy children |
| `/api/readv2/ancestors/{code}` | GET | Load the ancestor path for a concept |

## 🌐 Deployment

### Azure Static Web Apps (Recommended)

1. Push code to GitHub
2. Create Azure Static Web App in Azure Portal
3. Connect to your GitHub repository
4. Configure build:
   - **App location**: `/StaticBlazorSnomed`
   - **Output location**: `wwwroot`

### Manual Deployment

```bash
dotnet publish -c Release
# Upload contents of bin/Release/net8.0/publish/wwwroot to your host
```

See [DEPLOYMENT.md](DEPLOYMENT.md) and [AZURE_DEPLOYMENT_GUIDE.md](AZURE_DEPLOYMENT_GUIDE.md) for detailed instructions.

## 🔗 Related Resources

- [SNOMED International](https://www.snomed.org/)
- [SNOMED CT Browser](https://browser.ihtsdotools.org/)
- [NHS Digital Terminology Server](https://digital.nhs.uk/services/terminology-server)
- [NHS TRUD](https://isd.digital.nhs.uk/trud) - Technology Reference Update Distribution

## 👤 Author

Created by **Imran Khan** - [KhanClinicalInformatics.net](https://khanclinicalinformatics.net)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -m 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Open a Pull Request
