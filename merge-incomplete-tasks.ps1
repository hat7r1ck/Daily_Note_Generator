param (
    [string]$NotesDir,
    [string]$Today,
    [string]$Template
)

$todayFile = Join-Path $NotesDir "$Today.md"
$cutoffDate = (Get-Date).AddDays(-7)
$incompleteTasks = @()

Get-ChildItem -Path $NotesDir -Filter *.md | Where-Object {
    $_.Name -ne "$Today.md" -and
    ($_.BaseName -as [datetime]) -ge $cutoffDate
} | ForEach-Object {
    $filePath = $_.FullName
    $lines = Get-Content $filePath
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^\s*-\s\[\s\]\s') {
            $incompleteTasks += $line.Trim()
            $newLines += $line -replace '^\s*-\s\[\s\]\s', '- [-->] '
        } else {
            $newLines += $line
        }
    }

    Set-Content -Path $filePath -Value $newLines -Encoding UTF8
}

if (-not (Test-Path $todayFile)) {
    "# Daily Operator Log - $Today" | Out-File $todayFile -Encoding UTF8
    Get-Content $Template | Add-Content $todayFile
}

if ($incompleteTasks.Count -gt 0) {
    $lines = Get-Content $todayFile
    $outLines = @()
    $injected = $false

    foreach ($line in $lines) {
        $outLines += $line
        if (-not $injected -and $line -match '^## Task Review') {
            $outLines += $incompleteTasks
            $injected = $true
        }
    }

    Set-Content -Path $todayFile -Value $outLines -Encoding UTF8
}