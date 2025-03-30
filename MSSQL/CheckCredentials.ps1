# Requires the CredentialManager module
Import-Module CredentialManager

# Retrieve the stored TRUD API key
$cred = Get-StoredCredential -Target "TRUD_API"

if ($cred) {
    # Convert SecureString to plain text
    $plainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
    )
    Write-Host "TRUD API Key:" -ForegroundColor Cyan
    Write-Host $plainText -ForegroundColor Green
} else {
    Write-Host "TRUD_API credential not found." -ForegroundColor Red
}
