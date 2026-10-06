[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$FixtureFolder
)

$ErrorActionPreference = "Stop"

function Read-U32([byte[]]$Bytes, [int]$Offset) {
	return [System.BitConverter]::ToUInt32($Bytes, $Offset)
}

function Read-U64([byte[]]$Bytes, [int]$Offset) {
	return [System.BitConverter]::ToUInt64($Bytes, $Offset)
}

function Read-Double([byte[]]$Bytes, [int]$Offset) {
	return [System.BitConverter]::ToDouble($Bytes, $Offset)
}

if (-not (Test-Path -LiteralPath $FixtureFolder -PathType Container)) {
	throw "fixture folder not found: $FixtureFolder"
}

$converter = Join-Path $PWD.Path "PotreeConverter.exe"
if (-not (Test-Path -LiteralPath $converter -PathType Leaf)) {
	throw "PotreeConverter.exe not found in $($PWD.Path); run this from the target build directory"
}

$fixtures = @(Get-ChildItem -LiteralPath $FixtureFolder -File | Where-Object { $_.Extension -match '^\.(las|laz)$' })
if ($fixtures.Count -eq 0) {
	throw "no .las or .laz fixtures in $FixtureFolder"
}

$resultRoot = Join-Path $PSScriptRoot "result"
if (Test-Path -LiteralPath $resultRoot) {
	Remove-Item -LiteralPath $resultRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $resultRoot | Out-Null

foreach ($fixture in $fixtures) {
	foreach ($encoding in @("UNCOMPRESSED", "BROTLI")) {
		$outdir = Join-Path $resultRoot ("{0}-{1}" -f $fixture.Name, $encoding)
		New-Item -ItemType Directory -Path $outdir | Out-Null

		Write-Host "smoke: $($fixture.Name) ($encoding)"

		$conversionLog = Join-Path $outdir "conversion.log"
		& $converter $fixture.FullName -o $outdir --encoding $encoding *> $conversionLog
		if ($LASTEXITCODE -ne 0) {
			Get-Content -LiteralPath $conversionLog | Write-Host
			throw "conversion failed for $($fixture.Name) ($encoding)"
		}

		foreach ($artifact in @("metadata.json", "hierarchy.bin", "octree.bin")) {
			$artifactPath = Join-Path $outdir $artifact
			if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
				throw "missing $artifact for $($fixture.Name) ($encoding)"
			}
			if ((Get-Item -LiteralPath $artifactPath).Length -eq 0) {
				throw "empty $artifact for $($fixture.Name) ($encoding)"
			}
		}

		$header = [System.IO.File]::ReadAllBytes($fixture.FullName)
		if ($header.Length -lt 375) {
			throw "$($fixture.Name): LAS header too short"
		}
		if ([System.Text.Encoding]::ASCII.GetString($header, 0, 4) -ne "LASF") {
			throw "$($fixture.Name): not a LAS file"
		}

		$versionMajor = $header[24]
		$versionMinor = $header[25]

		$legacyCount = Read-U32 $header 107
		if ($versionMajor -gt 1 -or ($versionMajor -eq 1 -and $versionMinor -ge 4)) {
			$extendedCount = Read-U64 $header 247
			if ($extendedCount -gt 0) {
				$declaredCount = $extendedCount
			}
			else {
				$declaredCount = $legacyCount
			}
		}
		else {
			$declaredCount = $legacyCount
		}

		$fixtureScale = @((Read-Double $header 131), (Read-Double $header 139), (Read-Double $header 147))
		$fixtureMin = @((Read-Double $header 187), (Read-Double $header 203), (Read-Double $header 219))
		$fixtureMax = @((Read-Double $header 179), (Read-Double $header 195), (Read-Double $header 211))

		$metadata = Get-Content -LiteralPath (Join-Path $outdir "metadata.json") -Raw | ConvertFrom-Json

		if ($metadata.points -ne $declaredCount) {
			throw "points $($metadata.points) != fixture count $declaredCount"
		}
		if ($metadata.encoding -ne $encoding) {
			throw "encoding $($metadata.encoding) != $encoding"
		}
		if (@($metadata.attributes).Count -eq 0) {
			throw "attributes list is empty"
		}

		$bboxMin = $metadata.boundingBox.min
		$bboxMax = $metadata.boundingBox.max

		$cubeSize = 0.0
		for ($i = 0; $i -lt 3; $i++) {
			$span = $fixtureMax[$i] - $fixtureMin[$i]
			if ($span -gt $cubeSize) {
				$cubeSize = $span
			}
		}

		for ($i = 0; $i -lt 3; $i++) {
			$step = $fixtureScale[$i]
			if ($bboxMin[$i] -gt $bboxMax[$i]) {
				throw "boundingBox min > max on axis $i"
			}
			if ([math]::Abs($bboxMin[$i] - $fixtureMin[$i]) -gt $step) {
				throw "boundingBox.min[$i]=$($bboxMin[$i]) not within $step of $($fixtureMin[$i])"
			}
			$expectedMax = $fixtureMin[$i] + $cubeSize
			if ([math]::Abs($bboxMax[$i] - $expectedMax) -gt $step) {
				throw "boundingBox.max[$i]=$($bboxMax[$i]) not within $step of $expectedMax"
			}
		}
	}
}

Write-Host "smoke: all conversions passed"
Write-Host "smoke: results in $resultRoot"
