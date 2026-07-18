param([string] $VivadoBin = "")

$ErrorActionPreference = "Stop"

if ($VivadoBin -ne "") {
    $env:PATH = "$VivadoBin;$env:PATH"
}

$SimDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$StageDir      = (Resolve-Path (Join-Path $SimDir "..")).Path
$UartRoot      = (Resolve-Path (Join-Path $StageDir "..")).Path
$OutDir        = Join-Path $SimDir "out"
$UvcDir        = (Resolve-Path (Join-Path $StageDir "uvc\uart_tx")).Path
$TestDir       = (Resolve-Path (Join-Path $StageDir "tb\test")).Path
$RtlFile       = (Resolve-Path (Join-Path $UartRoot "m00_rtl\UART_Tx.sv")).Path
$InterfaceFile = (Resolve-Path (Join-Path $UvcDir "uart_tx_if.sv")).Path
$PackageFile   = (Resolve-Path (Join-Path $UvcDir "uart_tx_pkg.sv")).Path
$TbFile        = (Resolve-Path (Join-Path $StageDir "tb\top\tb_top_v14.sv")).Path
$Snapshot      = "uart_tx_sim"
$RunTclName    = "run_xsim.tcl"
$RunTcl        = Join-Path $OutDir $RunTclName
$SimLog        = Join-Path $OutDir "sim_xsim.log"
$ExpectedCaseCount = 3
$ExpectedItemCount = 15
$ExpectedPassCount = 15
$ExpectedResult = "[SB] RESULT: pass=5 fail=0"
$ExpectedConnect = "[AP] connected"
$ExpectedBuildDone = "[TEST] SV_ANALYSIS_PORT_OBJECTS_CONNECTED"
$ExpectedTestDone = "[TEST] SV_ANALYSIS_PORT_ALL_DONE cases=3"

function Check-Exit {
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Push-Location $OutDir
try {
    & xvlog -sv -i $UvcDir -i $TestDir $RtlFile $InterfaceFile $PackageFile $TbFile
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

    $ConnectCount = @(Select-String -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedConnect).Count
    if ($ConnectCount -ne 1) {
        throw "Expected one analysis port connection, found $ConnectCount in $SimLog"
    }
    if (!(Select-String -Quiet -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedBuildDone)) {
        throw "Expected analysis port object marker not found: $ExpectedBuildDone"
    }
    $CaseStartCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[TEST\] SV_ANALYSIS_PORT_CASE_START').Count
    if ($CaseStartCount -ne $ExpectedCaseCount) {
        throw "Expected $ExpectedCaseCount case starts, found $CaseStartCount in $SimLog"
    }
    $CaseDoneCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[TEST\] SV_ANALYSIS_PORT_CASE_DONE').Count
    if ($CaseDoneCount -ne $ExpectedCaseCount) {
        throw "Expected $ExpectedCaseCount case completions, found $CaseDoneCount in $SimLog"
    }
    $SequencerPutCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SEQR\] put item:').Count
    if ($SequencerPutCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount sequencer put results, found $SequencerPutCount in $SimLog"
    }
    $SequencerGetCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SEQR\] get_next_item:').Count
    if ($SequencerGetCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount sequencer get_next_item results, found $SequencerGetCount in $SimLog"
    }
    $PortGetCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[PORT\] get_next_item req:').Count
    if ($PortGetCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount seq_item_port get results, found $PortGetCount in $SimLog"
    }
    $PortDoneCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[PORT\] item_done').Count
    if ($PortDoneCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount seq_item_port done results, found $PortDoneCount in $SimLog"
    }
    $SequencerDoneCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SEQR\] item_done').Count
    if ($SequencerDoneCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount sequencer done results, found $SequencerDoneCount in $SimLog"
    }
    $SequenceCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SEQ\] port item/expected:').Count
    if ($SequenceCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount sequence item results, found $SequenceCount in $SimLog"
    }
    $ExpectedQueueCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SB\] expected queued:').Count
    if ($ExpectedQueueCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount expected queue results, found $ExpectedQueueCount in $SimLog"
    }
    $DriverCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[DRV\] driving req:').Count
    if ($DriverCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount driver request results, found $DriverCount in $SimLog"
    }
    $MonitorCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[MON\] captured item:').Count
    if ($MonitorCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount monitor item results, found $MonitorCount in $SimLog"
    }
    $AnalysisPortWriteCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[AP\] write item:').Count
    if ($AnalysisPortWriteCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount analysis port writes, found $AnalysisPortWriteCount in $SimLog"
    }
    $AnalysisImpWriteCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[IMP\] write item:').Count
    if ($AnalysisImpWriteCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount analysis imp writes, found $AnalysisImpWriteCount in $SimLog"
    }
    $PassCount = @(Select-String -LiteralPath $SimLog -Pattern '^\[SB\] PASS:').Count
    if ($PassCount -ne $ExpectedPassCount) {
        throw "Expected $ExpectedPassCount scoreboard PASS results, found $PassCount in $SimLog"
    }
    $ResultCount = @(Select-String -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedResult).Count
    if ($ResultCount -ne $ExpectedCaseCount) {
        throw "Expected $ExpectedCaseCount scoreboard results '$ExpectedResult', found $ResultCount in $SimLog"
    }
    if (!(Select-String -Quiet -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedTestDone)) {
        throw "Expected test completion marker not found: $ExpectedTestDone"
    }
}
finally {
    Pop-Location
}
