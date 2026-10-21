# Batch bitstream build for zybo-fm-radio.
#
# Usage (from the repo root):
#   vivado -mode batch -source scripts/build.tcl [-tclargs <jobs>]
# or just run build.bat.
#
# Opens the existing project, regenerates IP output products, runs
# synthesis + implementation through write_bitstream, and copies the
# resulting bitstream to output/LO.bit.

set jobs 4
if {$argc > 0} { set jobs [lindex $argv 0] }

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set xpr        [file join $repo_dir zybo-fm-radio.xpr]
set out_dir    [file join $repo_dir output]

open_project $xpr

# Make sure IP cores (clk_wiz_0, clk_station) are current and have output products.
set ips [get_ips -quiet]
if {[llength $ips] > 0} {
    upgrade_ip -quiet $ips
    generate_target all $ips
}

# Full clean rebuild of the top-level runs.
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

set synth_status [get_property STATUS [get_runs synth_1]]
set impl_status  [get_property STATUS [get_runs impl_1]]
puts "synth_1: $synth_status"
puts "impl_1:  $impl_status"

if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis failed — see [get_property DIRECTORY [get_runs synth_1]]/runme.log"
}
if {![string match "*write_bitstream Complete*" $impl_status]} {
    error "Implementation/bitstream failed — see [get_property DIRECTORY [get_runs impl_1]]/runme.log"
}

set top [get_property TOP [current_fileset]]
set bit [file join [get_property DIRECTORY [get_runs impl_1]] ${top}.bit]
file mkdir $out_dir
file copy -force $bit [file join $out_dir ${top}.bit]

# Timing summary so failures to meet timing are visible from the console.
open_run impl_1
report_timing_summary -no_detailed_paths -file [file join $out_dir timing_summary.rpt]
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
if {$wns eq ""} {
    puts "Worst negative slack (setup): n/a (no constrained timing paths)"
} else {
    puts "Worst negative slack (setup): $wns ns"
}
if {$wns ne "" && $wns < 0} {
    puts "WARNING: design does not meet timing."
}

close_project
puts "Bitstream written to [file join $out_dir ${top}.bit]"
