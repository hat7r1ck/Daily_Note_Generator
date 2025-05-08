# Daily Note Generator

Creates a daily markdown log from a template, and migrates incomplete tasks from the last 7 days into the new note’s "Task Review" section.

## How It Works

- Notes are saved in `daily-notes/YYYY/MM/YYYY-MM-DD.md`.
- The batch script (e.g., `LaunchDailyNotes.bat`) runs the PowerShell script (e.g., `Run-DailyNotes.ps1`).
- The PowerShell script itself automatically determines the current date and necessary file paths (assuming a `daily-notes` subfolder relative to its location).
- The PowerShell script creates today’s note from the template if it doesn’t exist, including `YYYY/MM` subdirectories.
- Incomplete tasks (`- [ ]`) from the past 7 days are:
  - Moved to today’s note under `## Task Review`
  - Replaced with `- [-->]` in original files

## Usage

1.  **Setup:**
    *   Place the PowerShell script (e.g., `Run-DailyNotes.ps1`) AND the batch file (e.g., `LaunchDailyNotes.bat`) in your main project folder.
    *   Ensure a `daily-notes` subfolder exists next to these scripts, containing a `templates/daily-note-template.md` file.
    *   Existing notes should be in the `daily-notes/YYYY/MM/YYYY-MM-DD.md` structure.

2.  Double-click the batch file (e.g., `LaunchDailyNotes.bat`).
3.  Today’s note will be generated and populated. The PowerShell window will stay open until you press a key.

## Customize

You can customize the layout and content of your daily notes by editing the template file: `daily-notes/templates/daily-note-template.md`.

**Important for Task Migration:**
*   The script identifies where to place migrated tasks by looking for a specific heading: `## Task Review`.
*   You can **move this `## Task Review` section anywhere within your template file** to suit your preferred layout. The script will find it as long as the heading exists.
*   However, for the automated task migration to work, the heading **must remain exactly `## Task Review`** (i.e., an H2 heading with that precise text). If you rename this heading or change its level (e.g., to `### My Tasks`), the script will not be able to find it, and migrated tasks will not be injected into that section.
