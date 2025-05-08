# merge-incomplete-tasks.ps1
# --- Corrected and Enhanced Version ---

param (
    [Parameter(Mandatory=$true)]
    [string]$NotesDir,  # Directory containing the markdown notes

    [Parameter(Mandatory=$true)]
    [string]$Today,     # Date for today's note in "yyyy-MM-dd" format

    [Parameter(Mandatory=$true)]
    [string]$Template   # Full path to the template file
)

# --- Setup ---
$ErrorActionPreference = "Stop" # Exit on critical errors

# Define UTF-8 encoding without BOM for all file writing
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# Prepare date objects for comparison
$todayDateObj = [datetime]::ParseExact($Today, "yyyy-MM-dd", $null)
$cutoffDate = $todayDateObj.AddDays(-7) # Look back 7 days from the $Today date

$todayFile = Join-Path $NotesDir "$Today.md"
$incompleteTasks = [System.Collections.Generic.List[string]]::new()

# --- Step 1: Scan past notes for incomplete tasks ---
Write-Host "Scanning notes in '$NotesDir' for incomplete tasks from the last 7 days (excluding '$Today')..."
Get-ChildItem -Path $NotesDir -Filter *.md -File | ForEach-Object {
    # Try to parse date from filename (BaseName, e.g., "2023-10-26")
    $fileDate = $null
    try {
        $fileDate = [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
    } catch {
        # Silently skip files with non-date names, or add: Write-Warning "Non-date filename: $($_.Name)"
        return # Skip to the next file
    }

    # Filter for relevant files:
    # - Not today's note by name
    # - Date successfully parsed
    # - Date is on or after the cutoff date
    # - Date is before $Today's date
    if ($_.Name -eq "$Today.md" -or $fileDate -eq $null -or $fileDate -lt $cutoffDate -or $fileDate -ge $todayDateObj) {
        return # Skip this file
    }

    $filePath = $_.FullName
    Write-Host "Processing past note: $filePath"
    
    $lines = [System.IO.File]::ReadAllLines($filePath) # Auto-detects encoding for reading
    $newLines = [System.Collections.Generic.List[string]]::new()
    $fileModified = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*-\s\[\s\]\s(.*)') { # Matches: optional leading space, then "- [ ] Task description"
            $taskDescription = $Matches[1].Trim() # Extract and trim the task description part
            $incompleteTasks.Add("- [ ] $taskDescription") # Add to list for today's note, formatted cleanly
            
            $newLines.Add(($line -replace '^\s*-\s\[\s\]\s', '- [-->] ')) # Mark original line as migrated
            $fileModified = $true
        } else {
            $newLines.Add($line)
        }
    }

    if ($fileModified) {
        Write-Host "  Marked tasks as migrated in '$filePath'."
        [System.IO.File]::WriteAllLines($filePath, $newLines.ToArray(), $utf8NoBom)
    }
}

# --- Step 2: Create today's note from template if it doesn't exist ---
Write-Host "Checking for today's note: '$todayFile'..."
if (-not (Test-Path $todayFile)) {
    Write-Host "  Today's note not found. Creating from template: '$Template'..."
    $header = "# Daily Operator Log - $Today`r`n" # Use Windows-style newlines `\r\n`
    
    # Read template content as UTF-8; System.Text.Encoding.UTF8 handles BOMs correctly on read.
    $templateContent = [System.IO.File]::ReadAllText($Template, [System.Text.Encoding]::UTF8)
    
    $fullContent = $header + "`r`n" + $templateContent # Ensure a blank line between custom header and template content
    
    [System.IO.File]::WriteAllText($todayFile, $fullContent, $utf8NoBom)
    Write-Host "  Created '$todayFile'."
} else {
    Write-Host "  Today's note '$todayFile' already exists."
}

# --- Step 3: Inject collected incomplete tasks into today's note ---
if ($incompleteTasks.Count -gt 0) {
    Write-Host "Injecting $($incompleteTasks.Count) incomplete task(s) into '$todayFile'..."
    
    # Read today's note content as UTF-8.
    $currentTodayContent = [System.IO.File]::ReadAllText($todayFile, [System.Text.Encoding]::UTF8)
    
    $taskReviewPattern = '(?m)^## Task Review\s*' # (?m) for multiline, ^ for start of line, \s* for any trailing space/newline on the header line
    
    if ($currentTodayContent -match $taskReviewPattern) {
        # Prepare the block of tasks to inject:
        # - Prepend `\r\n` to ensure tasks start on a new line after the "## Task Review" header.
        # - Join multiple tasks with `\r\n`.
        # - Append `\r`n` to ensure a blank line after the injected tasks block.
        $tasksToInjectAsString = "`r`n" + ($incompleteTasks -join "`r`n") + "`r`n"
        
        # Replacement logic: takes the matched header ($m.Value, which includes "## Task Review" and its trailing \s*)
        # and appends the formatted task block string after it.
        # The ', 1' ensures only the first occurrence of "## Task Review" is modified.
        $updatedTodayContent = [regex]::Replace($currentTodayContent, $taskReviewPattern, { param($m) $m.Value + $tasksToInjectAsString }, 1)
        
        [System.IO.File]::WriteAllText($todayFile, $updatedTodayContent, $utf8NoBom)
        Write-Host "  Successfully injected tasks under '## Task Review' in '$todayFile'."
    } else {
        Write-Warning "Section '## Task Review' not found in '$todayFile'. $($incompleteTasks.Count) tasks were collected but NOT injected."
        # To append tasks if the section is missing, you could uncomment and adapt this:
        # Write-Host "  '## Task Review' section not found. Appending new section with tasks."
        # $tasksBlockToAppend = "`r`n`r`n## Task Review`r`n" + ($incompleteTasks -join "`r`n") + "`r`n"
        # $currentTodayContent += $tasksBlockToAppend
        # [System.IO.File]::WriteAllText($todayFile, $currentTodayContent, $utf8NoBom)
        # Write-Host "  Appended '## Task Review' section and tasks to '$todayFile'."
    }
} else {
    Write-Host "No incomplete tasks found in past notes to migrate."
}

Write-Host "Daily note processing complete for $Today."
