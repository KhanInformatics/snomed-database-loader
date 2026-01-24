# Terminology Reporting Dashboard

Two approaches for displaying terminology update data in a Blazor app:

## 🚀 Option A: Blob Storage (Recommended for Simple Dashboards)

**Best for**: Quick setup, no database cold-start, instant loading

### How it works
- `Export-ReportToBlob.ps1` uploads a JSON file to Azure Blob Storage after each update
- Blazor component reads the JSON directly - no API, no database!
- Super fast: ~100ms load time

### Setup

1. Copy `TerminologyDashboardBlob.razor` to your Blazor Pages folder
2. The SAS URL is already configured (valid until 2027-01-24)
3. Done! Navigate to `/terminology-dashboard`

### Files
- `TerminologyDashboardBlob.razor` - Complete dashboard component
- `Export-ReportToBlob.ps1` - PowerShell script that uploads JSON to blob

### Regenerating SAS Token (when it expires)
```powershell
$connString = (Get-Content .\Config\TerminologyConfig.json | ConvertFrom-Json).azureBlobStorage.connectionString
$expiry = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
az storage blob generate-sas --account-name snomedviewerstorage --container-name "terminology-reports" --name "terminology-dashboard.json" --permissions r --expiry $expiry --connection-string $connString --full-uri -o tsv
```

---

## 📊 Option B: Azure SQL Database (For History & Analytics)

**Best for**: Historical tracking, trend analysis, querying past runs

### How it works
- `Export-ReportToAzure.ps1` writes results to Azure SQL after each update
- Minimal API provides RESTful endpoints
- Blazor component calls the API

### Setup

1. Copy the models and DbContext from `TerminologyReportingApi.cs` to your project
2. Add the NuGet packages:
   ```bash
   dotnet add package Microsoft.EntityFrameworkCore.SqlServer
   dotnet add package Azure.Identity
   ```
3. Register DbContext in `Program.cs`:
   ```csharp
   builder.Services.AddDbContext<ReportingDbContext>(options =>
       options.UseSqlServer(builder.Configuration.GetConnectionString("ReportingDb")));
   ```
4. Add the connection string to `appsettings.json`
5. Add the API endpoints or controller

### Option 2: Create Standalone API

```bash
# Create new minimal API project
dotnet new webapi -n TerminologyReportingApi -minimal
cd TerminologyReportingApi

# Add packages
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Azure.Identity

# Copy the code from TerminologyReportingApi.cs
# Update appsettings.json with connection string
# Run
dotnet run
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard` | Main dashboard data with latest run and stats |
| GET | `/api/runs` | List all runs (paginated) |
| GET | `/api/runs/{id}` | Get run details with steps and errors |
| GET | `/api/latest` | Get latest run summary only |
| GET | `/api/releases` | Get TRUD release history |
| GET | `/api/errors` | Get recent errors |
| GET | `/api/stats` | Get overall statistics |

## Example Response: `/api/dashboard`

```json
{
  "latestRun": {
    "runId": "72994ebd-3f37-43c9-8956-0b68f8101795",
    "startTime": "2026-01-24T17:35:43",
    "durationFormatted": "00:05:23",
    "overallSuccess": true,
    "snomedVersion": "20250115",
    "conceptCount": 1234567,
    "dmdVersion": "5.2.0_20250115",
    "vmpCount": 15678,
    "ampCount": 98765,
    "snomedValidationRate": 92.80,
    "errorCount": 0
  },
  "recentRuns": [...],
  "totalRuns": 1,
  "successfulRuns": 1,
  "failedRuns": 0,
  "lastSuccessfulUpdate": "2026-01-24T17:35:43"
}
```

## Blazor Dashboard Components

### TerminologyDashboardBlob.razor (Option A)
- Reads directly from Azure Blob Storage
- No API required
- Instant load, no cold-start

### TerminologyDashboard.razor (Option B)
- Calls REST API backed by Azure SQL
- Full history and analytics
- Stats cards, run details, error tracking

---

## 🔄 Using BOTH Approaches

The weekly update script exports to **both** destinations:
1. **Blob** → For instant dashboard access (no database wake time)
2. **SQL** → For historical tracking and analytics

This gives you the best of both worlds!

### Architecture
```
Weekly Update → Export-ReportToAzure.ps1 → Azure SQL (history)
             ↘ Export-ReportToBlob.ps1  → Azure Blob (instant)
                                              ↓
                              Blazor App → TerminologyDashboardBlob.razor
```

---

## Azure AD Authentication

The SQL connection string uses `Authentication=Active Directory Default` which will:

1. **Local development**: Use your Azure CLI or Visual Studio credentials
2. **Azure App Service**: Use Managed Identity (recommended)
3. **Other environments**: Use environment variables or Azure SDK credential chain

### Enable Managed Identity (Production)

1. Enable System Managed Identity on your App Service
2. Add the identity as a user in Azure SQL:
   ```sql
   CREATE USER [your-app-service-name] FROM EXTERNAL PROVIDER;
   ALTER ROLE db_datareader ADD MEMBER [your-app-service-name];
   ```

---

## Files in this folder

| File | Description |
|------|-------------|
| `TerminologyDashboardBlob.razor` | 🚀 Blob-based dashboard (Option A - recommended) |
| `TerminologyDashboard.razor` | API-based dashboard (Option B) |
| `TerminologyReportingApi.cs` | Complete API code (models, DbContext, endpoints) |
| `appsettings.json` | Configuration with connection strings |
| `README.md` | This file |

## Connection Details

| Resource | Value |
|----------|-------|
| Blob URL | `https://snomedviewerstorage.blob.core.windows.net/terminology-reports/terminology-dashboard.json` |
| SQL Server | `azuresnnomedct.database.windows.net` |
| SQL Database | `ReportingServer` |
