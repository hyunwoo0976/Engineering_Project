# Run python tools/run_regression.py first to prepare vectors and CPU memories.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path $root '_work'
$bin = 'D:\My_project\2026.1\Vivado\bin'

if (!(Test-Path (Join-Path $work 'vectors.txt'))) {
    throw 'Run python tools/run_regression.py first.'
}
$rtl = @(Get-Content (Join-Path $root 'F_file/CPU.f') |
    Where-Object { $_.Trim() -and !$_.Trim().StartsWith('//') } |
    ForEach-Object { Join-Path $root $_.Trim() })

Push-Location $work
try {
    & "$bin\xvlog.bat" -sv @rtl "$root\tb\fp_rounding_checks.sv" "$root\tb\fp32_regression.sv" "$root\tb\cpu_fp_special.sv"
    if ($LASTEXITCODE -ne 0) {
        throw 'xvlog failed'
    }

    foreach ($top in @('fp_rounding_checks', 'fp32_regression', 'Testbench_CPU', 'cpu_fp_special')) {
        $snapshot = "p11_$top"
        & "$bin\xelab.bat" $top -s $snapshot -mt 2
        if ($LASTEXITCODE -ne 0) {
            throw "xelab failed: $top"
        }

        $log = "xsim_$top.log"
        if ($top -eq 'fp32_regression') {
            & "$bin\xsim.bat" $snapshot -R -testplusarg '"VECTORS=vectors.txt"' -log $log
        }
        else {
            & "$bin\xsim.bat" $snapshot -R -log $log
        }
        if ($LASTEXITCODE -ne 0) {
            throw "xsim failed: $top"
        }

        $text = Get-Content -Raw $log
        if ($text -match '(?im)(Fatal:|\[FAIL\]|^Error:)' -or $text -notmatch 'PASS') {
            throw "Simulation did not pass: $top (see $log)"
        }
        Write-Host "XSIM PASS: $top"
    }
}
finally {
    Pop-Location
}
