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
$TbFile   = (Resolve-Path (Join-Path $StageDir "tb\tb_top_v6.sv")).Path
$Snapshot = "uart_tx_sim"
$RunTclName = "run_xsim.tcl"
$RunTcl     = Join-Path $OutDir $RunTclName
$SimLog     = Join-Path $OutDir "sim_xsim.log"
$ExpectedRoleCount = 5
$ExpectedPassCount = 5
$ExpectedResult = "[SB] RESULT: pass=5 fail=0"

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

    $SequenceCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SEQ\] queued:').Count
    if ($SequenceCount -ne $ExpectedRoleCount) {
        throw "Expected $ExpectedRoleCount sequence queue results, found $SequenceCount in $SimLog"
    }
    $DriverCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[DRV\] driving:').Count
    if ($DriverCount -ne $ExpectedRoleCount) {
        throw "Expected $ExpectedRoleCount driver results, found $DriverCount in $SimLog"
    }
    $PassCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SB\] PASS:').Count
    if ($PassCount -ne $ExpectedPassCount) {
        throw "Expected $ExpectedPassCount scoreboard PASS results, found $PassCount in $SimLog"
    }
    if (!(Select-String -Quiet -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedResult)) {
        throw "Expected scoreboard result not found: $ExpectedResult"
    }
}
finally {
    Pop-Location
}
