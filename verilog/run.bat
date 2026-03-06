@echo off
iverilog -o reg.out -f ./scripts/reg.f
vvp reg.out
gtkwave reg.vcd
echo DONE! Press Ctrl+Shift+R in GTKWave.