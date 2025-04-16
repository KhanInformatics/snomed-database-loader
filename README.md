# SNOMED CT Database Loader

This repository provides scripts specifically for building and maintaining a **SNOMED CT database instance** using the **Monolith** and **UK Primary Care** snapshots released via **NHS TRUD**.

It supports loading data into a variety of databases, with a full end-to-end **automated workflow for Microsoft SQL Server**, including:

- Checking for new releases via the TRUD API
- Downloading and extracting release files
- Generating and executing `BULK INSERT` SQL scripts for snapshot import

## Supported Targets

- **MSSQL** – Fully automated (PowerShell-driven)
- MySQL
- MySQL with optimized views
- PostgreSQL
- Neo4j
- Python DataFrame

> ⚠️ This repository is **not** a general-purpose RF2 loader. It is purpose-built for loading the **Monolith** and **UK Primary Care Snapshot** releases into a local database instance for analytics, reporting, or interoperability work.

Contributions are welcome — feel free to fork the repo and submit a pull request if you'd like to add or improve support for other environments.
