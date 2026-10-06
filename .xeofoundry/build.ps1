[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$PlatformTarget,

	[switch]$Clean,

	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$CMakeArgs
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

switch ($PlatformTarget) {
	"win-x64" {
		$ExpectedArch = "AMD64"
	}
	default {
		Write-Error "unknown platform target: $PlatformTarget"
		exit 1
	}
}

$HostArch = $env:PROCESSOR_ARCHITECTURE
if ($HostArch -ne $ExpectedArch) {
	Write-Error "platform target $PlatformTarget requires host architecture $ExpectedArch, found $HostArch"
	exit 1
}

$BuildDir = Join-Path $ScriptDir "build/$PlatformTarget"

if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
	Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

$configureArgs = @(
	"-S", $ScriptDir,
	"-B", $BuildDir,
	"-G", "Ninja",
	"-DCMAKE_C_COMPILER=clang-cl",
	"-DCMAKE_CXX_COMPILER=clang-cl"
)
if ($CMakeArgs.Count -gt 0) {
	$configureArgs += $CMakeArgs
}

& cmake @configureArgs
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

& cmake --build $BuildDir --config Release
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
