[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$PlatformTarget
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

switch ($PlatformTarget) {
	"win-x64" {
		$Extension = ".zip"
	}
	"linux-x64" {
		$Extension = ".tar.gz"
	}
	"linux-arm64" {
		$Extension = ".tar.gz"
	}
	default {
		Write-Error "unknown platform target: $PlatformTarget"
		exit 1
	}
}

$ReleaseRoot = Join-Path $RootDir ".release"
$ReleaseDir = Join-Path $ReleaseRoot $PlatformTarget

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
	Write-Error "release directory not found: $ReleaseDir; collect it first with .\.xeofoundry\collect.ps1 -PlatformTarget $PlatformTarget"
	exit 1
}

$versionFile = Join-Path $ReleaseDir "VERSION"
if (-not (Test-Path -LiteralPath $versionFile)) {
	Write-Error "version file not found: $versionFile"
	exit 1
}

$versionValue = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($versionValue.StartsWith("v")) {
	$versionValue = $versionValue.Substring(1)
}

$archiveBase = "PotreeConverter_${versionValue}_$PlatformTarget"
$archivePath = Join-Path $ReleaseRoot "$archiveBase$Extension"

$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$stagedDir = Join-Path $stagingDir $archiveBase
New-Item -ItemType Directory -Force -Path $stagedDir | Out-Null

try {
	Copy-Item -Path (Join-Path $ReleaseDir "*") -Destination $stagedDir -Recurse -Force

	if (Test-Path -LiteralPath $archivePath) {
		Remove-Item -LiteralPath $archivePath -Force
	}

	switch ($PlatformTarget) {
		"win-x64" {
			Compress-Archive -Path $stagedDir -DestinationPath $archivePath -Force
		}
		default {
			& tar -czf $archivePath -C $stagingDir $archiveBase
			if ($LASTEXITCODE -ne 0) {
				exit $LASTEXITCODE
			}
		}
	}
}
finally {
	Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "archived $PlatformTarget release at $archivePath"
Get-Item -LiteralPath $archivePath | Select-Object Name, @{Name = "SizeMB"; Expression = { [math]::Round($_.Length / 1MB, 2) } } | Format-Table -AutoSize
