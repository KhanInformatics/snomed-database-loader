# Define paths
$localPath = "C:\SNOMEDCT\*"
# Path to your local clone of the repo. Change this if your clone is located elsewhere.
$repoPath = "C:\Users\mik78\snomed-database-loader"
$remoteFolder = Join-Path $repoPath "MSSQL"

# Change directory to the repo folder
Set-Location $repoPath

# Ensure the MSSQL folder exists
if (-not (Test-Path $remoteFolder)) {
    New-Item -ItemType Directory -Path $remoteFolder | Out-Null
}

# Copy files from C:\SNOMEDCT to the MSSQL folder (overwrite existing files)
try {
    Copy-Item -Path $localPath -Destination $remoteFolder -Recurse -Force -ErrorAction Stop
    Write-Output "Files copied successfully."
} catch {
    Write-Error "Error copying files: $_"
    exit 1
}

# Stage the changes
try {
    git add MSSQL
    Write-Output "Files staged successfully."
} catch {
    Write-Error "Error staging files: $_"
    exit 1
}

# Commit the changes
try {
    $commitMessage = "Sync C:\SNOMEDCT to MSSQL folder"
    git commit -m $commitMessage
    Write-Output "Commit completed successfully."
} catch {
    Write-Error "Error during commit: $_"
    exit 1
}

# Push the changes with graceful error handling
try {
    $pushOutput = git push origin master 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "Push successful."
        Write-Output $pushOutput
    } else {
        Write-Error "Push failed with exit code $LASTEXITCODE. Details: $pushOutput"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "An unexpected error occurred during push: $_"
    exit 1
}
