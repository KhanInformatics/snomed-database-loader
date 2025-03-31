# Helper function to run Git commands
function Run-GitCommand {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$Args
    )
    # Execute the Git command and capture output and exit code
    $output = git @Args 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Error "Git command 'git $Args' failed with exit code $exitCode. Output: $output"
        exit $exitCode
    } else {
        # Check if the output contains any warnings and display them
        if ($output -match "warning") {
            Write-Output "Git command 'git $Args' executed with warnings:"
            Write-Output $output
        } else {
            Write-Output "Git command 'git $Args' executed successfully."
        }
    }
    return $output
}

# Define paths
$localPath = "C:\SNOMEDCT\*"
# Adjust this path to where your local clone is located
$repoPath = "C:\Users\mik78\snomed-database-loader"
$remoteFolder = Join-Path $repoPath "MSSQL"

# Change directory to the repository
Set-Location $repoPath

# Ensure the MSSQL folder exists
if (-not (Test-Path $remoteFolder)) {
    New-Item -ItemType Directory -Path $remoteFolder | Out-Null
    Write-Output "Created folder MSSQL."
}

# Copy files from C:\SNOMEDCT to the MSSQL folder (overwriting if necessary)
try {
    Copy-Item -Path $localPath -Destination $remoteFolder -Recurse -Force -ErrorAction Stop
    Write-Output "Files copied successfully."
} catch {
    Write-Error "Error copying files: $_"
    exit 1
}

# Stage the changes
Run-GitCommand -Args @("add", "MSSQL")

# Commit the changes
$commitMessage = "Sync C:\SNOMEDCT to MSSQL folder"
Run-GitCommand -Args @("commit", "-m", $commitMessage)

# Push the changes to GitHub
Run-GitCommand -Args @("push", "origin", "master")
