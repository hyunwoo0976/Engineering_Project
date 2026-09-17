# Minimal diagnostic, independent of the FPU. No user configuration changes.
set root [file normalize [file join [file dirname [info script]] ..]]
set_param general.maxThreads 1
create_project -in_memory -part xc7a35tcpg236-1

read_verilog [file join $root tools synthesis_probe.v]
synth_design -top synthesis_probe -part xc7a35tcpg236-1 -mode out_of_context

puts "SYNTHESIS_PROBE_PASS"
