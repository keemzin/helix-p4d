#requires -Version 5.1
<#
    PERFORCE HELIX CORE LOAD TEST  (P4D on port 1666)
    --------------------------------------------------
    Runs N concurrent background jobs ("clients"), each doing OpsPerClient
    mixed read / write / sync operations against the P4D.

    Measures from the CLIENT side:
      * Throughput       -> operations / second
      * Latency          -> p50 / p95 / p99 round-trip time per command type
      * Error rate       -> P4Y (deadlock), lock, protocol errors

    Does NOT measure (watch the SERVER separately):
      * P4D CPU / RAM usage

    Usage:
      .\p4-loadtest.ps1                       # defaults below
      .\p4-loadtest.ps1 -Clients 8 -Ops 300
    #>

param(
    [string]$Server = "localhost",
    [int]    $Port  = 1666,
    [int]    $Clients     = 5,
    [int]    $OpsPerClient = 500
)

$startTick = [DateTime]::Now.Ticks
$Host.UI.RawUI.WindowTitle = "Perforce Load Test"
Write-Host "Perforce Helix Core Load Test" -ForegroundColor Cyan
Write-Host ("  Server : {0}:{1}" -f $Server, $Port)
Write-Host ("  Clients: {0}" -f $Clients)
Write-Host ("  Ops   : {0} per client x 3 phases" -f $OpsPerClient)
Write-Host ""

$spec = "-G p4lt-lt"
$hdr  = "-H {0}:{1} {2}" -f $Server, $Port, $spec

function Invoke-Op([int]$phase) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $err = $null
    try {
        switch ($phase) {
            1 { p4 $hdr file //depot/public/hello.txt 2>&1 | Out-Null }
            2 { p4 $hdr changelist -c $((Get-Random -Max 50000)) -m "loadtest" 2>&1 | Out-Null }
            3 { p4 $hdr sync //depot/public/... 2>&1 | Out-Null }
        }
    } catch { $err = $_.Exception.Message } finally { $sw.Stop() }
    [PSCustomObject]@{ Phase=$phase; Ms=[math]::Round($sw.Elapsed.TotalMilliseconds,1); Err=$err }
}

Write-Host "Starting load..." -ForegroundColor Yellow
foreach ($job in 1..$Clients) {
    Write-Host ("Client {0}: {1} ops" -f $job, ($OpsPerClient*3))
    1..($OpsPerClient*3) | ForEach-Object { $results += Invoke-Op -phase ((Get-Random -Max 3)+1) }
}

Write-Host ""
Write-Host "==== RESULTS (client-side) ====" -ForegroundColor Cyan

# ---- Latency percentiles (clean) ----
function Get-Pctl($arr, [double]$pct) {
    $s = $arr | Sort-Object
    $n = $s.Count
    if ($n -eq 0) { return $null }
    $idx = [math]::Floor(($pct/100)*($n-1))
    return $s[$idx]
}

$phases = 1,2,3
foreach ($p in $phases) {
    $times = ($results | Where-Object { $_.Phase -eq $p } | Select-Object -ExpandProperty Ms)
    if (-not $times) { continue }
    $avg  = ($times | Measure-Object -Property Average -Property Sum) / $times.Count
    $p50  = Get-Pctl $times 50
    $p95  = Get-Pctl $times 95
    $p99  = Get-Pctl $times 99
    Write-Host ("  Phase {0}: {1,4} ops | avg {2,6} ms | p95 {3,6} ms | p99 {4,6} ms" -f `
        $p, $times.Count, $avg, $p95, $p99)
}

# ---- Errors + throughput ----
$errs    = ($results | Where-Object { $_.Err } | Measure-Object).Count
$c1 = ($results | Where-Object { $_.Phase -eq 1 }).Count
$c2 = ($results | Where-Object { $_.Phase -eq 2 }).Count
$c3 = ($results | Where-Object { $_.Phase -eq 3 }).Count
$total  = $c1 + $c2 + $c3
$wallMs = [DateTime]::Now.Ticks - $startTick

Write-Host ""
Write-Host ("  Total operations : {0}" -f $total)
Write-Host ("  Errors           : {0}" -f $errs)
Write-Host ("  Read/Write/Sync  : {0}/{1}/{2}" -f $c1,$c2,$c3)
Write-Host ("  Wall time        : {0:F1} s" -f ($wallMs/1000))
Write-Host ("  Throughput       : {0:N1} ops/s" -f ($total/($wallMs/1000)))
Write-Host ("  NOTE: P4D CPU/RAM -> monitor {0} during the run" -f $Server)
