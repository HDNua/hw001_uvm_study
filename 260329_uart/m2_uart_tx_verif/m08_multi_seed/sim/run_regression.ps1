param(
    [string] $VivadoBin = "",
    [int[]] $Seeds = @(1, 7, 42, 1234, 20260719),
    [int] $NumBytes = 8,
    [double] $CovMin = 70.0,
    [double] $DataCovMin = 85.0
)

$ErrorActionPreference = "Stop"

$SimDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunScript  = Join-Path $SimDir "run_xsim.ps1"
$OutDir     = Join-Path $SimDir "out"
$RegressDir = Join-Path $OutDir "regress"
$SimLog     = Join-Path $OutDir "sim_xsim.log"

if ($Seeds.Count -lt 1) {
    throw "At least one seed is required"
}

New-Item -ItemType Directory -Force -Path $RegressDir | Out-Null

# 같은 검증을 여러 seed로 반복해 한 seed의 운으로 통과하는
# 자극 구멍을 줄인다. seed별 로그는 out/regress/에 남긴다.
$Results = @()
foreach ($Seed in $Seeds) {
    $Ok     = $true
    $Detail = ""
    try {
        & $RunScript -VivadoBin $VivadoBin -Seed $Seed -NumBytes $NumBytes -CovMin $CovMin -DataCovMin $DataCovMin | Out-Null
    } catch {
        $Ok     = $false
        $Detail = $_.Exception.Message
    }

    $Coverage = 0.0
    if (Test-Path -LiteralPath $SimLog) {
        $CovMatch = [regex]::Match((Get-Content -LiteralPath $SimLog -Raw), 'UART_TX_VERIF_COVERAGE .*total=([\d\.]+)%')
        if ($CovMatch.Success) {
            $Coverage = [double] $CovMatch.Groups[1].Value
        }
        Copy-Item -LiteralPath $SimLog -Destination (Join-Path $RegressDir "sim_seed_$Seed.log") -Force
    }

    $Results += [pscustomobject]@{ Seed = $Seed; Pass = $Ok; Coverage = $Coverage; Detail = $Detail }
    Write-Host ("seed={0,-10} pass={1,-5} coverage={2}%" -f $Seed, $Ok, $Coverage)
}

$FailCount  = @($Results | Where-Object { -not $_.Pass }).Count
$CovValues  = $Results | ForEach-Object { $_.Coverage }
$CovMinSeen = ($CovValues | Measure-Object -Minimum).Minimum
$CovMaxSeen = ($CovValues | Measure-Object -Maximum).Maximum

Write-Host "REGRESSION: runs=$($Results.Count) fail=$FailCount cov_min=$CovMinSeen% cov_max=$CovMaxSeen%"

if ($FailCount -ne 0) {
    $Results | Where-Object { -not $_.Pass } | ForEach-Object {
        Write-Host "FAILED seed=$($_.Seed): $($_.Detail)"
    }
    throw "Regression failed: $FailCount of $($Results.Count) runs"
}

Write-Host "REGRESSION PASS: all $($Results.Count) seeds passed"
