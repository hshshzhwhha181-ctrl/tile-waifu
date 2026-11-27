<#
.SYNOPSIS
    PowerShell 5.1-safe 1-command Godot 4.5.1 QA runner for Tile Waifu.
.DESCRIPTION
    Supports:
      -Import        Isolated temp APPDATA Godot --headless --audio-driver Dummy --path game --import
      -Tests <list>  Comma-separated selftests (or "core", "v10", "all") with summary table + exit code
      -Shot <screen> Captures UI screenshot (-Out <png_path> -Res "450x1000" -At 2.0)
      -CleanImport   Restores tracked *.import churn via git checkout without deleting untracked .import files
#>
[CmdletBinding()]
param(
    [switch]$Import,
    [string]$Tests = "",
    [string]$Shot = "",
    [string]$Out = "",
    [string]$Res = "450x1000",
    [double]$At = 2.0,
    [string]$Act = "",
    [switch]$CleanImport,
    [switch]$Fast,
    [int]$TimeoutSec = 300,
    [string]$GodotBin = "",
    [string]$GameDir = "",
    [switch]$ListTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve repository and game paths relative to .agents/skills/tw-godot-qa/scripts
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
if ([string]::IsNullOrWhiteSpace($GameDir)) {
    $GameDir = Join-Path $RepoRoot "game"
} elseif (-not [System.IO.Path]::IsPathRooted($GameDir)) {
    $GameDir = Join-Path (Get-Location).Path $GameDir
}
$GameDir = [System.IO.Path]::GetFullPath($GameDir)

function Resolve-GodotExecutable {
    param([string]$ExplicitPath)
    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $candidates.Add($ExplicitPath)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $candidates.Add($env:GODOT_BIN)
    }
    $scratchParent = Split-Path -Parent $RepoRoot
    $candidates.Add((Join-Path $scratchParent "tw-tools\godot\Godot_v4.5.1-stable_win64_console.exe"))
    $candidates.Add((Join-Path $scratchParent "tw-tools\godot\Godot_v4.5.1-stable_win64.exe"))
    $candidates.Add("C:\Users\ADMIN\.gemini\antigravity\scratch\tw-tools\godot\Godot_v4.5.1-stable_win64_console.exe")
    $candidates.Add("C:\Users\ADMIN\.gemini\antigravity\scratch\tw-tools\godot\Godot_v4.5.1-stable_win64.exe")

    foreach ($cand in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($cand) -and (Test-Path -LiteralPath $cand)) {
            return (Resolve-Path -LiteralPath $cand).Path
        }
    }
    $onPath = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $onPath) {
        return $onPath.Source
    }
    throw "Godot 4.5.1 executable not found. Set -GodotBin or `$env:GODOT_BIN."
}

function Format-Arg {
    param([string]$Value)
    if ($null -eq $Value) { return '""' }
    if ($Value -match '[\s"]') {
        $escaped = $Value.Replace('"', '\"')
        return '"' + $escaped + '"'
    }
    return $Value
}

