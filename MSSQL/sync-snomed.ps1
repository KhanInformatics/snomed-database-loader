# Define paths
$localPath = "C:\SNOMEDCT\*"
# Path to your local clone of the repo. Change if your clone is located elsewhere.
$repoPath = "C:\Users\mik78\snomed-database-loader"
$remoteFolder = Join-Path $repoPath "MSSQL"

# Change directory to the repo folder
Set-Location $repoPath

# Ensure the MSSQL folder exists
if (-not (Test-Path $remoteFolder)) {
    New-Item -ItemType Directory -Path $remoteFolder | Out-Null
}

# Copy files from C:\SNOMEDCT to the MSSQL folder (overwrite existing files)
Copy-Item -Path $localPath -Destination $remoteFolder -Recurse -Force

# Stage the changes
git add MSSQL

# Commit the changes
git commit -m "Sync C:\SNOMEDCT to MSSQL folder"

# Push the changes to GitHub (adjust branch name if needed)
git push origin master
