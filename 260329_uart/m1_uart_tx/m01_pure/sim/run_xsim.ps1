param([string] $VivadoBin = "")

$ErrorActionPreference = "Stop"

if ($VivadoBin -ne "") {
    $env:PATH = "$VivadoBin;$env:PATH"
}

$SimDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$StageDir = (Resolve-Path (Join-Path $SimDir "..")).Path
$UartRoot = (Resolve-Path (Join-Path $StageDir "..")).Path
$OutDir   = Join-Path $SimDir "out"
$RtlFile  = (Resolve-Path (Join-Path $UartRoot "m00_rtl\UART_Tx.sv")).Path
$TbFile   = (Resolve-Path (Join-Path $StageDir "tb\tb_top_v1.sv")).Path
$Snapshot = "uart_tx_sim"
$RunTclName = "run_xsim.tcl"
$RunTcl     = Join-Path $OutDir $RunTclName
$SimLog     = Join-Path $OutDir "sim_xsim.log"

function Check-Exit {
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Push-Location $OutDir
try {
    & xvlog -sv $RtlFile $TbFile
    Check-Exit

    & xelab TB_Top -debug typical -s $Snapshot
    Check-Exit

    @"
log_wave -r /*
run all
quit
"@ | Set-Content -LiteralPath $RunTcl -Encoding ASCII

    & xsim $Snapshot -tclbatch $RunTclName -log sim_xsim.log -wdb uart_tx.wdb
    Check-Exit

    if (!(Select-String -Quiet -LiteralPath $SimLog -Pattern '^PASS:')) {
        throw "Simulation PASS result not found: $SimLog"
    }
}
finally {
    Pop-Location
}
