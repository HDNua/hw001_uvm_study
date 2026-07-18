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
$TbFile        = (Resolve-Path (Join-Path $StageDir "tb\top\tb_top_v15.sv")).Path
$Snapshot      = "uart_tx_sim"
$RunTclName    = "run_xsim.tcl"
$RunTcl        = Join-Path $OutDir $RunTclName
$SimLog        = Join-Path $OutDir "sim_xsim.log"
$ExpectedCaseCount = 3
$ExpectedItemCount = 15
$ExpectedPassCount = 15
$ExpectedResult = "[SB] RESULT: pass=5 fail=0"
$ExpectedTopStart = "[TOP] UVM_MINIMAL_RUN_TEST_START"
$ExpectedBuildDone = "[TEST] UVM_MINIMAL_COMPONENTS_BUILT"
$ExpectedTestDone = "[TEST] UVM_MINIMAL_ALL_DONE cases=3"

function Check-Exit {
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Push-Location $OutDir
try {
    # Vivado/XSim에 포함된 UVM library를 사용한다.
    & xvlog -sv -L uvm -i $UvcDir -i $TestDir $RtlFile $InterfaceFile $PackageFile $TbFile
    Check-Exit

    & xelab TB_Top -L uvm --timescale 1ns/1ps -debug typical -s $Snapshot
    Check-Exit

    @"
log_wave -r /*
run all
quit
"@ | Set-Content -LiteralPath $RunTcl -Encoding ASCII

    & xsim $Snapshot -tclbatch $RunTclName -log sim_xsim.log -wdb uart_tx.wdb
    Check-Exit

    $LogText = Get-Content -LiteralPath $SimLog -Raw
    if (($LogText -match 'UVM_ERROR\s*:\s*[1-9]') -or
        ($LogText -match 'UVM_FATAL\s*:\s*[1-9]')) {
        throw "UVM reported errors or fatals. See $SimLog"
    }
    if (($LogText -notmatch 'UVM_ERROR\s*:\s*0') -or
        ($LogText -notmatch 'UVM_FATAL\s*:\s*0')) {
        throw "UVM zero-error summary not found in $SimLog"
    }
    if (!(Select-String -Quiet -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedTopStart)) {
        throw "Expected UVM top marker not found: $ExpectedTopStart"
    }
    if (!(Select-String -Quiet -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedBuildDone)) {
        throw "Expected UVM build marker not found: $ExpectedBuildDone"
    }
    $AgentConnectCount = @(Select-String -LiteralPath $SimLog -Pattern '\[AGENT\] seq_item_port connected').Count
    if ($AgentConnectCount -ne 1) {
        throw "Expected one seq_item_port connection, found $AgentConnectCount in $SimLog"
    }
    $EnvConnectCount = @(Select-String -LiteralPath $SimLog -Pattern '\[ENV\] expected/actual analysis ports connected').Count
    if ($EnvConnectCount -ne 1) {
        throw "Expected one analysis path connection, found $EnvConnectCount in $SimLog"
    }
    $CaseStartCount = @(Select-String -LiteralPath $SimLog -Pattern '\[TEST\] UVM_MINIMAL_CASE_START').Count
    if ($CaseStartCount -ne $ExpectedCaseCount) {
        throw "Expected $ExpectedCaseCount case starts, found $CaseStartCount in $SimLog"
    }
    $CaseDoneCount = @(Select-String -LiteralPath $SimLog -Pattern '\[TEST\] UVM_MINIMAL_CASE_DONE').Count
    if ($CaseDoneCount -ne $ExpectedCaseCount) {
        throw "Expected $ExpectedCaseCount case completions, found $CaseDoneCount in $SimLog"
    }
    $SequenceCount = @(Select-String -LiteralPath $SimLog -Pattern '\[SEQ\] sent item/expected:').Count
    if ($SequenceCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount UVM sequence items, found $SequenceCount in $SimLog"
    }
    $DriverCount = @(Select-String -LiteralPath $SimLog -Pattern '\[DRV\] driving req:').Count
    if ($DriverCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount UVM driver requests, found $DriverCount in $SimLog"
    }
    $ExpectedCount = @(Select-String -LiteralPath $SimLog -Pattern '\[SB\] expected item:').Count
    if ($ExpectedCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount expected analysis writes, found $ExpectedCount in $SimLog"
    }
    $MonitorCount = @(Select-String -LiteralPath $SimLog -Pattern '\[MON\] captured item:').Count
    if ($MonitorCount -ne $ExpectedItemCount) {
        throw "Expected $ExpectedItemCount UVM monitor items, found $MonitorCount in $SimLog"
    }
    $PassCount = @(Select-String -LiteralPath $SimLog -Pattern '\[SB\] PASS:').Count
    if ($PassCount -ne $ExpectedPassCount) {
        throw "Expected $ExpectedPassCount scoreboard PASS results, found $PassCount in $SimLog"
    }
    $ResultCount = @(Select-String -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedResult).Count
    if ($ResultCount -ne $ExpectedCaseCount) {
        throw "Expected $ExpectedCaseCount scoreboard results '$ExpectedResult', found $ResultCount in $SimLog"
    }
    if (!(Select-String -Quiet -SimpleMatch -LiteralPath $SimLog -Pattern $ExpectedTestDone)) {
        throw "Expected UVM test completion marker not found: $ExpectedTestDone"
    }
}
finally {
    Pop-Location
}
