`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 11/03/2026 10:05:26 PM
// Design Name:
// Module Name: sim_module
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Replays a raw XADC dump (uint16 LE xadc_do words) through LO and
//              records S_AXIS_0 (tdata on every tvalid, int16 LE) - the same
//              format as the FIFO captures.
//              LO is not modified: the PS clock and the XADC outputs are forced
//              on LO's internal nets.
//              Plusargs (xsim -testplusarg):
//                in=<file>   default ../../../../output/dump_20M_xadc.bin
//                out=<file>  default ../../../../output/sim_s_axis.bin
//                n=<samples> default 961538 = 1 s of the record
//              Relative paths start at zybo-fm-radio.sim/sim_1/behav/xsim.
//
// Dependencies: LO
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module sim_module(
    );

localparam CLK_PERIOD = 20;                         // aclk_gp0_50mhz, ns
localparam CYCLES_PER_SAMPLE = 52;                  // 50 MHz / 961.5 kSPS (ADCCLK 25 MHz, INIT_42 = 0x0200)
localparam DRDY_DELAY = 4;                          // XADC DRP read latency, den (= eoc) -> drdy
localparam SAMPLES_DEFAULT = 1000000000 / (CLK_PERIOD * CYCLES_PER_SAMPLE);    // 1 s = 961538
localparam FLUSH_CYCLES = 2000;                     // let FIR / CORDIC drain after the last sample

reg clk = 0;
always #(CLK_PERIOD / 2) clk = ~clk;

reg        eoc = 0;
reg        drdy = 0;
reg [15:0] do_r = 0;

LO dut (
    .sysclk(1'b0),                                  // keeps the clk_wiz_0 MMCM model idle
    .btn(4'b0),
    .vauxp14(1'b0),
    .vauxn14(1'b0),
    .led(),
    .je()
);

// Stand in for FCLK0 and the XADC
initial begin
    force dut.aclk_gp0_50mhz = clk;
    force dut.xadc_eoc = eoc;
    force dut.xadc_drdy = drdy;
    force dut.xadc_do = do_r;
end

// Registers in dc_filter / make_iq have no initial value: in hardware they power
// up 0, in simulation they are X. An X on the FIR's s_axis_data_tvalid stops the
// FIR model ("empty_1 and not_empty_1 are inconsistent"), and y1 is fed back, so
// it would stay X forever. phase_to_freq.freq is X until the first CORDIC output,
// but the pilot PLL already feeds it into the CIC on the first fir_valid; one X
// into the CIC's integrators makes its output X for the rest of the run.
// Hold them at 0 before the first clock edge; a released reg keeps that value
// until the design assigns it.
initial begin
    force dut.inst_dc_filter.dc_valid = 1'b0;
    force dut.inst_dc_filter.y1 = 16'sd0;
    force dut.inst_make_iq.out_valid = 1'b0;
    force dut.inst_make_iq.long_i = 32'sd0;
    force dut.inst_make_iq.long_q = 32'sd0;
    force dut.i_phase_to_freq.freq = 16'sd0;
    #(CLK_PERIOD / 4);
    release dut.inst_dc_filter.dc_valid;
    release dut.inst_dc_filter.y1;
    release dut.inst_make_iq.out_valid;
    release dut.inst_make_iq.long_i;
    release dut.inst_make_iq.long_q;
    release dut.i_phase_to_freq.freq;
end

reg [8*512-1:0] in_file, out_file;
integer n, fi, fo, lo, hi;
integer n_in = 0, n_out = 0, n_pkt = 0;
reg done = 0;

initial begin
    if (!$value$plusargs("in=%s", in_file))   in_file = "../../../../output/dump_20M_xadc.bin";
    if (!$value$plusargs("out=%s", out_file)) out_file = "../../../../output/sim_s_axis.bin";
    if (!$value$plusargs("n=%d", n))          n = SAMPLES_DEFAULT;

    // binary modes: in text mode Windows turns 0x0A into 0x0D 0x0A
    fi = $fopen(in_file, "rb");
    if (fi == 0) begin
        $display("sim_module: cannot open input %0s", in_file);
        $finish;
    end
    fo = $fopen(out_file, "wb");
    if (fo == 0) begin
        $display("sim_module: cannot open output %0s", out_file);
        $finish;
    end
    $display("sim_module: %0s -> %0s, %0d samples", in_file, out_file, n);

    repeat (10) @(posedge clk);
    while (!done && n_in < n) begin
        lo = $fgetc(fi);                            // little-endian, byte by byte ($fread would be big-endian)
        hi = $fgetc(fi);
        if (hi < 0)
            done = 1;
        else begin
            @(posedge clk) eoc <= 1;
            @(posedge clk) eoc <= 0;
            repeat (DRDY_DELAY - 1) @(posedge clk);
            drdy <= 1;
            do_r <= {hi[7:0], lo[7:0]};
            @(posedge clk) drdy <= 0;
            repeat (CYCLES_PER_SAMPLE - DRDY_DELAY - 2) @(posedge clk);
            n_in = n_in + 1;
            if (n_in % 1000000 == 0)
                $display("sim_module: %0d samples in, %0d out, t = %0t", n_in, n_out, $time);
        end
    end

    repeat (FLUSH_CYCLES) @(posedge clk);
    $fclose(fi);
    $fclose(fo);
    $display("sim_module: %0d samples in, %0d samples out (%0d bytes), %0d packets",
             n_in, n_out, 2 * n_out, n_pkt);
    $finish;
end

// Record S_AXIS_0; sampled on negedge so there is no race with the design's posedge flops
always @(negedge clk) if (dut.S_AXIS_0_tvalid === 1'b1) begin
    $fwrite(fo, "%c%c", dut.S_AXIS_0_tdata[7:0], dut.S_AXIS_0_tdata[15:8]);
    n_out = n_out + 1;
    if (dut.S_AXIS_0_tlast === 1'b1)
        n_pkt = n_pkt + 1;
end

endmodule
