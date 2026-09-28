#Requires -Version 7.0
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'tools.ps1')

$pwsh = (Get-Process -Id $PID).Path
$captured = Invoke-PackageTool $pwsh @('-NoProfile', '-Command', '[Console]::Out.WriteLine("stdout evidence"); [Console]::Error.WriteLine("stderr evidence"); exit 7')
if ($captured.ExitCode -ne 7 -or $captured.Output -notmatch 'stdout evidence' -or $captured.Output -notmatch 'stderr evidence') {
    throw 'Native exit code or captured streams were lost.'
}

$previous = [Environment]::GetEnvironmentVariable('LUAU_LSP_OVERRIDE', 'Process')
try {
    foreach ($case in @(
        @{ Path = 'relative-lsp.exe'; Expected = 'absolute executable path' },
        @{ Path = (Join-Path (Get-PackageRoot) '.verification/missing-lsp.exe'); Expected = 'Missing tool' },
        @{ Path = $pwsh; Expected = 'Expected luau-lsp 1.70.1' }
    )) {
        [Environment]::SetEnvironmentVariable('LUAU_LSP_OVERRIDE', $case.Path, 'Process')
        $message = ''
        try { Resolve-PackageTool 'luau-lsp' | Out-Null } catch { $message = $_.Exception.Message }
        if ($message -notmatch [regex]::Escape($case.Expected)) {
            throw "Override fixture expected '$($case.Expected)', got '$message'."
        }
    }
} finally {
    [Environment]::SetEnvironmentVariable('LUAU_LSP_OVERRIDE', $previous, 'Process')
}
Write-Output 'PASS: both native streams, exit preservation, relative/missing/wrong-version override rejection.'
