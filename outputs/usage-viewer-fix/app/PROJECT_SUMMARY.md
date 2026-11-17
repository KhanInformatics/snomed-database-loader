# 🏥 SNOMED CT Static Blazor Application - Project Summary

## 📋 Overview

A Blazor WebAssembly application providing NHS clinical terminology tools including SNOMED CT search, Read Code to SNOMED mappings, and Primary Care Domain Reference Set exploration. Deployed as an Azure Static Web App with Azure Functions backend.

**Live Site**: [KhanClinicalInformatics.net](https://khanclinicalinformatics.net)

---

## 🔧 Technology Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Blazor WebAssembly (.NET 8) |
| **UI Components** | Syncfusion Blazor (Grids, Buttons, Inputs) |
| **Styling** | Bootstrap 5, Font Awesome, Custom CSS |
| **Backend** | Azure Functions (C#) |
| **Data Sources** | NHS Ontology API, SQL Server |
| **Hosting** | Azure Static Web Apps |

---

## 📄 Pages & Features

### Core Search Tools

| Page | Route | Purpose |
|------|-------|---------|
| **Search** | `/search` | SNOMED CT concept lookup via NHS Ontology API |
| **Read Code Search** | `/readcode-search` | Map Read codes to SNOMED CT concepts |
| **Cluster Search** | `/cluster-search` | Query PCD Reference Sets by cluster ID |
| **ECL Query** | `/ecl-query` | Execute Expression Constraint Language queries |
| **Advanced Search** | `/advanced-search` | Multi-parameter SNOMED CT search |

### Utilities

| Page | Route | Purpose |
|------|-------|---------|
| **Usage Viewer** | `/usage-viewer-syncfusion` | View SNOMED CT usage statistics |
| **Test Connection** | `/test-connection` | Verify Azure Function connectivity |
| **Availability** | `/availability` | System availability checker |

### Information

| Page | Route | Purpose |
|------|-------|---------|
| **Home** | `/` | Landing page with quick access |
| **About** | `/about` | Application information |
| **Contact** | `/contact` | Contact details |

---

## 🗂️ Key Files

### Models

- **`SnomedModel.cs`** - SNOMED CT concept data structures
- **`ReadCodeMapping.cs`** - Read Code to SNOMED mapping structures

### Services

- **`AzureFunctionService.cs`** - HTTP client for Azure Functions API calls

### Configuration

- **`appsettings.json`** - Runtime configuration (Azure Function URLs)
- **`staticwebapp.config.json`** - Azure Static Web App routing/config
- **`Clusters.json`** - PCD Reference Set cluster definitions

---

## 🌐 Azure Functions Endpoints

The backend provides these API endpoints:

```
GET  /api/SnomedSearch?term={sctid}
GET  /api/ReadCodeSearch?code={readcode}
GET  /api/ClusterSearch?clusterId={id}
POST /api/ECLQuery
GET  /api/SnomedUsage
```

---

## 🚀 Development Commands

```powershell
# Build and run
dotnet clean; dotnet build --configuration Release; dotnet run

# Quick run script
.\PowershellScripts\Run.ps1

# Publish for deployment
dotnet publish -c Release
```

---

## 📊 Data Sources

| Source | Usage |
|--------|-------|
| **NHS Ontology API** | SNOMED CT concept lookups, FSN retrieval |
| **NHS TRUD** | Read Code to SNOMED mappings (DMWB) |
| **PCD Reference Sets** | Cluster-based SNOMED groupings |
| **Local SQL Server** | Usage statistics, cached data |

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 4.01.x | Dec 2025 | Read Code Search improvements, header styling |
| 4.00.x | Dec 2025 | Syncfusion integration, Cluster Search |
| 3.x | 2025 | ECL Query support, Advanced Search |
| 2.x | 2024 | Initial Read Code mapping |
| 1.x | 2024 | Basic SNOMED CT search |

---

## 👤 Author

**Imran Khan**  
[KhanClinicalInformatics.net](https://khanclinicalinformatics.net)  
GitHub: [KhanInformatics](https://github.com/KhanInformatics)
