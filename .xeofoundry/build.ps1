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

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio/Installer/vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere)) {
	Write-Error "vswhere not found; install Visual Studio with the C++ build tools"
	exit 1
}

$vsInstall = & $vswhere -latest -products "*" -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsInstall) {
	Write-Error "no Visual Studio installation with the C++ build tools found"
	exit 1
}

$vcvars = Join-Path $vsInstall "VC/Auxiliary/Build/vcvars64.bat"
if (-not (Test-Path -LiteralPath $vcvars)) {
	Write-Error "vcvars64.bat not found at $vcvars"
	exit 1
}

& cmd.exe /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
	if ($_ -match "^([^=]+)=(.*)$") {
		Set-Item -Path "Env:$($matches[1])" -Value $matches[2]
	}
}

$BuildDir = Join-Path $ScriptDir "build/$PlatformTarget"

if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
	Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

$configureArgs = @(
	"-S", $ScriptDir,
	"-B", $BuildDir,
	"-G", "NMake Makefiles",
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
