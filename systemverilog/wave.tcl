open_vcd wave.vcd
log_vcd [get_objects -r /Top/*]
run all
close_vcd
quit
