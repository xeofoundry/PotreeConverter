[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$PlatformTarget,

	[switch]$Clean
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

switch ($PlatformTarget) {
	"win-x64" {
		$Executable = "PotreeConverter.exe"
	}
	"linux-x64" {
		$Executable = "PotreeConverter"
	}
	"linux-arm64" {
		$Executable = "PotreeConverter"
	}
	default {
		Write-Error "unknown platform target: $PlatformTarget"
		exit 1
	}
}

$BuildDir = Join-Path $RootDir "build/$PlatformTarget"
$ReleaseDir = Join-Path $RootDir ".release/$PlatformTarget"

if (-not (Test-Path -LiteralPath $BuildDir)) {
	Write-Error "build directory not found: $BuildDir; build it first with .\.xeofoundry\build.ps1 -PlatformTarget $PlatformTarget"
	exit 1
}

$exePath = Join-Path $BuildDir $Executable
if (-not (Test-Path -LiteralPath $exePath)) {
	Write-Error "executable not found: $exePath"
	exit 1
}

if ($Clean -and (Test-Path -LiteralPath $ReleaseDir)) {
	Remove-Item -LiteralPath $ReleaseDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null

Copy-Item -LiteralPath $exePath -Destination $ReleaseDir

foreach ($file in @("VERSION", "README.md")) {
	$path = Join-Path $BuildDir $file
	if (Test-Path -LiteralPath $path) {
		Copy-Item -LiteralPath $path -Destination $ReleaseDir
	}
}

foreach ($dir in @("licenses", "resources")) {
	$path = Join-Path $BuildDir $dir
	if (Test-Path -LiteralPath $path) {
		Copy-Item -LiteralPath $path -Destination $ReleaseDir -Recurse
	}
}

$sharedLibs = @(Get-ChildItem -LiteralPath $BuildDir -Filter "liblaszip.so*" -ErrorAction SilentlyContinue) + @(Get-ChildItem -LiteralPath $BuildDir -Filter "laszip.dll" -ErrorAction SilentlyContinue)
foreach ($lib in $sharedLibs) {
	Copy-Item -LiteralPath $lib.FullName -Destination $ReleaseDir
}

Write-Host "collected $PlatformTarget release files at $ReleaseDir"
Get-ChildItem -LiteralPath $ReleaseDir | Select-Object -ExpandProperty Name | Sort-Object | ForEach-Object { Write-Host "  $_" }
