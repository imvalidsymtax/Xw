<#
.SYNOPSIS
    Zrzuca zawartosc plikow .pas do jednego pliku tekstowego.
.EXAMPLE
    .\dump-sources.ps1
    .\dump-sources.ps1 -Path src -Output dump.txt -Extensions .pas,.dpr,.inc
#>
[CmdletBinding()]
param(
    [string]   $Path = '.',
    [string]   $Output = 'sources-dump.txt',
    [string[]] $Extensions = @('.pas'),
    [string[]] $ExcludeDirs = @('__recovery', '__history', '.git', 'Win32', 'Win64', 'Debug', 'Release'),
    [string]   $Encoding = 'windows-1250'
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).ProviderPath
$outFull = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine((Get-Location).ProviderPath, $Output))

# separatory po obu stronach, zeby 'history' w nazwie projektu nie wywalilo katalogu
$sep = [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)
$excludeRx = ($ExcludeDirs | ForEach-Object { [regex]::Escape($_) }) -join '|'
$excludeRx = "(^|$sep)($excludeRx)($sep|`$)"

$srcEnc = [System.Text.Encoding]::GetEncoding($Encoding)

function Get-RelPath {
    param([string]$Base, [string]$Full)

    if (-not $Base.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $Base += [System.IO.Path]::DirectorySeparatorChar
    }

    $baseUri = [Uri]::new($Base)
    $fullUri = [Uri]::new($Full)

    return [Uri]::UnescapeDataString(
        $baseUri.MakeRelativeUri($fullUri).ToString()
    ) -replace '/', [System.IO.Path]::DirectorySeparatorChar
}

$files = Get-ChildItem -LiteralPath $root -Recurse -File |
    Where-Object { $Extensions -contains $_.Extension } |
    Where-Object { $_.FullName -ne $outFull } |
    Where-Object { $_.DirectoryName -notmatch $excludeRx } |
    Sort-Object FullName

if (-not $files) {
    Write-Warning "Nie znaleziono plikow ($($Extensions -join ', ')) w $root"
    return
}

$sw = [System.IO.StreamWriter]::new($outFull, $false, [System.Text.UTF8Encoding]::new($true))
try {
    $sw.WriteLine("// dump: $root")
    $sw.WriteLine("// data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $sw.WriteLine("// plikow: $($files.Count)")
    $sw.WriteLine()

    foreach ($f in $files) {
        $rel = Get-RelPath -Base $root -Full $f.FullName
        $sw.WriteLine(('=' * 78))
        $sw.WriteLine("=== $rel")
        $sw.WriteLine(('=' * 78))
        $sw.WriteLine()
        $sw.WriteLine([System.IO.File]::ReadAllText($f.FullName, $srcEnc))
        $sw.WriteLine()
    }
}
finally {
    $sw.Dispose()
}

$kb = [math]::Round((Get-Item -LiteralPath $outFull).Length / 1KB, 1)
Write-Host "Zapisano $($files.Count) plikow -> $Output ($kb KB)" -ForegroundColor Green