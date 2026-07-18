param([string] $VivadoBin = "")

$ErrorActionPreference = "Stop"

if ($VivadoBin -ne "") {
    $env:PATH = "$VivadoBin;$env:PATH"
}

$SimDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutDir = Join-Path $SimDir "out"
$Wdb    = Join-Path $OutDir "uart_tx.wdb"

if (!(Test-Path -LiteralPath $Wdb -PathType Leaf)) {
    throw "XSim waveform database not found. Run .\run_xsim.ps1 first."
}

$ViewTcl = Join-Path $OutDir "view_xsim.tcl"
$WdbTcl  = $Wdb.Replace("\", "/")

@"
open_wave_database {$WdbTcl}
add_wave -r /TB_Top/*
"@ | Set-Content -LiteralPath $ViewTcl -Encoding ASCII

Push-Location $OutDir
try {
    & vivado -mode gui -source $ViewTcl -nojournal -nolog

    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location

    if (Test-Path -LiteralPath $ViewTcl) {
        Remove-Item -LiteralPath $ViewTcl -Force
    }
}
