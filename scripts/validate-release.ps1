[CmdletBinding()]
param([string[]]$ForbiddenLiteral = @())

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = [Collections.Generic.List[string]]::new()
function Add-Failure([string]$Message) { $script:failures.Add($Message) }

$required = @(
    'README.md', 'README.ko.md', 'LICENSE', 'SECURITY.md', '.gitignore', 'AGENTS.md',
    'configs\ik-llama-baseline-128k.example.sh',
    'configs\ik-llama-mtp-128k.experimental.sh',
    'configs\wslconfig.example',
    'benchmarks\runtime-comparison.csv',
    'docs\reproducibility.md', 'docs\methodology.md', 'docs\limitations.md',
    'docs\upstream-licenses.md', 'docs\publishing.md',
    'scripts\healthcheck.example.ps1', 'social\x-card.png'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        Add-Failure "missing:$relative"
    }
}

foreach ($ps1 in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1') {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($ps1.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count) { Add-Failure "invalid-powershell:$($ps1.FullName.Substring($root.Length + 1))" }
}

$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -ne $PSCommandPath
})
$textExtensions = @('.md', '.csv', '.sh', '.ps1', '.example')
$textNames = @('.gitignore', 'LICENSE')
$textFiles = @($files | Where-Object {
    $_.Extension -in $textExtensions -or $_.Name -in $textNames
})
$binaryFiles = @($files | Where-Object { $_ -notin $textFiles })
foreach ($file in $binaryFiles) {
    $relative = $file.FullName.Substring($root.Length + 1)
    if ($relative -ne 'social\x-card.png') {
        Add-Failure "unexpected-binary:$relative"
        continue
    }
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    $pngSignature = '137,80,78,71,13,10,26,10'
    if ($bytes.Length -lt 8 -or ($bytes[0..7] -join ',') -ne $pngSignature) {
        Add-Failure "invalid-png:$relative"
    }
}
$patterns = [ordered]@{
    windows_user_home = '(?i)[A-Z]:\\Users\\[^<\\\s]+'
    private_drive_path = '(?i)\b[DE]:\\(?:AI|Data|Workspace|LocalBackup)\\'
    unix_home = '(?i)(?:^|[\s"''])/home/[^/<\s]+'
    hf_token = '\bhf_[A-Za-z0-9]{12,}'
    openai_key = '\bsk-[A-Za-z0-9_-]{12,}'
    uuid = '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b'
}
foreach ($file in $textFiles) {
    $text = Get-Content -Raw -LiteralPath $file.FullName -Encoding utf8
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($text -match $entry.Value) {
            Add-Failure "sensitive-pattern:$($entry.Key):$($file.FullName.Substring($root.Length + 1))"
        }
    }
    foreach ($literal in $ForbiddenLiteral) {
        if ($literal -and $text.Contains($literal, [StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "forbidden-literal:$($file.FullName.Substring($root.Length + 1))"
        }
    }
}

$binaryPatterns = [ordered]@{
    windows_user_home = '(?i)[A-Z]:\\Users\\[^<\\\s]+'
    private_drive_path = '(?i)\b[DE]:\\(?:AI|Data|Workspace|LocalBackup)\\'
    unix_home = '(?i)/home/[^/<\s]+'
    hf_token = '\bhf_[A-Za-z0-9]{12,}'
    openai_key = '\bsk-[A-Za-z0-9_-]{12,}'
    github_token = '\bgh[pousr]_[A-Za-z0-9]{20,}'
}
foreach ($file in $binaryFiles) {
    $relative = $file.FullName.Substring($root.Length + 1)
    $ascii = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($file.FullName))
    foreach ($entry in $binaryPatterns.GetEnumerator()) {
        if ($ascii -match $entry.Value) {
            Add-Failure "sensitive-binary-pattern:$($entry.Key):$relative"
        }
    }
}

$weights = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -match '(?i)^\.(gguf|safetensors|bin|pt|pth|onnx|engine)$' })
if ($weights.Count) { Add-Failure 'model-weight-file-present' }

if ($failures.Count) {
    $failures | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    exit 1
}

[pscustomobject]@{
    status = 'PASS'
    scanned_files = $files.Count
    powershell_files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1').Count
    model_weight_files = 0
} | ConvertTo-Json
