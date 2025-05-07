param (
    [string]$NotesDir,
    [string]$Today,
    [string]$Template
)

$todayFile = Join-Path $NotesDir "$Today.md"
$cutoffDate = (Get-Date).AddDays(-7)
$incompleteTasks = @()

# --- Step 1: Scan past 7 days and migrate incomplete tasks ---
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

    [System.IO.File]::WriteAllLines($filePath, $newLines, [System.Text.UTF8Encoding]::new($false))
}

# --- Step 2: Create today's note if it doesn't exist ---
if (-not (Test-Path $todayFile)) {
    $initLines = @("# Daily Operator Log - $Today")
    $initLines += Get-Content $Template
    [System.IO.File]::WriteAllLines($todayFile, $initLines, [System.Text.UTF8Encoding]::new($false))
}

# --- Step 3: Inject migrated tasks into ## Task Review ---
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

    [System.IO.File]::WriteAllLines($todayFile, $outLines, [System.Text.UTF8Encoding]::new($false))
}
