# Daily Note Generator

Creates a daily markdown log from a template, and migrates incomplete tasks from the last 7 days into the new note’s "Task Review" section.

## How It Works

- Notes are saved in `daily-notes/YYYY/MM/YYYY-MM-DD.md`
- The batch script creates today’s note if it doesn’t exist
- Incomplete tasks (`- [ ]`) from the past 7 days are:
  - Moved to today’s note under `## Task Review`
  - Replaced with `- [-->]` in original files

## Usage

1. Clone or download this repo
2. Double-click `generate-daily-note.bat`
3. Today’s note will be generated and populated

## Customize

You can customize the layout and content of your daily notes by editing the template file: `daily-notes/templates/daily-note-template.md`.

**Important for Task Migration:**
*   The script identifies where to place migrated tasks by looking for a specific heading: `## Task Review`.
*   You can **move this `## Task Review` section anywhere within your template file** to suit your preferred layout. The script will find it as long as the heading exists.
*   However, for the automated task migration to work, the heading **must remain exactly `## Task Review`** (i.e., an H2 heading with that precise text). If you rename this heading or change its level (e.g., to `### My Tasks`), the script will not be able to find it, and migrated tasks will not be injected into that section.
