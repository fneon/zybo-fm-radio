# Batch bitstream build for zybo-fm-radio.
#
# Usage (from the repo root):
#   vivado -mode batch -source scripts/build.tcl [-tclargs <jobs>]
# or just run build.bat.
#
# Opens the existing project, regenerates IP output products, runs
# synthesis + implementation through write_bitstream, and copies the
# resulting bitstream to output/LO.bit. Also writes output/LO.ll (logic
# location file) and output/LO_bram_map.csv, used by bram_dump.bat to
# decode BRAM contents from a configuration readback.

set start_time [clock seconds]

set jobs 4
if {$argc > 0} { set jobs [lindex $argv 0] }

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set xpr        [file join $repo_dir zybo-fm-radio.xpr]
set out_dir    [file join $repo_dir output]

open_project $xpr

# Drop outputs of the previous build so a failed build cannot leave a stale
# BRAM map next to a fresh .ll (bram_dump.bat would then decode garbage).
foreach f {LO.bit LO.ll LO.ll.bram_cache LO_bram_map.csv} {
    file delete -force [file join $out_dir $f]
}

# Make sure IP cores (clk_wiz_0, clk_station) are current and have output products.
set ips [get_ips -quiet]
if {[llength $ips] > 0} {
    upgrade_ip -quiet $ips
    generate_target all $ips
}

# Logic location file (.ll): maps every BRAM bit to its position in the
# configuration data, for decoding readbacks.
set_property STEPS.WRITE_BITSTREAM.ARGS.LOGIC_LOCATION_FILE true [get_runs impl_1]

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
file copy -force [file rootname $bit].ll [file join $out_dir ${top}.ll]

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

# Placement and logical mapping of the inferred capture RAM, one row per
# BRAM primitive: which address range and data bits it holds.
set rams [get_cells -hierarchical -filter {PRIMITIVE_GROUP == BMEM && RTL_RAM_NAME =~ *inferred_ram*}]
if {[llength $rams] == 0} {
    error "No BRAM primitives for inferred_ram found — was the RAM optimized away?"
}
set f [open [file join $out_dir ${top}_bram_map.csv] w]
puts $f "loc,width,addr_begin,addr_end,slice_begin,slice_end"
foreach c [lsort -dictionary $rams] {
    puts $f [join [list [get_property LOC $c] [get_property READ_WIDTH_A $c]         [get_property ram_addr_begin $c] [get_property ram_addr_end $c]         [get_property ram_slice_begin $c] [get_property ram_slice_end $c]] ,]
}
close $f
puts "BRAM map: [llength $rams] primitives -> [file join $out_dir ${top}_bram_map.csv]"

close_project
puts "Bitstream written to [file join $out_dir ${top}.bit]"

set elapsed [expr {[clock seconds] - $start_time}]
puts [format "Build finished: %d jobs, %d:%02d elapsed" $jobs [expr {$elapsed / 60}] [expr {$elapsed % 60}]]
