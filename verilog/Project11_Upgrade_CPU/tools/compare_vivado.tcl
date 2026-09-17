# vivado -mode batch -source tools/compare_vivado.tcl -tclargs PART
# OOC FPU only; identical 20ns clock, no package I/O constraints.
set root [file normalize [file join [file dirname [info script]] ..]]
set part [lindex $argv 0]
if {$part eq ""} {
    set part xc7a35tcpg236-1
}
set out [file join $root _work ppa]
file mkdir $out
set_param general.maxThreads 1
set modes [lindex $argv 1]
if {$modes eq ""} {
    set modes {0 1}
}
foreach iso $modes {
    create_project -in_memory -part $part
    set manifest [open [file join $root F_file CPU.f] r]
    set rtl_sources {}

    foreach line [split [read $manifest] "\n"] {
        set line [string trim $line]
        if {$line eq "" || [string match {//*} $line]} {
            continue
        }
        if {![string match {tb/*} $line]} {
            lappend rtl_sources [file join $root $line]
        }
    }
    close $manifest

    read_verilog -sv $rtl_sources
    synth_design -top FPU -part $part -mode out_of_context -generic ISOLATE=$iso
    create_clock -name clk -period 20 [get_ports clk]
    set_false_path -from [get_ports reset]

    opt_design
    place_design
    route_design

    report_utilization -file [file join $out isolation_${iso}_utilization.rpt]
    report_timing_summary -file [file join $out isolation_${iso}_timing.rpt]
    report_power -file [file join $out isolation_${iso}_vectorless_power.rpt]
    write_checkpoint -force [file join $out isolation_${iso}.dcp]
    close_project
}
