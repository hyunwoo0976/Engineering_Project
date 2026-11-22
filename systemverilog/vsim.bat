@echo off
chcp 65001 >nul
setlocal
if "%~2"=="" ( echo Usage: vsim ^<path\file.sv^> ^<top_module^>  &  exit /b 1 )
call "D:\My_project\Engineering_Project\development\environment.cmd" >nul
set "SRC=%~f1"
set "WD=%~dp1_work"
if not exist "%WD%" mkdir "%WD%"
pushd "%WD%"
echo ===== COMPILE =====
call xvlog -sv "%SRC%"
if errorlevel 1 goto :end
echo ===== ELABORATE =====
call xelab %2 -s snap
if errorlevel 1 goto :end
echo ===== RUN =====
call xsim snap -R
:end
popd
endlocal
