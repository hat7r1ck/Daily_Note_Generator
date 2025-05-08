# File: Run-DailyNotes.ps1

# Script Setup
$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# Determine Paths and Today's Date
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$NotesDir = Join-Path -Path $scriptRoot -ChildPath "daily-notes"
$Template = Join-Path -Path $scriptRoot -ChildPath "daily-notes\templates\daily-note-template.md"
$todayDateObj = Get-Date
$Today = $todayDateObj.ToString("yyyy-MM-dd")

# Initial Path Validations
if (-not (Test-Path $NotesDir -PathType Container)) {
    Write-Error "FATAL: Notes directory '$NotesDir' not found. Expected a 'daily-notes' subfolder in the same directory as this script."
    Write-Host "Press any key to exit..."
    [System.Console]::ReadKey($true) | Out-Null
    exit 1
}
if (-not (Test-Path $Template -PathType Leaf)) {
    Write-Error "FATAL: Template file '$Template' not found. Expected it inside '$($NotesDir)\templates\daily-note-template.md'."
    Write-Host "Press any key to exit..."
    [System.Console]::ReadKey($true) | Out-Null
    exit 1
}

# Main Script Logic
Write-Host "Daily Note Automation Started for: $Today"
Write-Host "Notes Directory: $NotesDir"
Write-Host "Template File: $Template"

$yearForPath = $todayDateObj.ToString("yyyy")
$monthForPath = $todayDateObj.ToString("MM")
$todayFileName = $todayDateObj.ToString("yyyy-MM-dd")
$todayNoteDirPath = Join-Path $NotesDir $yearForPath $monthForPath
$todayFile = Join-Path $todayNoteDirPath "$todayFileName.md"
$cutoffDate = $todayDateObj.AddDays(-7)
$incompleteTasks = [System.Collections.Generic.List[string]]::new()

# Step 1: Scan past notes
Write-Host "Scanning notes under '$NotesDir' (recursive). Cutoff date: $($cutoffDate.ToString('yyyy-MM-dd'))"
Get-ChildItem -Path $NotesDir -Filter *.md -Recurse -File | ForEach-Object {
    $fileDate = $null
    try {
        $baseNameParts = $_.BaseName.Split('-')
        if ($baseNameParts.Count -eq 3 -and ($baseNameParts[0] -match '^\d{4}$') -and ($baseNameParts[1] -match '^\d{1,2}$') -and ($baseNameParts[2] -match '^\d{1,2}$')) {
            $normalizedFileDateString = "{0:D4}-{1:D2}-{2:D2}" -f [int]$baseNameParts[0], [int]$baseNameParts[1], [int]$baseNameParts[2]
            $fileDate = [datetime]::ParseExact($normalizedFileDateString, "yyyy-MM-dd", $null)
        }
    } catch {}

    if ($_.FullName -ne $todayFile -and $fileDate -ne $null -and $fileDate -ge $cutoffDate -and $fileDate -lt $todayDateObj) {
        $filePath = $_.FullName
        $lines = [System.IO.File]::ReadAllLines($filePath)
        $newLines = [System.Collections.Generic.List[string]]::new()
        $fileModified = $false
        foreach ($line in $lines) {
            if ($line -match '^\s*-\s\[\s\]\s(.*)') {
                $taskDescription = $Matches[1].Trim()
                $incompleteTasks.Add("- [ ] $taskDescription")
                $newLines.Add(($line -replace '^\s*-\s\[\s\]\s', '- [-->] '))
                $fileModified = $true
            } else { $newLines.Add($line) }
        }
        if ($fileModified) { [System.IO.File]::WriteAllLines($filePath, $newLines.ToArray(), $utf8NoBom) }
    }
}

# Step 2: Create today's file
if (-not (Test-Path $todayFile)) {
    if (-not (Test-Path $todayNoteDirPath)) {
        Write-Host "Creating directory: $todayNoteDirPath"
        New-Item -ItemType Directory -Path $todayNoteDirPath -Force | Out-Null
    }
    $header = "# Daily Operator Log - $($todayDateObj.ToString('yyyy-MM-dd'))`r`n"
    $templateContent = [System.IO.File]::ReadAllText($Template, [System.Text.Encoding]::UTF8)
    $fullContent = $header + "`r`n" + $templateContent
    [System.IO.File]::WriteAllText($todayFile, $fullContent, $utf8NoBom)
    Write-Host "Created today's note: $todayFile"
} else { Write-Host "Today's note already exists: $todayFile" }

# Step 3: Inject tasks
if ($incompleteTasks.Count -gt 0) {
    if (Test-Path $todayFile) {
        $content = [System.IO.File]::ReadAllText($todayFile, [System.Text.Encoding]::UTF8)
        $pattern = '(?m)^## Task Review\s*'
        if ($content -match $pattern) {
            $taskReviewHeaderText = "## Task Review"
            $tasksBlockWithTrailingNewline = ($incompleteTasks -join "`r`n") + "`r`n"
            $replacementString = $taskReviewHeaderText + "`r`n" + "`r`n" + $tasksBlockWithTrailingNewline
            $content = [regex]::Replace($content, $pattern, $replacementString, 1)
            [System.IO.File]::WriteAllText($todayFile, $content, $utf8NoBom)
            Write-Host "Injected $($incompleteTasks.Count) tasks into $todayFile"
        } else { Write-Warning "Section '## Task Review' not found in '$todayFile'. Tasks NOT injected." }
    } else { Write-Warning "Today's note '$todayFile' not found for task injection." }
}

Write-Host "Processing complete for $($todayDateObj.ToString('yyyy-MM-dd'))"
Write-Host "Press any key to exit..."
[System.Console]::ReadKey($true) | Out-Null
