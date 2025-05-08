# File: Run-DailyNotes.ps1

# --- Script Setup ---
$ErrorActionPreference = "Stop"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# --- Determine Paths and Today's Date ---
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$NotesDir = Join-Path -Path $scriptRoot -ChildPath "daily-notes"
$Template = Join-Path -Path $scriptRoot -ChildPath "daily-notes\templates\daily-note-template.md"
$todayDateObj = Get-Date
$Today = $todayDateObj.ToString("yyyy-MM-dd")

# --- Initial Path Validations ---
if (-not (Test-Path $NotesDir -PathType Container)) {
    Write-Error "FATAL: Notes directory '$NotesDir' not found. Expected 'daily-notes' subfolder."
    Write-Host "Press any key to exit...";[System.Console]::ReadKey($true)|Out-Null;exit 1
}
if (-not (Test-Path $Template -PathType Leaf)) {
    Write-Error "FATAL: Template file '$Template' not found. Expected in '$($NotesDir)\templates\'."
    Write-Host "Press any key to exit...";[System.Console]::ReadKey($true)|Out-Null;exit 1
}

# --- Main Script Logic ---
Write-Host "Daily Note Automation Started for: $Today"
#Write-Host "Notes Directory: $NotesDir" # Optional: Uncomment for debugging
#Write-Host "Template File: $Template" # Optional: Uncomment for debugging

$yearForPath = $todayDateObj.ToString("yyyy")
$monthForPath = $todayDateObj.ToString("MM")
$todayFileName = $todayDateObj.ToString("yyyy-MM-dd")

# --- MODIFIED PATH CONSTRUCTION ---
$CleanedNotesDir = $NotesDir.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
$todayNoteDirPath = "$CleanedNotesDir$([System.IO.Path]::DirectorySeparatorChar)$yearForPath$([System.IO.Path]::DirectorySeparatorChar)$monthForPath"
# Write-Host "Constructed todayNoteDirPath: '$todayNoteDirPath'" # Optional: Uncomment for debugging
# --- END MODIFIED PATH CONSTRUCTION ---

$todayFile = Join-Path $todayNoteDirPath "$todayFileName.md"

$cutoffDate = $todayDateObj.AddDays(-7)
$incompleteTasks = [System.Collections.Generic.List[string]]::new()

# Step 1: Scan past notes
# Write-Host "Scanning notes. Cutoff: $($cutoffDate.ToString('yyyy-MM-dd'))" # Optional
Get-ChildItem -Path $NotesDir -Filter *.md -Recurse -File | ForEach-Object {
    $fileDate = $null; try {
        $bp = $_.BaseName.Split('-'); if($bp.Count -eq 3 -and ($bp[0]-match'^\d{4}$')-and($bp[1]-match'^\d{1,2}$')-and($bp[2]-match'^\d{1,2}$')) {
            $nfs="{0:D4}-{1:D2}-{2:D2}"-f[int]$bp[0],[int]$bp[1],[int]$bp[2];$fileDate=[datetime]::ParseExact($nfs,"yyyy-MM-dd",$null) }
    } catch {}
    if($_.FullName-ne $todayFile -and $fileDate-ne $null -and $fileDate-ge $cutoffDate -and $fileDate-lt $todayDateObj){
        $fp=$_.FullName;$ls=[System.IO.File]::ReadAllLines($fp);$nls=[System.Collections.Generic.List[string]]::new();$fm=$false
        foreach($l in $ls){if($l-match'^\s*-\s\[\s\]\s(.*)'){$td=$Matches[1].Trim();$incompleteTasks.Add("- [ ] $td");$nls.Add(($l-replace'^\s*-\s\[\s\]\s','- [-->] '));$fm=$true}else{$nls.Add($l)}}
        if($fm){[System.IO.File]::WriteAllLines($fp,$nls.ToArray(),$utf8NoBom)}
    }
}

# Step 2: Create today's file
if(-not(Test-Path $todayFile)){
    if(-not(Test-Path $todayNoteDirPath)){New-Item -ItemType Directory -Path $todayNoteDirPath -Force|Out-Null}
    $hdr="# Daily Operator Log - $($todayDateObj.ToString('yyyy-MM-dd'))`r`n";$tc=[System.IO.File]::ReadAllText($Template,[System.Text.Encoding]::UTF8)
    $fc=$hdr+"`r`n"+$tc;[System.IO.File]::WriteAllText($todayFile,$fc,$utf8NoBom);Write-Host "Created: $todayFile"
}else{Write-Host "Exists: $todayFile"}

# Step 3: Inject tasks
if($incompleteTasks.Count -gt 0){
    if(Test-Path $todayFile){
        $c=[System.IO.File]::ReadAllText($todayFile,[System.Text.Encoding]::UTF8);$p='(?m)^## Task Review\s*'
        if($c-match $p){
            $trh="## Task Review";$tbn=($incompleteTasks-join"`r`n")+"`r`n";$rs=$trh+"`r`n`r`n"+$tbn
            $c=[regex]::Replace($c,$p,$rs,1);[System.IO.File]::WriteAllText($todayFile,$c,$utf8NoBom);Write-Host "Injected $($incompleteTasks.Count) tasks."
        }else{Write-Warning "Section '## Task Review' NOT FOUND in '$todayFile'. Tasks NOT injected."}
    }else{Write-Warning "'$todayFile' NOT FOUND for task injection."}
}
Write-Host "Processing complete for $Today"
Write-Host "Press any key to exit...";[System.Console]::ReadKey($true)|Out-Null
