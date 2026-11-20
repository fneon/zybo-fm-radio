`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Simulation-only stand-in for the block design wrapper (design_1_wrapper).
// The real design_1.bd / design_1_wrapper.v are excluded from simulation
// (used_in_simulation = false): the PS7 VIP, AXI FIFO and interconnect cost a
// lot of simulation time and nothing the testbench records goes through them.
// sim_module forces aclk_gp0_50mhz, so the stub only ties its outputs off.
// Keep the port list in sync with
// zybo-fm-radio.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v.
//////////////////////////////////////////////////////////////////////////////////

module design_1_wrapper
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    S_AXIS_0_tdata,
    S_AXIS_0_tlast,
    S_AXIS_0_tready,
    S_AXIS_0_tvalid,
    aclk_gp0_50mhz);
  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;
  input [31:0]S_AXIS_0_tdata;
  input S_AXIS_0_tlast;
  output S_AXIS_0_tready;
  input S_AXIS_0_tvalid;
  output aclk_gp0_50mhz;

  assign S_AXIS_0_tready = 1'b1;
  assign aclk_gp0_50mhz = 1'b0;     // forced by sim_module
endmodule
