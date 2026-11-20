//////////////////////////////////////////////////////////////////////////////////
// Simulation-only: use the FIR Compiler's synthesized netlist instead of its
// behavioral VHDL model, which is ~30x slower and accounts for almost all of
// the simulation time. The netlist is bit- and cycle-exact (it is the IP
// itself); checked against the behavioral model on 3000 input samples.
// fir_compiler_0.xci is excluded from simulation (used_in_simulation = false).
// The netlist is regenerated with the IP (out-of-context synthesis); after
// changing the FIR, run its synthesis and then Reset Behavioral Simulation.
//////////////////////////////////////////////////////////////////////////////////

`include "../../../zybo-fm-radio.gen/sources_1/ip/fir_compiler_0/fir_compiler_0_sim_netlist.v"
