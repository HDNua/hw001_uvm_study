param(
    [string] $VivadoBin = "",
    [int] $Seed = 1,
    [int] $NumBytes = 5
)

$ErrorActionPreference = "Stop"

if ($VivadoBin -ne "") {
    $env:PATH = "$VivadoBin;$env:PATH"
}

if ($Seed -lt 0) {
    throw "Seed must be >= 0"
}
if ($NumBytes -lt 2) {
    throw "NumBytes must be >= 2 for the mid-reset case"
}

$SimDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$StageDir      = (Resolve-Path (Join-Path $SimDir "..")).Path
$ModuleRoot    = (Resolve-Path (Join-Path $StageDir "..")).Path
$OutDir        = Join-Path $SimDir "out"
$UvcDir        = (Resolve-Path (Join-Path $StageDir "uvc\uart_tx")).Path
$TestDir       = (Resolve-Path (Join-Path $StageDir "tb\test")).Path
$RtlFile       = (Resolve-Path (Join-Path $ModuleRoot "m00_rtl\UART_Tx.sv")).Path
$InterfaceFile = (Resolve-Path (Join-Path $UvcDir "uart_tx_if.sv")).Path
$PackageFile   = (Resolve-Path (Join-Path $UvcDir "uart_tx_pkg.sv")).Path
$TbFile        = (Resolve-Path (Join-Path $StageDir "tb\top\tb_top.sv")).Path
$Snapshot      = "uart_tx_sim"
$RunTclName    = "run_xsim.tcl"
$RunTcl        = Join-Path $OutDir $RunTclName
$SimLog        = Join-Path $OutDir "sim_xsim.log"
$ExpectedCaseCount = 5
$ExpectedDropCount = 1

