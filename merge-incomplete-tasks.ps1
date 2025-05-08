# merge-incomplete-tasks.ps1

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
    $fileDate = $null
    try {
        $fileDate = [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
    } catch {
        return # Skip files with non-date names
    }

    if ($_.Name -eq "$Today.md" -or $fileDate -eq $null -or $fileDate -lt $cutoffDate -or $fileDate -ge $todayDateObj) {
        return # Skip this file
    }

    $filePath = $_.FullName
    # Write-Host "Processing past note: $filePath" # Uncomment for verbose logging
    
    $lines = [System.IO.File]::ReadAllLines($filePath)
    $newLines = [System.Collections.Generic.List[string]]::new()
    $fileModified = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*-\s\[\s\]\s(.*)') {
            $taskDescription = $Matches[1].Trim()
            $incompleteTasks.Add("- [ ] $taskDescription") # Add clean task
            
            $newLines.Add(($line -replace '^\s*-\s\[\s\]\s', '- [-->] '))
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
    $header = "# Daily Operator Log - $Today`r`n" 
    
    $templateContent = [System.IO.File]::ReadAllText($Template, [System.Text.Encoding]::UTF8) # Read template as UTF-8
    $fullContent = $header + "`r`n" + $templateContent
    
    [System.IO.File]::WriteAllText($todayFile, $fullContent, $utf8NoBom)
    Write-Host "  Created '$todayFile'."
} else {
    Write-Host "  Today's note '$todayFile' already exists."
}

# --- Step 3: Inject collected incomplete tasks into today's note ---
if ($incompleteTasks.Count -gt 0) {
    Write-Host "Injecting $($incompleteTasks.Count) incomplete task(s) into '$todayFile'..."
    
    $todayLines = [System.IO.File]::ReadAllLines($todayFile) # Read today's file line-by-line
    $newTodayLines = [System.Collections.Generic.List[string]]::new()
    
    $inTaskReviewSection = $false
    $tasksInjected = $false
    $taskReviewHeaderFound = $false

    for ($i = 0; $i -lt $todayLines.Count; $i++) {
        $currentLine = $todayLines[$i]

        # Check if we are about to leave the Task Review section
        # This happens if we were in the section AND the current line is a new H2 (##) or H1 (#) heading
        # AND it's not the "## Task Review" header itself (in case of re-processing or malformed files).
        if ($inTaskReviewSection -and ($currentLine -match '^\s*#{1,2}\s+') -and ($currentLine -notmatch '^\s*## Task Review')) {
            # We've hit the next section. Inject tasks *before* this current line.
            if (-not $tasksInjected) {
                # Add a blank line before tasks if the last line added wasn't already blank.
                if ($newTodayLines.Count -gt 0 -and $newTodayLines[-1].Trim().Length -gt 0) {
                    $newTodayLines.Add("") 
                }
                $incompleteTasks.ForEach({ $newTodayLines.Add($_) })
                # Add a blank line after tasks, before the new section starts.
                if ($currentLine.Trim().Length -gt 0) { # Only if next line isn't blank
                    $newTodayLines.Add("")
                }
                $tasksInjected = $true
            }
            $inTaskReviewSection = $false # We've now exited the Task Review section
        }

        $newTodayLines.Add($currentLine) # Add the current line from today's note to our output

        # Check if we are entering/in the Task Review section
        if ($currentLine -match '^\s*## Task Review') {
            $inTaskReviewSection = $true
            $taskReviewHeaderFound = $true
        }
    }

    # If tasks haven't been injected yet, it means Task Review was the last section (or only section).
    if ($inTaskReviewSection -and -not $tasksInjected) {
        if ($newTodayLines.Count -gt 0 -and $newTodayLines[-1].Trim().Length -gt 0) {
            $newTodayLines.Add("") # Add a blank line
        }
        $incompleteTasks.ForEach({ $newTodayLines.Add($_) })
        $newTodayLines.Add("") # Add a blank line after tasks at the end of the file
        $tasksInjected = $true
    }

    if ($tasksInjected) {
        [System.IO.File]::WriteAllLines($todayFile, $newTodayLines.ToArray(), $utf8NoBom)
        Write-Host "  Successfully injected tasks at the end of '## Task Review' section in '$todayFile'."
    } elseif (-not $taskReviewHeaderFound -and $incompleteTasks.Count -gt 0) {
        # '## Task Review' section was NOT found at all. Append it.
        Write-Warning "'## Task Review' section NOT found in '$todayFile'."
        Write-Host "  Appending '## Task Review' section and tasks to the end of '$todayFile'."
        if ($newTodayLines.Count -gt 0 -and $newTodayLines[-1].Trim().Length -gt 0) {
            $newTodayLines.Add("") # Blank line before new section
        }
        $newTodayLines.Add("## Task Review")
        $newTodayLines.Add("") # Blank line after header
        $incompleteTasks.ForEach({ $newTodayLines.Add($_) })
        $newTodayLines.Add("") # Blank line after tasks
        [System.IO.File]::WriteAllLines($todayFile, $newTodayLines.ToArray(), $utf8NoBom)
        Write-Host "  Appended '## Task Review' and tasks."
    } elseif ($taskReviewHeaderFound -and -not $tasksInjected -and $incompleteTasks.Count -gt 0) {
        # This case should ideally not be hit if logic is correct, but good for diagnostics.
        Write-Warning "  '## Task Review' section was found, but tasks were not injected. This might indicate an unusual file structure or an edge case."
    }

} else {
    Write-Host "No incomplete tasks found in past notes to migrate."
}

Write-Host "Daily note processing complete for $Today."
