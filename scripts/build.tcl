# Batch bitstream build for zybo-fm-radio.
#
# Usage (from the repo root):
#   vivado -mode batch -source scripts/build.tcl [-tclargs <jobs>]
# or just run build.bat.
#
# Opens the existing project, regenerates IP and block-design output
# products, runs synthesis + implementation through write_bitstream, and
# copies the resulting bitstream to output/LO.bit. Also exports the hardware
# platform (output/LO.xsa, bitstream included) for PetaLinux / Vitis.
# Samples leave the PL through the AXI4-Stream FIFO in design_1 and are
# collected on PetaLinux with capture.bat.

set start_time [clock seconds]

set jobs 4
if {$argc > 0} { set jobs [lindex $argv 0] }

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set xpr        [file join $repo_dir zybo-fm-radio.xpr]
set out_dir    [file join $repo_dir output]

open_project $xpr

# Drop outputs of the previous build so a failed build cannot leave a stale
# bitstream behind to be programmed by mistake.
foreach f {LO.bit LO.xsa} {
    file delete -force [file join $out_dir $f]
}

# Make sure the stand-alone IP cores (clk_wiz_0, xadc_wiz_0, dds, fir, cordic)
# are current and have output products. IP inside a block design has
# SCOPE = its .bd file and is handled with the block design below.
set ips [get_ips -quiet -filter {SCOPE == ""}]
if {[llength $ips] > 0} {
    upgrade_ip -quiet $ips
    generate_target all $ips
}

# Block design (PS7 + AXI4-Stream FIFO): regenerate its output products and
# the HDL wrapper LO instantiates, so the wrapper ports always match the BD.
foreach bd [get_files -quiet *.bd] {
    set bd_ips [get_ips -quiet -filter "SCOPE == \"$bd\""]
    if {[llength $bd_ips] > 0} { upgrade_ip -quiet $bd_ips }
    generate_target all $bd
    make_wrapper -files $bd -top -force
}
update_compile_order -fileset sources_1

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

# Hardware handoff for PetaLinux / Vitis: address map, PS7 config, bitstream.
write_hw_platform -fixed -include_bit -force [file join $out_dir ${top}.xsa]

close_project
puts "Bitstream written to [file join $out_dir ${top}.bit]"

set elapsed [expr {[clock seconds] - $start_time}]
puts [format "Build finished: %d jobs, %d:%02d elapsed" $jobs [expr {$elapsed / 60}] [expr {$elapsed % 60}]]
