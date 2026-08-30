[CmdletBinding()]
param(
    [string]$Endpoint = 'http://127.0.0.1:18080',
    [ValidateRange(1, 60)][int]$TimeoutSeconds = 5
)

$ErrorActionPreference = 'Stop'
$base = $Endpoint.TrimEnd('/')
$health = Invoke-RestMethod -Method Get -Uri "$base/health" -TimeoutSec $TimeoutSeconds
$models = Invoke-RestMethod -Method Get -Uri "$base/v1/models" -TimeoutSec $TimeoutSeconds

[pscustomobject]@{
    status = $health.status
    endpoint = $base
    served_models = @($models.data | ForEach-Object { $_.id })
} | ConvertTo-Json -Depth 4