function Invoke-GodotIsolated {
    param(
        [string]$Exe,
        [string[]]$Arguments,
        [int]$LimitSec
    )
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tw_godot_qa_" + $PID + "_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    $appRoaming = Join-Path $tempRoot "Roaming"
    $appLocal = Join-Path $tempRoot "Local"
    $outLog = Join-Path $tempRoot "stdout.log"
    $errLog = Join-Path $tempRoot "stderr.log"

    New-Item -ItemType Directory -Path (Join-Path $appRoaming "Godot") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $appLocal "Godot") -Force | Out-Null

    $prevAppData = $env:APPDATA
    $prevLocalAppData = $env:LOCALAPPDATA
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $env:APPDATA = $appRoaming
        $env:LOCALAPPDATA = $appLocal

        $quotedArgs = New-Object System.Collections.Generic.List[string]
        foreach ($a in $Arguments) {
            $quotedArgs.Add((Format-Arg $a))
        }
        $argLine = [string]::Join(" ", $quotedArgs)

        $proc = Start-Process -FilePath $Exe -ArgumentList $argLine -NoNewWindow -PassThru `
            -RedirectStandardOutput $outLog -RedirectStandardError $errLog

        $finished = $proc.WaitForExit($LimitSec * 1000)
        $timedOut = $false
        if (-not $finished) {
            $timedOut = $true
            try { $proc.Kill() } catch {}
            $proc.WaitForExit(3000) | Out-Null
        } else {
            # Ensure async stream buffers flush on PS 5.1
            $proc.WaitForExit()
        }
        $sw.Stop()

        $stdoutText = ""
        $stderrText = ""
        if (Test-Path -LiteralPath $outLog) {
            $stdoutText = [System.IO.File]::ReadAllText($outLog, [System.Text.Encoding]::UTF8)
        }
        if (Test-Path -LiteralPath $errLog) {
            $stderrText = [System.IO.File]::ReadAllText($errLog, [System.Text.Encoding]::UTF8)
        }
        $combined = ($stdoutText + "`n" + $stderrText).Trim()
        $exitCode = if ($timedOut) { 124 } else { [int]$proc.ExitCode }

        return [PSCustomObject]@{
            ExitCode = $exitCode
            TimedOut = $timedOut
            Duration = [Math]::Round($sw.Elapsed.TotalSeconds, 2)
            Output   = $combined
        }
    } finally {
        $env:APPDATA = $prevAppData
        $env:LOCALAPPDATA = $prevLocalAppData
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-TestCatalog {
    # Ordered list of core + v10 selftests matching main.gd, g.gd, event.gd, and V10RegistryList
    return @(
        @{ Id="contract";     Aliases=@("contract_selftest");    Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--contract_selftest=1"); FastArgs=@("--contract_selftest=1"); Marker="CONTRACT_SELFTEST" },
        @{ Id="selftest";     Aliases=@("board_selftest");       Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--selftest=1");          FastArgs=@("--selftest=1");          Marker="SELFTEST" },
        @{ Id="event";        Aliases=@("event_selftest");       Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--event_selftest=1");    FastArgs=@("--event_selftest=1");    Marker="EVENT SELFTEST" },
        @{ Id="league";       Aliases=@("league_selftest");      Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--league_selftest=1");   FastArgs=@("--league_selftest=1");   Marker="LEAGUE" },
        @{ Id="profile";      Aliases=@("profile_selftest");     Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--profile_selftest=1");  FastArgs=@("--profile_selftest=1");  Marker="PROFILE" },
        @{ Id="recovery";     Aliases=@("recovery_selftest");    Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--recovery_selftest=1"); FastArgs=@("--recovery_selftest=1"); Marker="RECOVERY" },
        @{ Id="ults";         Aliases=@("ults_selftest");        Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--ults_selftest=1");     FastArgs=@("--ults_selftest=1");     Marker="ULTS" },
        @{ Id="letters";      Aliases=@("letters_selftest");     Group="core"; Scene=""; Script=""; Render=$false; Res=""; Args=@("--letters_selftest=1");  FastArgs=@("--letters_selftest=1");  Marker="LETTERS" },

        @{ Id="responsive";   Aliases=@("layout","layout_selftest");   Group="v10"; Scene="";                                                Script=""; Render=$true;  Res="1536x2048"; Args=@("--layout_selftest=1","--save=user://layout_shots_save.json","--save_wipe=1"); FastArgs=@("--layout_selftest=1","--save=user://layout_shots_save.json","--save_wipe=1"); Marker="LAYOUT_SELFTEST" },
        @{ Id="economy";      Aliases=@("econ","econ_selftest");       Group="v10"; Scene="res://scripts/v10/economy/econ_selftest.tscn";    Script=""; Render=$false; Res="";          Args=@("--econ_selftest=1");    FastArgs=@("--econ_selftest=1","--econ_mc=0.1"); Marker="ECON_SELFTEST" },
        @{ Id="stamina";      Aliases=@("stamina_selftest");           Group="v10"; Scene="res://scripts/v10/economy/stamina_selftest.tscn"; Script=""; Render=$false; Res="";          Args=@("--stamina_selftest=1"); FastArgs=@("--stamina_selftest=1");              Marker="STAMINA_SELFTEST" },
        @{ Id="meta";         Aliases=@("meta_selftest");              Group="v10"; Scene="res://scripts/v10/meta/meta_runner.tscn";         Script=""; Render=$false; Res="";          Args=@("--meta_selftest=1","--save=user://meta_runner.json","--save_wipe=1"); FastArgs=@("--meta_selftest=1","--save=user://meta_runner.json","--save_wipe=1"); Marker="META_SELFTEST" },
        @{ Id="hud2";         Aliases=@("hud2_selftest");              Group="v10"; Scene="res://scripts/v10/hud2/hud2_demo.tscn";           Script=""; Render=$false; Res="";          Args=@("--hud2_selftest=1");    FastArgs=@("--hud2_selftest=1");                 Marker="HUD2 SELFTEST" },
        @{ Id="fonts";        Aliases=@("fonts_selftest");             Group="v10"; Scene="res://scripts/v10/fonts/fonts_runner.tscn";       Script=""; Render=$false; Res="";          Args=@("--fonts_selftest=1");   FastArgs=@("--fonts_selftest=1");                Marker="FONTS SELFTEST" },
        @{ Id="profile2";     Aliases=@("profile2_selftest");          Group="v10"; Scene="res://scripts/v10/profile/profile2_selftest.tscn";Script=""; Render=$false; Res="";          Args=@("--profile2_selftest=1");FastArgs=@("--profile2_selftest=1");             Marker="PROFILE2_SELFTEST" },
        @{ Id="look";         Aliases=@("look_selftest");              Group="v10"; Scene="res://scripts/v10/look/look_runner.tscn";         Script=""; Render=$false; Res="";          Args=@("--look_selftest=1");    FastArgs=@("--look_selftest=1");                 Marker="LOOK_SELFTEST" },
        @{ Id="shop";         Aliases=@("shop_selftest");              Group="v10"; Scene="res://scripts/v10/shop/shop_demo.tscn";           Script=""; Render=$false; Res="";          Args=@("--shop_selftest=1");    FastArgs=@("--shop_selftest=1");                 Marker="SHOP_SELFTEST" },
        @{ Id="auth";         Aliases=@("auth_selftest");              Group="v10"; Scene="res://scripts/v10/auth/auth_dev.tscn";            Script=""; Render=$false; Res="";          Args=@("--auth_selftest=1","--save=user://auth_selftest_save.json","--save_wipe=1"); FastArgs=@("--auth_selftest=1","--save=user://auth_selftest_save.json","--save_wipe=1"); Marker="AUTH_SELFTEST" },
        @{ Id="clarity";      Aliases=@("clarity_selftest");           Group="v10"; Scene="res://scripts/v10/clarity/clarity_selftest.tscn"; Script=""; Render=$false; Res="";          Args=@();                       FastArgs=@();                                    Marker="V10 CLARITY SELFTEST" },
        @{ Id="tutorial";     Aliases=@("tut","tut_selftest");         Group="v10"; Scene="res://scripts/v10/tutorial/tut_selftest.tscn";    Script=""; Render=$false; Res="";          Args=@("--save=user://tut_test.json","--save_wipe=1","--tut_static=1"); FastArgs=@("--save=user://tut_test.json","--save_wipe=1","--tut_static=1"); Marker="V10TUT" },
        @{ Id="juice";        Aliases=@("juice_selftest");             Group="v10"; Scene="res://scripts/v10/juice/demo/juice_demo.tscn";    Script=""; Render=$false; Res="";          Args=@("--juice_selftest=1");   FastArgs=@("--juice_selftest=1");                Marker="JUICE SELFTEST" },
        @{ Id="levels";       Aliases=@("levels_selftest");            Group="v10"; Scene="res://scripts/v10/levels/levels_selftest.tscn";   Script=""; Render=$false; Res="";          Args=@("--levels_selftest=1");  FastArgs=@("--levels_selftest=1","--levels_n=200"); Marker="LEVELS SELFTEST" },
        @{ Id="path";         Aliases=@("path_selftest");              Group="v10"; Scene="res://scripts/v10/path/path_demo.tscn";           Script=""; Render=$false; Res="";          Args=@("--path_selftest=1");    FastArgs=@("--path_selftest=1");                 Marker="PATH SELFTEST" },
        @{ Id="salon";        Aliases=@("salon_selftest");             Group="v10"; Scene="res://scripts/v10/salon/salon_runner.tscn";       Script=""; Render=$false; Res="";          Args=@("--salon_selftest=1");   FastArgs=@("--salon_selftest=1");                Marker="SALON_SELFTEST" },
        @{ Id="rituals";      Aliases=@("rit","rit_selftest","rituals_selftest"); Group="v10"; Scene="res://scripts/v10/rituals/rituals_runner.tscn"; Script=""; Render=$false; Res="";  Args=@("--rit=selftest","--save=user://rit_runner.json","--save_wipe=1"); FastArgs=@("--rit=selftest","--save=user://rit_runner.json","--save_wipe=1"); Marker="RIT_SELFTEST" },
        @{ Id="chat";         Aliases=@("chat_selftest");              Group="v10"; Scene="";                                                Script="res://scripts/v10/chat/chat_selftest_cli.gd"; Render=$false; Res=""; Args=@(); FastArgs=@(); Marker="CHAT SELFTEST" },
        @{ Id="phone";        Aliases=@("phone_selftest");             Group="v10"; Scene="res://scripts/v10/phone/phone_runner.tscn";       Script=""; Render=$true;  Res="720x1280";  Args=@("--save=user://phone_st.json","--save_wipe=1","--phone_selftest=1"); FastArgs=@("--save=user://phone_st.json","--save_wipe=1","--phone_selftest=1"); Marker="PHONE SELFTEST" },
        @{ Id="gacha";        Aliases=@("gacha_selftest");             Group="v10"; Scene="res://scripts/v10/gacha/gacha_demo.tscn";         Script=""; Render=$false; Res="";          Args=@("--gacha_selftest=1");   FastArgs=@("--gacha_selftest=1","--mc=0.5");     Marker="GACHA_SELFTEST" },
        @{ Id="rig";          Aliases=@("rig_selftest");               Group="v10"; Scene="res://scripts/v10/rig/rig_selftest.tscn";         Script=""; Render=$false; Res="";          Args=@();                       FastArgs=@();                                    Marker="RIG_SELFTEST" },
        @{ Id="voice";        Aliases=@("v10_voice","v10_voice_selftest","voice_selftest"); Group="v10"; Scene="res://scripts/v10/voice/v10_voice_selftest.tscn"; Script=""; Render=$false; Res=""; Args=@(); FastArgs=@(); Marker="V10VOICE OK" },
        @{ Id="audio";        Aliases=@("v10_audio","v10_audio_selftest","audio_selftest"); Group="v10"; Scene="res://scripts/v10/audio/v10_audio_selftest.tscn"; Script=""; Render=$false; Res=""; Args=@(); FastArgs=@(); Marker="V10AUDIO" },
        @{ Id="hudfx";        Aliases=@("hudfx_selftest");             Group="v10"; Scene="res://scripts/v10/hudfx/hudfx_selftest.tscn";     Script=""; Render=$false; Res="";          Args=@("--hudfx_selftest=1");   FastArgs=@("--hudfx_selftest=1");                Marker="HUDFX SELFTEST" },
        @{ Id="tower";        Aliases=@("tower_selftest");             Group="v10"; Scene="res://scripts/v10/tower/tower_selftest.tscn";     Script=""; Render=$false; Res="";          Args=@("--tower_selftest=1");   FastArgs=@("--mods_selftest=1","--pagoda_selftest=1","--journey_selftest=1","--tower_tables=1","--tower_rules=1","--tower_hygiene=1"); Marker="TOWER_SELFTEST" },
        @{ Id="mj_stage";     Aliases=@("stage_selftest","mj_stage_selftest");     Group="v10"; Scene="res://scripts/v10/mj/stage/stage_selftest.tscn";     Script=""; Render=$false; Res="";         Args=@("--mj_stage_selftest=1");   FastArgs=@("--mj_stage_selftest=1");               Marker="MJ_STAGE" },
        @{ Id="mj_look";      Aliases=@("mj_look_selftest");                       Group="v10"; Scene="res://scripts/v10/mj/look/look_selftest.tscn";       Script=""; Render=$true;  Res="720x1280"; Args=@("--mj_look_selftest=1");    FastArgs=@("--mj_look_selftest=1");                Marker="MJ_LOOK" },
        @{ Id="mj_triples";   Aliases=@("triples","triples_selftest","mj_triples_selftest"); Group="v10"; Scene="res://scripts/v10/mj/triples/triples_selftest.tscn"; Script=""; Render=$false; Res=""; Args=@("--mj_triples_selftest=1"); FastArgs=@("--mj_triples_selftest=1"); Marker="MJ_TRIPLES" },
        @{ Id="mj_riichi";    Aliases=@("riichi","riichi_selftest","mj_riichi_selftest");    Group="v10"; Scene="res://scripts/v10/mj/riichi/riichi_selftest.tscn";   Script=""; Render=$false; Res=""; Args=@("--mj_riichi_selftest=1");  FastArgs=@("--mj_riichi_selftest=1","--games=20"); Marker="MJ_RIICHI" },
        @{ Id="mj_sanma";     Aliases=@("sanma","sanma_selftest","mj_sanma_selftest");       Group="v10"; Scene="res://scripts/v10/mj/sanma/sanma_selftest.tscn";     Script=""; Render=$false; Res=""; Args=@("--mj_sanma_selftest=1");   FastArgs=@("--mj_sanma_selftest=1","--games=20");  Marker="MJ_SANMA" },
        @{ Id="mj_koikoi";    Aliases=@("koikoi","koikoi_selftest","mj_koikoi_selftest");    Group="v10"; Scene="res://scripts/v10/mj/koikoi/koikoi_selftest.tscn";   Script=""; Render=$false; Res=""; Args=@("--mj_koikoi_selftest=1");  FastArgs=@("--mj_koikoi_selftest=1","--games=100");Marker="MJ_KOIKOI" },
        @{ Id="mj_classic";   Aliases=@("classic","classic_selftest","mj_classic_selftest"); Group="v10"; Scene="res://scripts/v10/mj/classic/classic_selftest.tscn"; Script=""; Render=$false; Res=""; Args=@("--mj_classic_selftest=1"); FastArgs=@("--mj_classic_selftest=1");             Marker="MJ_CLASSIC" },
        @{ Id="mj_connect";   Aliases=@("connect","connect_selftest","mj_connect_selftest"); Group="v10"; Scene="res://scripts/v10/mj/connect/connect_selftest.tscn"; Script=""; Render=$false; Res=""; Args=@("--mj_connect_selftest=1"); FastArgs=@("--mj_connect_selftest=1");             Marker="MJ_CONNECT" },
        @{ Id="mj_cube";      Aliases=@("cube","cube_selftest","mj_cube_selftest");          Group="v10"; Scene="res://scripts/v10/mj/cube/cube_selftest.tscn";       Script=""; Render=$false; Res=""; Args=@("--mj_cube_selftest=1");    FastArgs=@("--mj_cube_selftest=1");                Marker="MJ_CUBE" },
        @{ Id="mj_garden";    Aliases=@("garden","garden_selftest","mj_garden_selftest");    Group="v10"; Scene="res://scripts/v10/mj/garden/garden_selftest.tscn";   Script=""; Render=$false; Res=""; Args=@("--mj_garden_selftest=1");  FastArgs=@("--mj_garden_selftest=1");              Marker="MJ_GARDEN" },
        @{ Id="mj_bridge";    Aliases=@("bridge","bridge_selftest","mj_bridge_selftest");    Group="v10"; Scene="res://scripts/v10/mj/bridge/bridge_selftest.tscn";   Script=""; Render=$false; Res=""; Args=@("--mj_bridge_selftest=1");  FastArgs=@("--mj_bridge_selftest=1");              Marker="MJ_BRIDGE" },
        @{ Id="palm";         Aliases=@("hand","hand_selftest","palm_selftest");             Group="v10"; Scene="res://scripts/v10/palm/hand_selftest.tscn";          Script=""; Render=$false; Res=""; Args=@("--hand_selftest=1");       FastArgs=@("--hand_selftest=1","--hand_real=24");  Marker="HAND_SELFTEST" },
        @{ Id="duels";        Aliases=@("duel","duel_selftest","duels_selftest");            Group="v10"; Scene="res://scripts/v10/duels/duel_selftest.tscn";         Script=""; Render=$false; Res=""; Args=@("--duel_selftest=1","--save=user://duel_selftest.json","--save_wipe=1"); FastArgs=@("--duel_selftest=1","--save=user://duel_selftest.json","--save_wipe=1"); Marker="DUEL_SELFTEST" },
        @{ Id="challenge";    Aliases=@("challenge_selftest");                               Group="v10"; Scene="res://scripts/v10/duels/challenge/challenge_selftest.tscn"; Script=""; Render=$false; Res=""; Args=@("--challenge_selftest=1","--save=user://ch_selftest.json","--save_wipe=1"); FastArgs=@("--challenge_selftest=1","--save=user://ch_selftest.json","--save_wipe=1"); Marker="CHALLENGE_SELFTEST" },
        @{ Id="wave1";        Aliases=@("wave1_selftest");                                   Group="v10"; Scene="res://scripts/v10/wave1/wave1_selftest.tscn";        Script=""; Render=$false; Res=""; Args=@("--wave1_selftest=1");      FastArgs=@("--wave1_selftest=1");                  Marker="WAVE1_SELFTEST" },
        @{ Id="adventure";    Aliases=@("adventure_selftest");                               Group="v10"; Scene="res://scripts/v10/adventure/adventure_selftest.tscn";Script=""; Render=$false; Res=""; Args=@("--adventure_selftest=1");  FastArgs=@("--adventure_selftest=1");              Marker="ADVENTURE_SELFTEST" },
        @{ Id="online";       Aliases=@("online_selftest");                                  Group="v10"; Scene="res://scripts/v10/online/online_selftest.tscn";      Script=""; Render=$false; Res=""; Args=@();                          FastArgs=@();                                      Marker="ONLINE_SELFTEST" },
        @{ Id="events";       Aliases=@("events_selftest");                                  Group="v10"; Scene="res://scripts/v10/events/events_selftest.tscn";      Script=""; Render=$false; Res=""; Args=@();                          FastArgs=@();                                      Marker="EVENTS_SELFTEST" }
    )
}

function Resolve-TestSpecs {
    param([string]$RawList)
    $catalog = Get-TestCatalog
    $byKey = @{}
    foreach ($entry in $catalog) {
        $byKey[$entry.Id.ToLowerInvariant()] = $entry
        foreach ($al in $entry.Aliases) {
            $byKey[$al.ToLowerInvariant()] = $entry
        }
    }

    $selected = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $tokens = $RawList.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach ($tok in $tokens) {
        $clean = $tok.Trim()
        if ($clean.StartsWith("--")) { $clean = $clean.Substring(2) }
        if ($clean.Contains("=")) { $clean = $clean.Split("=")[0] }
        $key = $clean.ToLowerInvariant()

        if ($key -eq "all") {
            foreach ($entry in $catalog) {
                if (-not $seen.ContainsKey($entry.Id)) {
                    $seen[$entry.Id] = $true
                    $selected.Add($entry)
                }
            }
            continue
        }
        if ($key -eq "core") {
            foreach ($entry in $catalog) {
                if ($entry.Group -eq "core" -and -not $seen.ContainsKey($entry.Id)) {
                    $seen[$entry.Id] = $true
                    $selected.Add($entry)
                }
            }
            continue
        }
        if ($key -eq "v10") {
            foreach ($entry in $catalog) {
                if ($entry.Group -eq "v10" -and -not $seen.ContainsKey($entry.Id)) {
                    $seen[$entry.Id] = $true
                    $selected.Add($entry)
                }
            }
            continue
        }
        if ($byKey.ContainsKey($key)) {
            $entry = $byKey[$key]
            if (-not $seen.ContainsKey($entry.Id)) {
                $seen[$entry.Id] = $true
                $selected.Add($entry)
            }
            continue
        }

        # Fallback: pass raw --<name>=1 flag to main scene
        $flagName = if ($key.EndsWith("_selftest")) { $key } else { $key + "_selftest" }
        if (-not $seen.ContainsKey($flagName)) {
            $seen[$flagName] = $true
            $selected.Add(@{
                Id       = $flagName
                Aliases  = @()
                Group    = "custom"
                Scene    = ""
                Script   = ""
                Render   = $false
                Res      = ""
                Args     = @("--" + $flagName + "=1")
                FastArgs = @("--" + $flagName + "=1")
                Marker   = "SELFTEST"
            })
        }
    }
    return $selected
}

if ($ListTests) {
    $cat = Get-TestCatalog
    Write-Host ("{0,-14} {1,-6} {2,-22} {3}" -f "ID", "GROUP", "MARKER", "SCENE / TARGET")
    Write-Host ("-" * 88)
    foreach ($c in $cat) {
        $target = if ($c.Script -ne "") { "-s " + $c.Script } elseif ($c.Scene -ne "") { $c.Scene } else { "(main.tscn)" }
        Write-Host ("{0,-14} {1,-6} {2,-22} {3}" -f $c.Id, $c.Group, $c.Marker, $target)
    }
    exit 0
}

if (-not $Import -and [string]::IsNullOrWhiteSpace($Tests) -and [string]::IsNullOrWhiteSpace($Shot) -and -not $CleanImport) {
    Write-Host "Usage: godot_qa.ps1 [-Import] [-Tests <comma-list|core|v10|all> [-Fast]] [-Shot <screen> -Out <png> [-Res 450x1000]] [-CleanImport] [-ListTests]"
    exit 1
}

$overallExit = 0

# 1. Import step
if ($Import) {
    $godotExe = Resolve-GodotExecutable -ExplicitPath $GodotBin
    Write-Host "[godot_qa] Running headless --import in isolated APPDATA..."
    $resImport = Invoke-GodotIsolated -Exe $godotExe -Arguments @("--headless", "--audio-driver", "Dummy", "--path", $GameDir, "--import") -LimitSec $TimeoutSec
    $importOk = ($resImport.ExitCode -eq 0) -or ($resImport.ExitCode -eq -1073741819 -and $resImport.Output -notmatch "SCRIPT ERROR:")
    if ($importOk -and -not $resImport.TimedOut) {
        Write-Host ("[godot_qa] Import OK ({0}s, rc={1})" -f $resImport.Duration, $resImport.ExitCode)
    } else {
        Write-Host ("[godot_qa] Import FAILED ({0}s, rc={1})" -f $resImport.Duration, $resImport.ExitCode) -ForegroundColor Red
        if (-not [string]::IsNullOrWhiteSpace($resImport.Output)) {
            Write-Host $resImport.Output
        }
        $overallExit = 1
    }
}

# 2. Selftests step
if (-not [string]::IsNullOrWhiteSpace($Tests)) {
    $godotExe = Resolve-GodotExecutable -ExplicitPath $GodotBin
    $specs = @(Resolve-TestSpecs -RawList $Tests)
    $specsCount = [int]($specs | Measure-Object).Count
    $results = New-Object System.Collections.Generic.List[object]

    Write-Host ("[godot_qa] Running {0} selftest(s) against {1}..." -f $specsCount, (Split-Path -Leaf $godotExe))

    foreach ($sp in $specs) {
        $gArgs = New-Object System.Collections.Generic.List[string]
        if ($sp.Render) {
            $gArgs.Add("--rendering-driver")
            $gArgs.Add("opengl3")
            if ($sp.Res -ne "") {
                $gArgs.Add("--resolution")
                $gArgs.Add($sp.Res)
            }
        } else {
            $gArgs.Add("--headless")
        }
        $gArgs.Add("--audio-driver")
        $gArgs.Add("Dummy")
        $gArgs.Add("--path")
        $gArgs.Add($GameDir)

        if ($sp.Script -ne "") {
            $gArgs.Add("-s")
            $gArgs.Add($sp.Script)
        } elseif ($sp.Scene -ne "") {
            $gArgs.Add($sp.Scene)
        }

        $userArgs = @(if ($Fast) { $sp.FastArgs } else { $sp.Args })
        $uaCount = [int]($userArgs | Measure-Object).Count
        if ($uaCount -gt 0) {
            $gArgs.Add("--")
            foreach ($ua in $userArgs) {
                if (-not [string]::IsNullOrWhiteSpace([string]$ua)) {
                    $gArgs.Add([string]$ua)
                }
            }
        }

        $run = Invoke-GodotIsolated -Exe $godotExe -Arguments $gArgs.ToArray() -LimitSec $TimeoutSec

        $markerLine = ""
        $lines = $run.Output -split "`r?`n"
        foreach ($ln in $lines) {
            $trimmed = $ln.Trim()
            if ($sp.Marker -ne "" -and $trimmed.IndexOf($sp.Marker, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $markerLine = $trimmed
            }
        }
        if ($markerLine -eq "") {
            foreach ($ln in $lines) {
                $trimmed = $ln.Trim()
                if ($trimmed -match "(SELFTEST|OK\s+\d+/\d+|\d+/\d+\s+(PASS|boards solved))") {
                    $markerLine = $trimmed
                }
            }
        }

        $hasScriptErr = ($run.Output -match "SCRIPT ERROR:")
        # Windows Godot 4.5.1 headless sometimes emits post-quit(0) teardown -1073741819 (0xC0000005)
        $rcClean = ($run.ExitCode -eq 0) -or ($run.ExitCode -eq -1073741819 -and -not $hasScriptErr -and $markerLine -ne "" -and $markerLine -notmatch "\bFAIL\b")
        $ratioOk = $true
        if ($markerLine -match "(\d+)/(\d+)") {
            $numOk = [int]$Matches[1]
            $numTot = [int]$Matches[2]
            if ($numOk -ne $numTot -or $numTot -eq 0) {
                $ratioOk = $false
            }
        }
        if ($markerLine -match "\bFAIL\b") {
            $ratioOk = $false
        }

        $passed = (-not $run.TimedOut) -and (-not $hasScriptErr) -and $rcClean -and ($markerLine -ne "") -and $ratioOk
        $statusStr = if ($run.TimedOut) { "TIMEOUT" } elseif ($passed) { "PASS" } else { "FAIL" }
        $summaryMsg = if ($markerLine -ne "") { $markerLine } elseif ($hasScriptErr) { "SCRIPT ERROR in log" } else { "No marker (" + $sp.Marker + ")" }
        if ($summaryMsg.Length -gt 48) {
            $summaryMsg = $summaryMsg.Substring(0, 45) + "..."
        }

        $results.Add([PSCustomObject]@{
            Test    = $sp.Id
            Status  = $statusStr
            Summary = $summaryMsg
            Secs    = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:0.0}s", $run.Duration)
            RC      = $run.ExitCode
            RawOut  = $run.Output
            Passed  = $passed
        })

        if (-not $passed) {
            $overallExit = 1
        }
    }

    Write-Host ""
    Write-Host "+----------------+---------+--------------------------------------------------+--------+-------------+"
    Write-Host ("| {0,-14} | {1,-7} | {2,-48} | {3,6} | {4,11} |" -f "Test", "Status", "Result / Marker", "Time", "ExitCode")
    Write-Host "+----------------+---------+--------------------------------------------------+--------+-------------+"
    $passCount = 0
    foreach ($r in $results) {
        if ($r.Passed) { $passCount++ }
        Write-Host ("| {0,-14} | {1,-7} | {2,-48} | {3,6} | {4,11} |" -f $r.Test, $r.Status, $r.Summary, $r.Secs, $r.RC)
    }
    $resCount = [int]$results.Count
    Write-Host "+----------------+---------+--------------------------------------------------+--------+-------------+"
    Write-Host ("[godot_qa] Summary: {0}/{1} PASSED" -f $passCount, $resCount)

    foreach ($r in $results) {
        if (-not $r.Passed) {
            Write-Host ""
            Write-Host ("--- FAILURE LOG: {0} ---" -f $r.Test) -ForegroundColor Red
            $tail = ($r.RawOut -split "`r?`n") | Select-Object -Last 35
            foreach ($tl in $tail) { Write-Host ("  " + $tl) }
        }
    }
}

# 3. Screenshot step
if (-not [string]::IsNullOrWhiteSpace($Shot)) {
    if ([string]::IsNullOrWhiteSpace($Out)) {
        throw "When using -Shot <screen>, you must specify -Out <png_path>."
    }
    if ($Res -notmatch "^\d+x\d+$") {
        throw "Invalid -Res '$Res'. Expected '<width>x<height>' (e.g. '450x1000' or '720x1280')."
    }
    $godotExe = Resolve-GodotExecutable -ExplicitPath $GodotBin
    $outFull = if ([System.IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path (Get-Location).Path $Out }
    $outFull = [System.IO.Path]::GetFullPath($outFull)
    $outParent = Split-Path -Parent $outFull
    if (-not [string]::IsNullOrWhiteSpace($outParent) -and -not (Test-Path -LiteralPath $outParent)) {
        New-Item -ItemType Directory -Path $outParent -Force | Out-Null
    }

    $shotTmp = Join-Path ([System.IO.Path]::GetTempPath()) ("tw_shot_" + $PID + "_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $shotTmp -Force | Out-Null
    try {
        $shotTmpSlash = $shotTmp.Replace("\", "/")
        $atStr = $At.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        $sArgs = New-Object System.Collections.Generic.List[string]
        $sArgs.Add("--rendering-driver")
        $sArgs.Add("opengl3")
        $sArgs.Add("--audio-driver")
        $sArgs.Add("Dummy")
        $sArgs.Add("--resolution")
        $sArgs.Add($Res)
        $sArgs.Add("--path")
        $sArgs.Add($GameDir)
        $sArgs.Add("--")
        if ($Shot -eq "splash" -or $Shot -eq "title") {
            $sArgs.Add("--splash=1")
        } else {
            $sArgs.Add("--screen=" + $Shot)
        }
        $sArgs.Add("--shots=" + $shotTmpSlash)
        $sArgs.Add("--name=capture")
        $sArgs.Add("--at=" + $atStr)
        $sArgs.Add("--unlock=50")
        $sArgs.Add("--save=user://qa_shot_save.json")
        $sArgs.Add("--save_wipe=1")
        $sArgs.Add("--story_off=1")
        if (-not [string]::IsNullOrWhiteSpace($Act)) {
            $sArgs.Add("--act=" + $Act)
        }

        Write-Host ("[godot_qa] Capturing screen '{0}' at {1} -> {2}..." -f $Shot, $Res, $outFull)
        $shotRun = Invoke-GodotIsolated -Exe $godotExe -Arguments $sArgs.ToArray() -LimitSec $TimeoutSec
        $capturedPng = Join-Path $shotTmp "capture_0.png"
        if (Test-Path -LiteralPath $capturedPng) {
            Copy-Item -LiteralPath $capturedPng -Destination $outFull -Force
            $szKb = [Math]::Round(((Get-Item -LiteralPath $outFull).Length / 1024.0), 1)
            Write-Host ("[godot_qa] Screenshot OK: {0} ({1} KB, {2}s)" -f $outFull, $szKb, $shotRun.Duration)
        } else {
            Write-Host ("[godot_qa] Screenshot FAILED: capture_0.png was not generated (rc={0})" -f $shotRun.ExitCode) -ForegroundColor Red
            if (-not [string]::IsNullOrWhiteSpace($shotRun.Output)) {
                Write-Host $shotRun.Output
            }
            $overallExit = 1
        }
    } finally {
        if (Test-Path -LiteralPath $shotTmp) {
            Remove-Item -LiteralPath $shotTmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 4. CleanImport step
if ($CleanImport) {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCmd) {
        throw "git executable not found on PATH."
    }
    $dirtyImports = @(& git -C $RepoRoot diff --name-only -- "*.import" 2>$null | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $untrackedImports = @(& git -C $RepoRoot ls-files --others --exclude-standard -- "*.import" 2>$null | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $dirtyCount = [int]($dirtyImports | Measure-Object).Count
    $untrackedCount = [int]($untrackedImports | Measure-Object).Count

    if ($dirtyCount -gt 0) {
        & git -C $RepoRoot checkout -- "*.import"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[godot_qa] CleanImport FAILED during git checkout." -ForegroundColor Red
            $overallExit = 1
        } else {
            Write-Host ("[godot_qa] CleanImport: restored {0} tracked *.import file(s); preserved {1} untracked *.import file(s)." -f $dirtyCount, $untrackedCount)
        }
    } else {
        Write-Host ("[godot_qa] CleanImport: 0 tracked *.import files modified; {0} untracked *.import file(s) preserved." -f $untrackedCount)
    }
}

exit $overallExit
