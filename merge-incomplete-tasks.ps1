param (
    [string]$NotesDir,
    [string]$Today,
    [string]$Template
)

$todayFile = Join-Path $NotesDir "$Today.md"
$cutoffDate = (Get-Date).AddDays(-7)
$incompleteTasks = @()

# --- Step 1: Collect incomplete tasks from past 7 days ---
Get-ChildItem -Path $NotesDir -Filter *.md | Where-Object {
    $_.Name -ne "$Today.md" -and
    ($_.BaseName -as [datetime]) -ge $cutoffDate
} | ForEach-Object {
    $filePath = $_.FullName
    $originalLines = [System.IO.File]::ReadAllLines($filePath)
    $updatedLines = @()

    foreach ($line in $originalLines) {
        if ($line -match '^\s*-\s\[\s\]\s') {
            $incompleteTasks += $line.Trim()
            $updatedLines += $line -replace '^\s*-\s\[\s\]\s', '- [-->] '
        } else {
            $updatedLines += $line
        }
    }

    [System.IO.File]::WriteAllLines($filePath, $updatedLines, [System.Text.UTF8Encoding]::new($false))
}

# --- Step 2: Build today's file if missing ---
if (-not (Test-Path $todayFile)) {
    $header = "# Daily Operator Log - $Today"
    $template = [System.IO.File]::ReadAllLines($Template)
    $initLines = @($header) + $template
    [System.IO.File]::WriteAllLines($todayFile, $initLines, [System.Text.UTF8Encoding]::new($false))
}

# --- Step 3: Inject migrated tasks under '## Task Review' ---
if ($incompleteTasks.Count -gt 0) {
    $todayLines = [System.IO.File]::ReadAllLines($todayFile)
    $finalLines = @()
    $injected = $false

    foreach ($line in $todayLines) {
        $finalLines += $line
        if (-not $injected -and $line -match '^## Task Review') {
            $finalLines += $incompleteTasks
            $injected = $true
        }
    }

    [System.IO.File]::WriteAllLines($todayFile, $finalLines, [System.Text.UTF8Encoding]::new($false))
}
