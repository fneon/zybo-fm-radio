`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/20/2026 03:31:50 PM
// Design Name: 
// Module Name: LO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module LO(
    input sysclk,
    input  [3:0] btn,   // btn[0] = increment level, btn[1] = decrement level
    input  vauxp14, vauxn14,
    output [3:0] led,   // shows current level on the user LEDs
    output [3:1] je,
    // PS7 DDR and fixed MIO pins, passed straight through to design_1_wrapper.
    // Each needs its own direction: a bare name would inherit "output [3:1]" from je.
    inout [14:0] DDR_addr,
    inout [2:0]  DDR_ba,
    inout        DDR_cas_n,
    inout        DDR_ck_n,
    inout        DDR_ck_p,
    inout        DDR_cke,
    inout        DDR_cs_n,
    inout [3:0]  DDR_dm,
    inout [31:0] DDR_dq,
    inout [3:0]  DDR_dqs_n,
    inout [3:0]  DDR_dqs_p,
    inout        DDR_odt,
    inout        DDR_ras_n,
    inout        DDR_reset_n,
    inout        DDR_we_n,
    inout        FIXED_IO_ddr_vrn,
    inout        FIXED_IO_ddr_vrp,
    inout [53:0] FIXED_IO_mio,
    inout        FIXED_IO_ps_clk,
    inout        FIXED_IO_ps_porb,
    inout        FIXED_IO_ps_srstb
);

wire [31:0] S_AXIS_0_tdata;      // non 1-bit wires must be forwrd declared
design_1_wrapper inst_system
       (.DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        //----
        .S_AXIS_0_tdata(S_AXIS_0_tdata),
        .S_AXIS_0_tlast(S_AXIS_0_tlast),
        .S_AXIS_0_tready(S_AXIS_0_tready),
        .S_AXIS_0_tvalid(S_AXIS_0_tvalid),
        .aclk_gp0_50mhz(aclk_gp0_50mhz)
        );


reg count = 0;
//assign je[3] = count;
//always @ (posedge(sysclk)) count <= count + 1;
wire sysclk_buf;

IBUFG sysclk_ibuf (
    .I(sysclk),
    .O(sysclk_buf)
);

clk_wiz_0 instance_clk_wiz_0 (
        .clk_in1(sysclk_buf),
        .clk_out1(je[3]),
        .clk_out2(je[2])
    );
    

wire xadc_eoc, xadc_drdy;
wire [15:0] xadc_do;
wire signed [16:0] xadc_signed = {1'b0, xadc_do};
xadc_wiz_0 instance_xadc (                              // TODO: currently in DRP mode, AXI4-Stream is probably better
        .dclk_in(aclk_gp0_50mhz),
        .vauxp14(vauxp14),
        .vauxn14(vauxn14),
        .eoc_out(xadc_eoc),
        .daddr_in(7'h1e),
        .den_in(xadc_eoc),             // 961538 Hz
        .drdy_out(xadc_drdy),
        .do_out(xadc_do)
    );

wire signed [15:0] dc_out;
wire dc_valid;
dc_filter inst_dc_filter(
    .clk(aclk_gp0_50mhz),
    .in_valid(xadc_drdy),
    .x0(xadc_signed[16:1]),
    .y1(dc_out),
    .dc_valid(dc_valid)
);


wire signed [15:0] dds_cos, dds_msin;
dds_compiler_0 inst_dds (
    .aclk(xadc_eoc),                        // TODO: maybe xadc_drdy?
    .m_axis_data_tdata({dds_msin, dds_cos})
);


wire signed [15:0] si;
wire signed [15:0] sq;
wire iq_valid;
make_iq inst_make_iq (
    .clk(aclk_gp0_50mhz),
    .in_valid(dc_valid),
    .in_signal(dc_out),
    .in_cos(dds_cos),
    .in_msin(dds_msin),
    .out_i(si),
    .out_q(sq),
    .out_valid(iq_valid)
);

wire [73:0] fir_out;
wire signed [15:0] fsq = fir_out[40+17+15:40+17]; //73:40
wire signed [15:0] fsi = fir_out[17+15:17]; //33:0
wire fir_valid;
fir_compiler_0 inst_fir (
    .aclk(aclk_gp0_50mhz),
    .s_axis_data_tvalid(iq_valid),
    .s_axis_data_tdata({sq, si}),
    .m_axis_data_tdata(fir_out),
    .m_axis_data_tvalid(fir_valid)
);

wire signed [15:0] cordic_tdata;
wire cordic_tvalid;
cordic_0 inst_cordic (
    .aclk(aclk_gp0_50mhz),
    .s_axis_cartesian_tdata({fsq, fsi}),
    .s_axis_cartesian_tvalid(fir_valid),
    .m_axis_dout_tdata(cordic_tdata),
    .m_axis_dout_tvalid(cordic_tvalid)
);


`define A4S_PREV(sig) cordic_``sig
`define A4S_NEXT(sig) S_AXIS_0_``sig
wire signed [15:0] phase_to_freq_data;
phase_to_freq i_phase_to_freq (
    .aclk(aclk_gp0_50mhz),
    .s_axis_tvalid(`A4S_PREV(tvalid)),
    //.s_axis_tlast(`A4S_PREV(tlast)),
    .s_axis_tdata({cordic_tdata[13:0], 2'b00}),
    //.m_axis_tvalid(`A4S(`A4S_NEXT, tvalid)),
    //.m_axis_tlast(`A4S(`A4S_NEXT, tlast)),
    //.m_axis_tdata(`A4S(`A4S_NEXT, tdata))
    .m_axis_tdata(phase_to_freq_data)
);

`define A4S_NEXT(sig) S_AXIS_0_``sig
wire signed [7:0] pilot_cos;
wire signed [7:0] pilot_sin;
dds_pilot i_dds_pilot (
    .aclk(fir_valid),                               // fir_valid is 320513 Hz, xadc_eoc is 961538 Hz
    //.m_axis_phase_tdata(`A4S(`A4S_NEXT, tdata))   // inc: 111100101101 -> 65536/320513*19000 ~= 3885, 
    .m_axis_data_tdata({pilot_sin, pilot_cos})
);
reg i_dds_pilot_tvalid;
reg signed [23:0] pilot_mult;
always @(posedge aclk_gp0_50mhz) begin
    i_dds_pilot_tvalid <= fir_valid;
    if (i_dds_pilot_tvalid)
        pilot_mult <= phase_to_freq_data * pilot_cos;
end

//pilot digital
localparam PHASE_MSB = 16+2-1;
reg [PHASE_MSB:0] pilot_phase = 0;
wire pilot_dout = pilot_phase[PHASE_MSB];
reg signed [PHASE_MSB:0] pilot_vco = 0;               // 3886 -> 19005
always @(posedge aclk_gp0_50mhz) if (fir_valid) begin
    pilot_phase <= pilot_phase + (3885+1)*4 + pilot_vco;
end

reg dmult_tvalid = 0;
reg signed [15:0] pilot_dmult;
always @(posedge aclk_gp0_50mhz) begin
    dmult_tvalid <= fir_valid;
    if (fir_valid) begin
        if (pilot_dout)
            pilot_dmult <= phase_to_freq_data;
        else
            pilot_dmult <= -phase_to_freq_data;
    end
end

wire cic_tvalid;
wire signed [15:0] cic_tdata;
cic_19k_pll i_cic_19k_pll (
    .aclk(aclk_gp0_50mhz),
    .s_axis_data_tvalid(dmult_tvalid),
    .s_axis_data_tdata(pilot_dmult),
    .m_axis_data_tvalid(cic_tvalid),
    .m_axis_data_tdata(cic_tdata)
);

reg signed [31:0] PD_int = 0;
wire signed [7:0] PD_int_top = PD_int[31 -:8];
always @(posedge aclk_gp0_50mhz) begin  // -822 / 807 -> +/- 1000
    if (cic_tvalid) begin
        pilot_vco <= PD_int_top - (cic_tdata / (512/4));   // Proportional part
        PD_int <= PD_int - cic_tdata*2*256;                // Integral part ( PD_int_top4 = PD_int >> 24  )
    end
end

wire signed [15:0] pilot_sincos_tdata;
pilot_sincos i_pilot_sincos (
    .aclk(aclk_gp0_50mhz),
    .s_axis_phase_tvalid(dmult_tvalid),
    .s_axis_phase_tdata(pilot_phase[PHASE_MSB -: 16]),
    //.m_axis_data_tvalid(cic_tvalid),
    .m_axis_data_tdata(pilot_sincos_tdata)
);

//assign S_AXIS_0_tdata[15:0] = {pilot_sincos_tdata[15:8], 8'd0};          // L - dpilot
//assign S_AXIS_0_tdata[31:16] = phase_to_freq_data;  // R - audio
//assign S_AXIS_0_tvalid = i_dds_pilot_tvalid;

// pll error
assign S_AXIS_0_tdata[15:0] = cic_tdata;          // L - dpilot
assign S_AXIS_0_tdata[31:16] = phase_to_freq_data;  // R - audio
assign S_AXIS_0_tvalid = i_dds_pilot_tvalid;

// digital 19k*audio, audio
//assign S_AXIS_0_tdata[15:0] = pilot_dmult;          // L - dpilot
//assign S_AXIS_0_tdata[31:16] = phase_to_freq_data;  // R - audio
//assign S_AXIS_0_tvalid = i_dds_pilot_tvalid;

// analog 19k*audio, audio
//assign S_AXIS_0_tdata[15:0] = pilot_mult[23:8];     // L - pilot*audio
//assign S_AXIS_0_tdata[31:16] = phase_to_freq_data;  // R - audio
//assign S_AXIS_0_tvalid = i_dds_pilot_tvalid;

// works great! (analog 19k, audio)
//assign S_AXIS_0_tdata[15:0] = {pilot_cos, 8'b0};
//assign S_AXIS_0_tdata[31:16] = phase_to_freq_data;
//assign S_AXIS_0_tvalid = i_dds_pilot_tvalid;

//assign S_AXIS_0_tdata = xadc_do;
//assign S_AXIS_0_tvalid = xadc_drdy;

//assign S_AXIS_0_tdata = dc_out;
//assign S_AXIS_0_tvalid = dc_valid;

//assign S_AXIS_0_tdata = {cordic_out[13:0], 2'b00};
//assign S_AXIS_0_tvalid = cordic_valid;

//wire signed [15:0] pilot_cos16 = pilot_cos;
//assign S_AXIS_0_tdata = pilot_cos16;
//assign S_AXIS_0_tvalid = i_dds_pilot_tvalid;


reg [6:0] fifo_counter = 1;
reg  tlast_reg = 0;
assign S_AXIS_0_tlast = tlast_reg;

always @(posedge aclk_gp0_50mhz) if (S_AXIS_0_tvalid) begin
    fifo_counter <= fifo_counter + 1;
    if (fifo_counter == 0)
        tlast_reg <= 1;
    else
        tlast_reg <= 0;
end
 
endmodule

module pwm (
    input  wire        clk,
    input  wire [8:0]  duty,      // 0..256: 0 -> 0%, 256 -> 100%
    output reg         pwm_out
);

    reg [7:0] counter;            // free-running 0..255

    always @(posedge clk) begin
        counter <= counter + 1;
        pwm_out <= (counter < duty);   // duty=256 -> always high (100%)
    end

endmodule