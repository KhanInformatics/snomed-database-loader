# SNOMED usage data refresh

The `.txt` files in this directory are local source extracts and are deliberately
ignored by Git. The generated, deployable JSON is committed under
`wwwroot/data/snomed-usage`.

These JSON files are required at runtime by `/usage-viewer-syncfusion`; do not
remove them during asset cleanup. Build and publish check that the manifest and
its expected number of versioned shards are present, including in Azure CI/CD.
Missing files cause HTTP 404 errors for every usage search.

## Expected source files

Use one NHS usage extract per reporting period, retaining the original filename:

```text
SNOMED_code_usage_YYYY-YY.txt
```

The generator requires the reporting periods to be contiguous. It validates the
header, every row, active flags, usage values, concept IDs, and duplicate
concept/period records before changing the generated output.

## Generate a new dataset

From the repository root, run:

```powershell
dotnet run --project Tools/SnomedUsageShardGenerator -- "Usage data" "wwwroot/data/snomed-usage"
```

The command creates:

- `manifest.json`, which tells the app the periods, current version, hash, and
  latest-period top 100 concepts;
- 1,024 JSON shards in a versioned directory named after the latest period.

The files are deterministic: running the generator twice with identical source
data produces identical content. Commit the updated manifest and the new
versioned shard directory. Once the new dataset is deployed, an older versioned
directory can be removed in a subsequent deployment if it is no longer needed.

## Stored values

- `0` means the concept had no published usage row for that period.
- `-1` is the internal sentinel for the NHS `*` value, meaning a suppressed
  usage count of 1–4. The viewer and CSV export display this as `*`.
- The description is the most recent description published for that concept.

The browser uses stable FNV-1a hashing to request only the shards needed for a
search. Do not replace it with `.NET string.GetHashCode()`, which is not stable
between processes.
