param (
    [Parameter(Mandatory=$true)]
    [string]$NotesDir, # Should be the root, e.g., "daily-notes"

    [Parameter(Mandatory=$true)]
    [string]$Today, # Expected to be like "2024-01-03" or "2024-1-3"

    [Parameter(Mandatory=$true)]
    [string]$Template
)

# --- Date and Path Setup ---
$todayDateObj = $null
try {
    $todayParts = $Today.Split('-')
    if ($todayParts.Count -eq 3 -and ($todayParts[0] -match '^\d{4}$') -and ($todayParts[1] -match '^\d{1,2}$') -and ($todayParts[2] -match '^\d{1,2}$')) {
        $normalizedTodayString = "{0:D4}-{1:D2}-{2:D2}" -f [int]$todayParts[0], [int]$todayParts[1], [int]$todayParts[2]
        $todayDateObj = [datetime]::ParseExact($normalizedTodayString, "yyyy-MM-dd", $null)
    } else {
        throw "Invalid format for -Today parameter: '$Today'. Expected yyyy-M-d format."
    }
} catch {
    Write-Error "Error parsing -Today parameter '$Today': $($_.Exception.Message)"
    exit 1 # Exit if $Today cannot be parsed
}

$yearForPath = $todayDateObj.ToString("yyyy")
$monthForPath = $todayDateObj.ToString("MM")
$todayFileName = $todayDateObj.ToString("yyyy-MM-dd") # Filename itself

# Construct the full path for today's note including YYYY/MM subdirectories
$todayNoteDirPath = Join-Path $NotesDir $yearForPath $monthForPath
$todayFile = Join-Path $todayNoteDirPath "$todayFileName.md"

$cutoffDate = $todayDateObj.AddDays(-7)
$incompleteTasks = [System.Collections.Generic.List[string]]::new()

# --- Step 1: Scan past 7 days for incomplete tasks (RECURSIVELY) ---
Write-Host "Scanning notes under '$NotesDir' (recursive). Cutoff date: $($cutoffDate.ToString('yyyy-MM-dd'))"
# Added -Recurse to search subdirectories
Get-ChildItem -Path $NotesDir -Filter *.md -Recurse -File | ForEach-Object {
    $fileDate = $null
    try {
        # $file.BaseName is just the filename without extension, e.g., "2023-12-27"
        # This should work fine even if the file is in a subdirectory.
        $baseNameParts = $_.BaseName.Split('-')
        if ($baseNameParts.Count -eq 3 -and ($baseNameParts[0] -match '^\d{4}$') -and ($baseNameParts[1] -match '^\d{1,2}$') -and ($baseNameParts[2] -match '^\d{1,2}$')) {
            $normalizedFileDateString = "{0:D4}-{1:D2}-{2:D2}" -f [int]$baseNameParts[0], [int]$baseNameParts[1], [int]$baseNameParts[2]
            $fileDate = [datetime]::ParseExact($normalizedFileDateString, "yyyy-MM-dd", $null)
        }
    } catch {
        # Silently ignore files with non-date names or add: Write-Warning "Could not parse date from filename: $($_.FullName)"
    }

    # Filter conditions
    # Compare full path of current file with the expected full path of today's file
    if ($_.FullName -ne $todayFile -and       # Exclude the file for the specified $Today
        $fileDate -ne $null -and            # Ensure a date was successfully parsed from filename
        $fileDate -ge $cutoffDate -and      # File date is on or after the cutoff
        $fileDate -lt $todayDateObj) {      # File date is *before* the specified $Today

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
            } else {
                $newLines.Add($line)
            }
        }

        if ($fileModified) {
            [System.IO.File]::WriteAllLines($filePath, $newLines.ToArray(), [System.Text.UTF8Encoding]::new($false))
        }
    }
}

# --- Step 2: Create today's file from template if needed ---
if (-not (Test-Path $todayFile)) {
    # Ensure the YYYY/MM directory structure exists for today's note
    if (-not (Test-Path $todayNoteDirPath)) {
        Write-Host "Creating directory: $todayNoteDirPath"
        New-Item -ItemType Directory -Path $todayNoteDirPath -Force | Out-Null
    }

    $header = "# Daily Operator Log - $($todayDateObj.ToString('yyyy-MM-dd'))`r`n"
    $templateContent = [System.IO.File]::ReadAllText($Template, [System.Text.Encoding]::UTF8)
    $fullContent = $header + "`r`n" + $templateContent
    [System.IO.File]::WriteAllText($todayFile, $fullContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Created today's note: $todayFile"
} else {
    Write-Host "Today's note already exists: $todayFile"
}

# --- Step 3: Inject tasks under '## Task Review' ---
if ($incompleteTasks.Count -gt 0) {
    # Ensure today's file actually exists before trying to read/write (it should if created in Step 2)
    if (Test-Path $todayFile) {
        $content = [System.IO.File]::ReadAllText($todayFile, [System.Text.Encoding]::UTF8)
        $pattern = '(?m)^## Task Review\s*'

        if ($content -match $pattern) {
            $taskReviewHeaderText = "## Task Review"
            $tasksBlockWithTrailingNewline = ($incompleteTasks -join "`r`n") + "`r`n"
            $replacementString = $taskReviewHeaderText + "`r`n" + "`r`n" + $tasksBlockWithTrailingNewline
            $content = [regex]::Replace($content, $pattern, $replacementString, 1)
            [System.IO.File]::WriteAllText($todayFile, $content, [System.Text.UTF8Encoding]::new($false))
            Write-Host "Injected $($incompleteTasks.Count) tasks into $todayFile"
        } else {
            Write-Warning "Section '## Task Review' not found in '$todayFile'. $($incompleteTasks.Count) tasks were collected but NOT injected."
        }
    } else {
        Write-Warning "Today's note '$todayFile' was expected but not found for task injection. This shouldn't happen."
    }
}

Write-Host "Processing complete for $($todayDateObj.ToString('yyyy-MM-dd'))"
