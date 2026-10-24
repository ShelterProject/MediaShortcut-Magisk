#requires -Version 5.1
<#
    Packages Media Shortcuts into a flashable Magisk zip.

    Run it from anywhere:

        .\build.ps1

    You get media_shortcuts-<version>.zip sitting next to this script.
    Install with the Magisk app, or from adb:

        adb push media_shortcuts-v1.0.zip /sdcard/Download/
        adb shell su -c "magisk --install-module /sdcard/Download/media_shortcuts-v1.0.zip"
#>

$ErrorActionPreference = 'Stop'

$Root     = $PSScriptRoot
$PropFile = Join-Path $Root 'module.prop'

if (-not (Test-Path $PropFile)) {
    throw "module.prop is missing from $Root"
}

# --- read module.prop ------------------------------------------------------

$Prop = @{}
foreach ($line in Get-Content $PropFile) {
    if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$') {
        $Prop[$matches[1]] = $matches[2].Trim()
    }
}

$ModuleId = $Prop['id']
if ([string]::IsNullOrWhiteSpace($ModuleId)) {
    throw "module.prop has no id= line"
}

$Version = if ($Prop['version']) { $Prop['version'] } else { 'dev' }
$ZipName = "$ModuleId-$Version.zip"
$ZipPath = Join-Path $Root $ZipName

Write-Host ""
Write-Host "  $($Prop['name'])  $Version"
Write-Host "  id: $ModuleId"
Write-Host ""

# --- stage -----------------------------------------------------------------

$Stage = Join-Path $env:TEMP "media_shortcuts_stage"
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

# Build tooling and docs stay out of the zip.
$Skip = @(
    'build.ps1'
    'build.bat'
    'build.sh'
    'README.md'
    'LICENSE'
    '.git'
    '.gitignore'
    '.gitattributes'
    'META-INF'
    $ZipName
)

Get-ChildItem -Path $Root -Force | Where-Object { $Skip -notcontains $_.Name } | ForEach-Object {
    Copy-Item $_.FullName -Destination $Stage -Recurse -Force
}

# Installer stubs, written straight into the stage so the repo stays clean.
$MetaDir = Join-Path $Stage 'META-INF\com\google\android'
New-Item -ItemType Directory -Force -Path $MetaDir | Out-Null

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText(
    (Join-Path $MetaDir 'updater-script'),
    "#MAGISK`n",
    $Utf8NoBom
)

$UpdateBinary = @'
#!/sbin/sh
umask 022
OUTFD=$2
ZIPFILE=$3
mount /data 2>/dev/null
[ -f /data/adb/magisk/util_functions.sh ] || { echo "! Magisk not found"; exit 1; }
. /data/adb/magisk/util_functions.sh
install_module
exit 0
'@ -replace "`r`n", "`n"

[System.IO.File]::WriteAllText(
    (Join-Path $MetaDir 'update-binary'),
    $UpdateBinary,
    $Utf8NoBom
)

# --- zip -------------------------------------------------------------------
# Entries are added one by one. CreateFromDirectory writes Windows path
# separators, and Magisk will not find META-INF if it is stored that way.

if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$StageFull = (Resolve-Path $Stage).Path
$ZipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
$Archive = New-Object System.IO.Compression.ZipArchive(
    $ZipStream,
    [System.IO.Compression.ZipArchiveMode]::Create
)

try {
    Get-ChildItem -Path $StageFull -Recurse -File | ForEach-Object {
        $Rel = $_.FullName.Substring($StageFull.Length + 1).Replace('\', '/')
        $Entry = $Archive.CreateEntry($Rel, [System.IO.Compression.CompressionLevel]::Optimal)
        $Entry.LastWriteTime = $_.LastWriteTime

        $In = [System.IO.File]::OpenRead($_.FullName)
        $Out = $Entry.Open()
        try {
            $In.CopyTo($Out)
        } finally {
            $Out.Dispose()
            $In.Dispose()
        }
    }
} finally {
    $Archive.Dispose()
    $ZipStream.Dispose()
}

Remove-Item $Stage -Recurse -Force

# --- sanity check ----------------------------------------------------------

Add-Type -AssemblyName System.IO.Compression
$Archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $Entries = $Archive.Entries | ForEach-Object { $_.FullName }
} finally {
    $Archive.Dispose()
}

$Required = @(
    'module.prop'
    'META-INF/com/google/android/update-binary'
    'META-INF/com/google/android/updater-script'
)

$Missing = $Required | Where-Object { $Entries -notcontains $_ }
if ($Missing) {
    throw "zip is missing: $($Missing -join ', ')"
}

$SizeKb = [math]::Round((Get-Item $ZipPath).Length / 1KB, 1)

Write-Host "  built   $ZipPath"
Write-Host "  size    $SizeKb KB"
Write-Host "  files   $($Entries.Count)"
Write-Host ""
Write-Host "  adb push `"$ZipPath`" /sdcard/Download/$ZipName"
Write-Host "  adb shell su -c `"magisk --install-module /sdcard/Download/$ZipName`""
Write-Host ""
