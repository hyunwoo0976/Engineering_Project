@echo off
chcp 65001 >nul
setlocal
if "%~1"=="" (
    echo Usage: wave ^<path\file.sv^>
    exit /b 1
)

call "D:\My_project\Engineering_Project\development\environment.cmd" >nul
set "SRC=%~f1"
set "WD=%~dp1_work"
set "WAVE_TCL=%~dp0wave.tcl"
set "WAVE_TCL=%WAVE_TCL:\=/%"
set "GTKWAVE=C:\iverilog\gtkwave\bin\gtkwave.exe"

if not exist "%WD%" mkdir "%WD%"
pushd "%WD%"

echo ===== COMPILE =====
call xvlog -sv "%SRC%"
if errorlevel 1 goto :end

echo ===== ELABORATE =====
call xelab Top -s snap -debug typical
if errorlevel 1 goto :end

echo ===== VCD =====
call xsim snap -tclbatch "%WAVE_TCL%"
if not exist "wave.vcd" goto :no_wave

echo ===== GTKWave =====
start "" "%GTKWAVE%" "wave.vcd"
goto :end

:no_wave
echo ERROR: wave.vcd was not created.

:end
popd
endlocal
