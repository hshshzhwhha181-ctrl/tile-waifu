<#
.SYNOPSIS
    DEPRECATED shim. The QA runner is now tools/tw_test.py (cross-platform, parallel, baseline-aware).
.DESCRIPTION
    Forwards the common switches to python tools/tw_test.py:
      -Import            -> --import
      -CleanImport       -> --clean-import
      -Tests <list|all>  -> -s <list>      (-Fast -> --fast)
      -ListTests         -> --list
      -Shot <screen> -Out <png> [-Res WxH] [-At sec] [-Act name] -> --shot ...
    Set $env:GODOT_BIN or pass -GodotBin.
#>
[CmdletBinding()]
param(
    [switch]$Import, [string]$Tests = "", [string]$Shot = "", [string]$Out = "", [string]$Res = "450x1000",
    [double]$At = 2.0, [string]$Act = "", [switch]$CleanImport, [switch]$Fast, [int]$TimeoutSec = 300,
    [string]$GodotBin = "", [string]$GameDir = "", [switch]$ListTests
)
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$py = Join-Path $repo "tools\tw_test.py"
$a = @($py)
if ($GodotBin -ne "") { $a += @("--godot", $GodotBin) }
if ($Import) { $a += "--import" }
if ($CleanImport) { $a += "--clean-import" }
if ($ListTests) { $a += "--list" }
if ($Tests -ne "") { $a += @("-s", $Tests); if ($Fast) { $a += "--fast" } }
if ($Shot -ne "") { $a += @("--shot", $Shot, "--out", $Out, "--res", $Res, "--at", $At); if ($Act -ne "") { $a += @("--act", $Act) } }
Write-Host "[godot_qa] deprecated: forwarding to python tools/tw_test.py $($a[1..($a.Count-1)] -join ' ')"
& python @a
exit $LASTEXITCODE