function Check-Exit {
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Get-MarkerCount {
    param([string] $Pattern)
    return @(Select-String -LiteralPath $SimLog -Pattern $Pattern).Count
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

    # xsim은 batch 래퍼라서 = 이 인자 구분자로 쪼개지지 않게 따옴표를 내장한다.
    & xsim $Snapshot -tclbatch $RunTclName -log sim_xsim.log -wdb uart_tx.wdb `
        -testplusarg "`"SEED=$Seed`"" -testplusarg "`"NUM_BYTES=$NumBytes`""
    Check-Exit

    $LogText = Get-Content -LiteralPath $SimLog -Raw

    # 1) UVM error/fatal 요약이 0이어야 한다.
    if (($LogText -match 'UVM_ERROR\s*:\s*[1-9]') -or
        ($LogText -match 'UVM_FATAL\s*:\s*[1-9]')) {
        throw "UVM reported errors or fatals. See $SimLog"
    }
    if (($LogText -notmatch 'UVM_ERROR\s*:\s*0') -or
        ($LogText -notmatch 'UVM_FATAL\s*:\s*0')) {
        throw "UVM zero-error summary not found in $SimLog"
    }

    # 1-1) SVA가 활성화되어 있고 assertion 실패가 없어야 한다.
    if ($LogText -match '(?im)SVA a_') {
        throw "SVA assertion failure found in $SimLog"
    }

    # 2) 실행 marker와 config echo를 확인한다.
    #    TB가 스크립트와 같은 seed/num_bytes로 실행됐음을 보장한다.
    foreach ($Marker in @(
        "[TOP] UART_TX_VERIF_RUN_TEST_START",
        "[IF] UART_TX_VERIF_SVA_ACTIVE props=4",
        "[TEST] UART_TX_VERIF_COMPONENTS_BUILT",
        "[TEST] UART_TX_VERIF_CONFIG seed=$Seed num_bytes=$NumBytes",
        "[TEST] UART_TX_VERIF_ALL_DONE cases=$ExpectedCaseCount"
    )) {
        if (!(Select-String -Quiet -SimpleMatch -LiteralPath $SimLog -Pattern $Marker)) {
            throw "Expected marker not found: $Marker"
        }
    }

    # 3) case 시작·종료 수가 맞아야 한다.
    $CaseStartCount = Get-MarkerCount '\[TEST\] UART_TX_VERIF_CASE_START'
    $CaseDoneCount  = Get-MarkerCount '\[TEST\] UART_TX_VERIF_CASE_DONE'
    if (($CaseStartCount -ne $ExpectedCaseCount) -or ($CaseDoneCount -ne $ExpectedCaseCount)) {
        throw "Expected $ExpectedCaseCount case start/done, found start=$CaseStartCount done=$CaseDoneCount"
    }

    # 4) 경로 불변식: 자극 경로(seq == drv == exp)와 관측 경로(mon == pass)가
    #    각각 일치해야 한다. 리셋으로 잘린 byte만큼 관측 경로가 짧다.
    $SequenceCount   = Get-MarkerCount '\[SEQ\] sent item/expected:'
    $DriverCount     = Get-MarkerCount '\[DRV\] driving req:'
    $ExpectedWrCount = Get-MarkerCount '\[SB\] expected item:'
    $MonitorCount    = Get-MarkerCount '\[MON\] captured item:'
    $PassCount       = Get-MarkerCount '\[SB\] PASS:'
    if (($SequenceCount -ne $DriverCount) -or ($SequenceCount -ne $ExpectedWrCount)) {
        throw "Stimulus invariant broken: seq=$SequenceCount drv=$DriverCount exp=$ExpectedWrCount"
    }
    if ($MonitorCount -ne $PassCount) {
        throw "Observe invariant broken: mon=$MonitorCount pass=$PassCount"
    }
    if ($SequenceCount -ne ($ExpectedCaseCount * $NumBytes)) {
        throw "Expected $($ExpectedCaseCount * $NumBytes) items ($ExpectedCaseCount cases x $NumBytes bytes), found $SequenceCount"
    }
    if ($MonitorCount -ne ($SequenceCount - $ExpectedDropCount)) {
        throw "Expected $($SequenceCount - $ExpectedDropCount) observed items (reset drops $ExpectedDropCount), found $MonitorCount"
    }

    # 4-1) corner case: busy 중 valid 주입이 byte마다 1건씩 있어야 한다.
    #      주입이 무시됐다는 사실 자체는 위 불변식(추가 actual 없음)이 보증한다.
    $BusyInjectCount = Get-MarkerCount '\[DRV\] busy valid injected:'
    if ($BusyInjectCount -ne $NumBytes) {
        throw "Expected $NumBytes busy valid injections, found $BusyInjectCount"
    }

    # 4-2) reset case: 리셋 주입, monitor abort와 scoreboard drop이 각 1건씩이다.
    foreach ($Pair in @(
        @('\[TEST\] UART_TX_VERIF_RESET_INJECTED', 1),
        @('\[MON\] capture aborted by reset', 1),
        @('\[SB\] reset: dropped 1 in-flight expected', 1)
    )) {
        $Count = Get-MarkerCount $Pair[0]
        if ($Count -ne $Pair[1]) {
            throw "Expected $($Pair[1]) matches for $($Pair[0]), found $Count"
        }
    }

    # 5) case별 RESULT: fail은 0, pass 합은 전체 item 수와 같아야 한다.
    $ResultLines = @(Select-String -LiteralPath $SimLog -Pattern '\[SB\] RESULT: pass=(\d+) fail=(\d+)')
    if ($ResultLines.Count -ne $ExpectedCaseCount) {
        throw "Expected $ExpectedCaseCount scoreboard results, found $($ResultLines.Count)"
    }
    $PassSum = 0
    foreach ($Line in $ResultLines) {
        $CasePass = [int] $Line.Matches[0].Groups[1].Value
        $CaseFail = [int] $Line.Matches[0].Groups[2].Value
        if ($CaseFail -ne 0) {
            throw "Scoreboard reported failures: $($Line.Line)"
        }
        $PassSum += $CasePass
    }
    if ($PassSum -ne $MonitorCount) {
        throw "RESULT pass sum $PassSum does not match observed count $MonitorCount"
    }

    Write-Host "PASS: seed=$Seed num_bytes=$NumBytes items=$SequenceCount cases=$ExpectedCaseCount"
}
finally {
    Pop-Location
}
