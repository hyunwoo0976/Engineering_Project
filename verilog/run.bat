@echo off
echo ========================================
echo 실행 프로젝트: %1
echo 컴파일 파일: %2.f
echo ========================================


cd verilog\%1


iverilog -o result.out -f %2.f
vvp result.out
gtkwave %2.vcd


cd ..\..

:: .\verilog\run.bat Project7_Shift_register Shift_register