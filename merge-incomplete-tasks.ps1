param (
    [string]$NotesDir,
    [string]$Today,
    [string]$Template
)

$todayFile = Join-Path $NotesDir "$Today.md"
$cutoffDate = (Get-Date).AddDays(-7)
$incompleteTasks = @()

# Step 1: Scan past 7 days for incomplete tasks
Get-ChildItem -Path $NotesDir -Filter *.md | Where-Object {
    $fileDate = $null
    try {
        # Attempt to parse the BaseName as a date.
        # This assumes filenames like "YYYY-MM-DD.md"
        # If your $Today variable is "YYYY-MM-DD", this should align.
        $fileDate = [datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null)
    } catch {
        # If BaseName is not a parsable date, $fileDate remains $null.
        # This helps filter out non-date named files.
    }

    $_.Name -ne "$Today.md" -and
    $fileDate -ne $null -and # Ensure a date was successfully parsed
    $fileDate -ge $cutoffDate
} | ForEach-Object {
    $filePath = $_.FullName
    $lines = [System.IO.File]::ReadAllLines($filePath) # Auto-detects encoding
    $newLines = [System.Collections.Generic.List[string]]::new() # Use a generic list for easier Add operations
    $fileModified = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*-\s\[\s\]\s(.*)') { # Capture the task description
            $taskDescription = $Matches[1].Trim() # Get the trimmed task description
            $incompleteTasks.Add("- [ ] $taskDescription") # Add cleaned-up task to the list
            $newLines.Add(($line -replace '^\s*-\s\[\s\]\s', '- [-->] ')) # Mark original as migrated
            $fileModified = $true
        } else {
            $newLines.Add($line)
        }
    }

    if ($fileModified) {
        [System.IO.File]::WriteAllLines($filePath, $newLines.ToArray(), [System.Text.UTF8Encoding]::new($false))
    }
}

# Step 2: Create today's file from template if needed
if (-not (Test-Path $todayFile)) {
    $header = "# Daily Operator Log - $Today`r`n"
    # Read template using ReadAllText and specify UTF-8. This handles BOMs correctly on read.
    $templateContent = [System.IO.File]::ReadAllText($Template, [System.Text.Encoding]::UTF8)
    $fullContent = $header + "`r`n" + $templateContent # Add blank line between header and template content
    [System.IO.File]::WriteAllText($todayFile, $fullContent, [System.Text.UTF8Encoding]::new($false))
}

# Step 3: Inject tasks under '## Task Review'
if ($incompleteTasks.Count -gt 0) {
    # Read today's file content using ReadAllText and specify UTF-8.
    $content = [System.IO.File]::ReadAllText($todayFile, [System.Text.Encoding]::UTF8)
    $pattern = '(?m)^## Task Review\s*' # Matches "## Task Review" and any following whitespace/newlines

    if ($content -match $pattern) {
        # --- START OF MODIFICATION for precise newline control ---

        # 1. Define the literal text of your header.
        $taskReviewHeaderText = "## Task Review"

        # 2. Prepare the block of tasks.
        #    Each task on a new line, and a blank line *after* the entire block of tasks.
        $tasksBlockWithTrailingNewline = ($incompleteTasks -join "`r`n") + "`r`n"

        # 3. Construct the complete replacement string.
        #    This will replace everything matched by $pattern (the header and its original following newlines).
        #    We want: Header Text + Newline_for_Header + ONE_Blank_Line_Separator + Tasks_Block
        $replacementString = $taskReviewHeaderText + "`r`n" + "`r`n" + $tasksBlockWithTrailingNewline
        
        # 4. Perform the replacement using the fully constructed string.
        #    The ', 1' ensures only the first occurrence is replaced.
        $content = [regex]::Replace($content, $pattern, $replacementString, 1)
        
        # --- END OF MODIFICATION ---

        [System.IO.File]::WriteAllText($todayFile, $content, [System.Text.UTF8Encoding]::new($false))
    } else {
        # Optional: Handle cases where "## Task Review" is not found in today's note.
        # For now, it will just skip injection if the header isn't present.
        # You could add logic here to append the section and tasks if desired.
        Write-Warning "Section '## Task Review' not found in '$todayFile'. $($incompleteTasks.Count) tasks were collected but NOT injected."
        # Example to append if not found:
        # $newSectionAndTasks = "`r`n`r`n## Task Review`r`n`r`n" + ($incompleteTasks -join "`r`n") + "`r`n"
        # $content += $newSectionAndTasks
        # [System.IO.File]::WriteAllText($todayFile, $content, [System.Text.UTF8Encoding]::new($false))
        # Write-Host "  Appended '## Task Review' section and tasks to '$todayFile'."
    }
}
