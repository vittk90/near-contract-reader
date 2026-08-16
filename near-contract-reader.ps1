# near-contract-reader
#
# NEAR contracts ship no ABI: to call a method you have to know its argument names and
# types, and the only public record of them is what other people already sent. This script
# reads a contract's recent call history, groups it by method, and reconstructs each
# method's argument shape - names, inferred types, how often each key appears, and a real
# example payload you can copy.

param(
  [Parameter(Mandatory=$true)][string]$Contract,
  [int]$Pages = 2,
  [int]$PerPage = 25,
  [string]$Method = ""
)

$ErrorActionPreference = "Stop"
$api = "https://api.nearblocks.io/v1"
$out = Join-Path $PSScriptRoot ("contract-" + ($Contract -replace '[^a-z0-9]', '_') + ".json")

function TypeOf($v) {
  if ($null -eq $v) { return "null" }
  if ($v -is [bool]) { return "bool" }
  if ($v -is [array]) { return "array" }
  if ($v -is [pscustomobject]) { return "object" }
  if ($v -is [string]) {
    if ($v -match '^\d+$') {
      if ($v.Length -ge 20) { return "string(u128 amount)" }
      return "string(number)"
    }
    if ($v -match '^[a-z0-9._-]+\.(near|tg)$' -or $v -match '^[0-9a-f]{64}$') { return "string(account_id)" }
    return "string"
  }
  if ($v -is [int] -or $v -is [long] -or $v -is [double]) { return "number" }
  return "unknown"
}

Write-Host "Reading call history of $Contract ..." -ForegroundColor Cyan

$calls = @()
for ($p = 1; $p -le $Pages; $p++) {
  try {
    $r = Invoke-RestMethod -Uri "$api/account/$Contract/txns?per_page=$PerPage&page=$p" -TimeoutSec 45
  } catch {
    Write-Host "page $p failed: $($_.Exception.Message)" -ForegroundColor Yellow
    break
  }
  if (-not $r.txns) { break }
  foreach ($t in $r.txns) {
    if ($t.receiver_account_id -ne $Contract) { continue }
    foreach ($a in $t.actions) {
      if ($a.action -ne "FUNCTION_CALL") { continue }
      $calls += [pscustomobject]@{
        method  = $a.method
        args    = $a.args
        deposit = $a.deposit
        caller  = $t.predecessor_account_id
        tx      = $t.transaction_hash
      }
    }
  }
  Start-Sleep -Milliseconds 400
}

if ($calls.Count -eq 0) {
  Write-Host "No function calls found for $Contract - it may be a plain account, or the history is older than the pages scanned." -ForegroundColor Yellow
  return
}

if ($Method) { $calls = $calls | Where-Object { $_.method -eq $Method } }

$report = @()
$report += "NEAR CONTRACT READER - $Contract"
$report += "scanned $($calls.Count) function calls from the last $Pages page(s) of history"
$report += "=" * 70

$schema = @{}

foreach ($g in ($calls | Group-Object method | Sort-Object Count -Descending)) {
  $keys = @{}
  $sample = $null

  foreach ($c in $g.Group) {
    if (-not $c.args) { continue }
    try { $parsed = $c.args | ConvertFrom-Json } catch { continue }
    if (-not $parsed) { continue }
    if (-not $sample) { $sample = $c }
    foreach ($prop in $parsed.PSObject.Properties) {
      $t = TypeOf $prop.Value
      if (-not $keys.ContainsKey($prop.Name)) {
        $keys[$prop.Name] = [pscustomobject]@{ types = @($t); seen = 1 }
      } else {
        $keys[$prop.Name].seen++
        if ($keys[$prop.Name].types -notcontains $t) { $keys[$prop.Name].types += $t }
      }
    }
  }

  # @(...) matters: a single match would otherwise have no usable .Count
  $withArgs = @($g.Group | Where-Object { $_.args }).Count
  $report += ""
  $report += "method: $($g.Name)   [$($g.Count) calls]"

  if ($keys.Count -eq 0) {
    $report += "  arguments: none (called with empty args)"
  } else {
    $report += "  arguments:"
    foreach ($k in ($keys.Keys | Sort-Object)) {
      $info = $keys[$k]
      $req = if ($withArgs -le 1) {
        "seen once"                       # a single call proves nothing about optionality
      } elseif ($info.seen -eq $withArgs) {
        "always present"
      } else {
        "optional ($($info.seen)/$withArgs)"
      }
      $report += ("    {0,-22} {1,-24} {2}" -f $k, ($info.types -join " | "), $req)
    }
  }

  if ($sample) {
    $report += "  example: $($sample.args)"
    $report += "  seen in: $($sample.tx)"
  }

  $schema[$g.Name] = [pscustomobject]@{
    calls     = $g.Count
    arguments = $keys
    example   = if ($sample) { $sample.args } else { $null }
    exampleTx = if ($sample) { $sample.tx } else { $null }
  }
}

$report += ""
$report += "=" * 70
$report += "Schema saved to: $out"

$text = $report -join "`r`n"
Write-Host $text

try {
  $json = [pscustomobject]@{
    contract  = $Contract
    scannedAt = (Get-Date).ToString("s")
    callCount = $calls.Count
    methods   = $schema
  } | ConvertTo-Json -Depth 8
  [IO.File]::WriteAllText($out, $json)
} catch {
  Write-Host ("could not write schema file: " + $_.Exception.Message) -ForegroundColor Yellow
}

exit 0
