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

Edit `daily-notes/templates/daily-note-template.md` to control layout of your daily note.