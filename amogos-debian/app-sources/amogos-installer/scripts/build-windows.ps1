# Build a fresh Windows preview on the spacious drive while keeping the maintained source in Documents.
param([string]$OutputRoot='D:\CodexAmogOSBuild-20261031')
$ErrorActionPreference='Stop'
$taskProject=Split-Path $PSScriptRoot -Parent
$taskFlutter=Join-Path $env:USERPROFILE 'Downloads\flutter_windows_3.47.6-stable\flutter\bin\flutter.bat'
$taskStamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$taskBuild=Join-Path $OutputRoot ('preview-'+$taskStamp)
$taskArchive=Join-Path $OutputRoot ('preview-source-'+$taskStamp+'.tar.gz')
if(Test-Path -LiteralPath $taskBuild) { throw 'A build directory with this timestamp already exists' }
New-Item -ItemType Directory -Path $taskBuild | Out-Null
$taskTemp=Join-Path $OutputRoot 'temp'
New-Item -ItemType Directory -Path $taskTemp -Force | Out-Null
tar.exe -czf $taskArchive --exclude=build --exclude=dist --exclude=.dart_tool --exclude=.git --exclude=.idea --exclude=ephemeral --exclude=.plugin_symlinks --exclude=__pycache__ -C $taskProject .
if($LASTEXITCODE) { throw 'Source archive failed' }
tar.exe -xzf $taskArchive -C $taskBuild
if($LASTEXITCODE) { throw 'Source extraction failed' }
$taskPreviousTemp=$env:TEMP
$taskPreviousTmp=$env:TMP
Push-Location $taskBuild
try {
    $env:TEMP=$taskTemp
    $env:TMP=$taskTemp
    & $taskFlutter pub get
    if($LASTEXITCODE) { throw 'Dependency resolution failed' }
    & $taskFlutter analyze
    if($LASTEXITCODE) { throw 'Analysis failed' }
    & $taskFlutter build windows --release
    if($LASTEXITCODE) { throw 'Windows build failed' }
    Write-Output ('Preview: '+(Join-Path $taskBuild 'build\windows\x64\runner\Release\amogos_installer.exe'))
} finally {
    $env:TEMP=$taskPreviousTemp
    $env:TMP=$taskPreviousTmp
    Pop-Location
}
