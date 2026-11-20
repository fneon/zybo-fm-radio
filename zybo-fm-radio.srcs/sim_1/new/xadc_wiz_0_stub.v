`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Simulation-only stand-in for the xadc_wiz_0 IP.
// The real xadc_wiz_0.xci is excluded from simulation (used_in_simulation =
// false): the XADC model runs on every DCLK although sim_module forces its
// outputs (xadc_do, xadc_eoc, xadc_drdy) from the recorded dump.
// Keep the port list in sync with
// zybo-fm-radio.gen/sources_1/ip/xadc_wiz_0/xadc_wiz_0.v.
//////////////////////////////////////////////////////////////////////////////////

module xadc_wiz_0
         (
          daddr_in,
          dclk_in,
          den_in,
          di_in,
          dwe_in,
          vauxp14,
          vauxn14,
          busy_out,
          channel_out,
          do_out,
          drdy_out,
          eoc_out,
          eos_out,
          alarm_out,
          vp_in,
          vn_in);

          input [6:0] daddr_in;
          input dclk_in;
          input den_in;
          input [15:0] di_in;
          input dwe_in;
          input vauxp14;
          input vauxn14;
          input vp_in;
          input vn_in;

          output busy_out;
          output [4:0] channel_out;
          output [15:0] do_out;
          output drdy_out;
          output eoc_out;
          output eos_out;
          output alarm_out;

          // forced by sim_module
          assign busy_out = 1'b0;
          assign channel_out = 5'd0;
          assign do_out = 16'd0;
          assign drdy_out = 1'b0;
          assign eoc_out = 1'b0;
          assign eos_out = 1'b0;
          assign alarm_out = 1'b0;
endmodule
