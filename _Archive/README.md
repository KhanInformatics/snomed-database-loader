# Archived Files

This folder contains development artifacts, implementation notes, and one-time-use scripts that were used during the initial development and testing of the terminology database loaders.

**Archived Date:** January 26, 2026

These files are preserved for reference but are not part of the active workflow.

## Archive Contents

### DMD/
| File | Purpose |
|------|---------|
| `Cleanup-ObsoleteFiles.ps1` | One-time cleanup utility (already executed) |
| `IMPLEMENTATION_SUMMARY.md` | Development notes from October 2025 |
| `StandaloneImports/COMPLETION_CHECKLIST.md` | Import validation checklist (completed) |
| `StandaloneImports/SUCCESS_SUMMARY.md` | Final import success summary |

### MSSQL/
| File | Purpose |
|------|---------|
| `CheckCredentials.ps1` | Simple credential display utility |
| `Fix-Duplicate-Records.ps1` | One-time duplicate fix script |
| `PCDTestData.ps1` | Development testing script for PCD data |
| `Simple-PCD-Validation.ps1` | Early validation script (superseded by `Quick-PCD-Validation.ps1`) |

### DMWB/
| File | Purpose |
|------|---------|
| `IMPLEMENTATION_SUMMARY.md` | Development notes for DMWB export |
| `TEST_FINDINGS.md` | Test results from initial validation |

## Note

The active scripts and documentation remain in their original locations:
- **MSSQL/** - Use `Quick-PCD-Validation.ps1` and `Validate-PCD-Import.ps1`
- **DMD/** - Use `Validate-RandomSamples.ps1` and `Validate-DMDImport.ps1`
- **DMWB/** - Use `Test-DMWBExport.ps1` for validation
