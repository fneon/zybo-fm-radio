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

wire [15:0]S_AXIS_0_tdata;      // non 1-bit wires must be forwrd declared
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
        .den_in(xadc_eoc),
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

/*
wire signed [31:0] long_i = dds_cos  *  dc_out;  //[31:31-15];
wire signed [31:0] long_q = dds_msin *  dc_out;  //[31:31-15];
wire signed [15:0] si = long_i[31:31-15];
wire signed [15:0] sq = long_q[31:31-15];
*/

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

wire signed [15:0] cordic_out;
wire cordic_valid;
cordic_0 inst_cordic (
    .aclk(aclk_gp0_50mhz),
    .s_axis_cartesian_tdata({fsq, fsi}),
    .s_axis_cartesian_tvalid(fir_valid),
    .m_axis_dout_tdata(cordic_out),
    .m_axis_dout_tvalid(cordic_valid)
);

// CORDIC Phase_Format = Scaled_Radians: cordic_out = phase/pi, fix16_13 (+-8192)
wire signed [15:0] phase16 = {cordic_out[13:0], 2'b00};  // +-pi -> +-32768, wraps for free
reg  signed [15:0] phase_prev = 0;
reg  signed [15:0] freq;          // 1 LSB = FS/65536 = 14.7 Hz; +-75 kHz -> +-5100
reg freq_valid = 0;
always @(posedge aclk_gp0_50mhz) begin
    freq_valid <= cordic_valid;
    if (cordic_valid) begin
        freq       <= phase16 - phase_prev;
        phase_prev <= phase16;
    end
end

/*
  input [15:0]S_AXIS_0_tdata;
  output S_AXIS_0_tready;
  input S_AXIS_0_tvalid;
  output aclk_gp0_50mhz;
*/
/*        
reg S_AXIS_0_tvalid_reg;
S_AXIS_0_tvalid = S_AXIS_0_tvalid_reg;
always @(posedge aclk_gp0_50mhz) begin
    S_AXIS_0_tvalid_reg <= freq_valid;
    if (freq_valid) begin
        S_AXIS_0_tdata <= freq;
    end
end
*/
assign S_AXIS_0_tvalid = freq_valid;
assign S_AXIS_0_tdata = freq;
reg [6:0] fifo_counter = 1;
reg  tlast_reg = 0;
assign S_AXIS_0_tlast = tlast_reg;

always @(posedge aclk_gp0_50mhz) begin
    if (S_AXIS_0_tvalid) begin
        fifo_counter <= fifo_counter + 1;
        if (fifo_counter == 0)
            tlast_reg <= 1;
        else
            tlast_reg <= 0;
    end
end
 

/*
(* ram_style = "block" *) reg [15:0] inferred_ram[0:262143];
reg [17:0] mem_addr = 0;
reg write_done = 0;
reg [15:0] ram_dout;

always @(posedge sysclk_buf) begin : p1
    if (write_done || (!cordic_ready)) disable p1;
    inferred_ram[mem_addr] <= freq;//fsi;//freq;//cordic_out;
    // Read port keeps the RAM from being optimized away; like the write it
    // stops after write_done, so the BRAM is idle during config readback.
    ram_dout <= inferred_ram[mem_addr];
    mem_addr <= mem_addr + 1;
    if (mem_addr == 18'h3FFFF) begin
        write_done <= 1;
    end
end
*/

/*
assign led[0] = write_done;
assign led[1] = ^ram_dout;
assign led[3:2] = 2'b00;
*/


/*
wire mm_station;
clk_station instance_clk_station (
        .clk_in1(sysclk_buf),
        .clk_out1(mm_station) // Connects output to your internal clock wire mesh
    );
assign je[2] = mm_station;*/

/*
// Map the 0..4 level onto PWM duty: 0 -> 0%, 4 -> 50%.
// duty = level * 32  ->  0, 32, 64, 96, 128 (128/256 = 50%).
wire [8:0] level_duty = {level, 5'b00000};

pwm instance_pwm (
        .clk(sysclk_buf),
        .duty(level_duty),
        .pwm_out (je[1])
);

// ---------------------------------------------------------------------------
// Button-controlled level: a value in the range 0..4.
//   btn[0] : increment (saturates at 4)
//   btn[1] : decrement (saturates at 0)
// One step per press. Buttons are synchronized into the clock domain and
// sampled on a slow tick (~8.4 ms @ 125 MHz) for debouncing; a level change
// happens on the rising edge of the debounced button.
// ---------------------------------------------------------------------------
reg [2:0] level = 3'd0;

// 2-stage synchronizers for the raw, asynchronous button inputs.
reg [1:0] btn0_sync = 2'b00;
reg [1:0] btn1_sync = 2'b00;
always @(posedge sysclk_buf) begin
    btn0_sync <= {btn0_sync[0], btn[0]};
    btn1_sync <= {btn1_sync[0], btn[1]};
end

// Slow sampling tick for debounce.
reg [19:0] tick_cnt = 20'd0;
wire tick = (tick_cnt == 20'd0);
always @(posedge sysclk_buf) tick_cnt <= tick_cnt + 1'b1;

// Debounced state at the previous tick, for rising-edge detection.
reg btn0_prev = 1'b0;
reg btn1_prev = 1'b0;
always @(posedge sysclk_buf) begin
    if (tick) begin
        if (btn0_sync[1] & ~btn0_prev) begin        // btn[0] pressed
            if (level < 3'd4) level <= level + 1'b1;
        end else if (btn1_sync[1] & ~btn1_prev) begin // btn[1] pressed
            if (level > 3'd0) level <= level - 1'b1;
        end
        btn0_prev <= btn0_sync[1];
        btn1_prev <= btn1_sync[1];
    end
end

// Show the current level on the LEDs.
led_bar level_display (
    .value (level),
    .led   (led)
);
*/
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