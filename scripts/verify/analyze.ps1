[CmdletBinding()]
param(
	[string]$Project = "dev.project.json",
	[string]$Sourcemap = "dev-sourcemap.json",
	[string]$Definitions = "",
	[string[]]$Paths = @("src", "tests/type-contracts")
)

$ErrorActionPreference = "Stop"

if (-not $Definitions) {
	$Definitions = Join-Path $PSScriptRoot "..\luau-lsp\globalTypes.d.luau"
}

function Resolve-RokitBinary {
	param([string]$Name)

	$rokitBin = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".rokit\bin"
	foreach ($fileName in @("$Name.exe", $Name)) {
		$binaryPath = Join-Path $rokitBin $fileName
		if (Test-Path -LiteralPath $binaryPath -PathType Leaf) {
			return $binaryPath
		}
	}

	throw "Rokit-managed '$Name' binary was not found in '$rokitBin'. Run 'rokit install' from the repository root."
}

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$definitionsPath = Resolve-Path -LiteralPath $Definitions -ErrorAction SilentlyContinue
if (-not $definitionsPath) {
	throw "Roblox definitions were not found at '$Definitions'. Run scripts/luau-lsp/fetch-roblox-types.ps1 first."
}

$rojo = Resolve-RokitBinary "rojo"
$luauLsp = Resolve-RokitBinary "luau-lsp"
$existingPaths = @($Paths | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot $_) })
if ($existingPaths.Count -eq 0) {
	throw "No requested Luau-LSP paths exist."
}

Push-Location $repoRoot
try {
	& $rojo "sourcemap" $Project "--output" $Sourcemap
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	& $luauLsp "analyze" "--sourcemap=$Sourcemap" "--definitions:@roblox=$($definitionsPath.ProviderPath)" @existingPaths
	exit $LASTEXITCODE
} finally {
	Pop-Location
}
