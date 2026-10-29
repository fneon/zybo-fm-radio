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
    output [3:1] je
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
xadc_wiz_0 instance_xadc (
        .dclk_in(sysclk_buf),
        .vauxp14(vauxp14),
        .vauxn14(vauxn14),
        .eoc_out(xadc_eoc),
        .daddr_in(7'h1e),
        .den_in(xadc_eoc),
        .drdy_out(xadc_drdy),
        .do_out(xadc_do)
    );

wire signed [15:0] dc_out;
wire dc_ready;
dc_filter inst_dc_filter(
    .clk(sysclk_buf),
    .in_valid(xadc_drdy),
    .x0(xadc_signed[16:1]),
    .y1(dc_out),
    .dc_ready(dc_ready)
);


wire signed [15:0] dds_cos, dds_msin;
dds_compiler_0 inst_dds (
    .aclk(xadc_eoc),                        // TODO: what is aclk? (why "a")
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
wire iq_ready;
make_iq inst_make_iq (
    .clk(sysclk_buf),
    .in_valid(dc_ready),
    .in_signal(dc_out),
    .in_cos(dds_cos),
    .in_msin(dds_msin),
    .out_i(si),
    .out_q(sq),
    .out_ready(iq_ready)
);

wire [73:0] fir_out;
wire signed [15:0] fsq = fir_out[40+17+15:40+17]; //73:40
wire signed [15:0] fsi = fir_out[17+15:17]; //33:0
wire fir_ready;
fir_compiler_0 inst_fir (
    .aclk(sysclk_buf),
    .s_axis_data_tvalid(iq_ready),
    .s_axis_data_tdata({sq, si}),
    .m_axis_data_tdata(fir_out),
    .m_axis_data_tvalid(fir_ready)
);

wire signed [15:0] cordic_out;
wire cordic_ready;
cordic_0 inst_cordic (
    .aclk(sysclk_buf),
    .s_axis_cartesian_tdata({fsq, fsi}),
    .s_axis_cartesian_tvalid(fir_ready),
    .m_axis_dout_tdata(cordic_out),
    .m_axis_dout_tvalid(cordic_ready)
);

// CORDIC Phase_Format = Scaled_Radians: cordic_out = phase/pi, fix16_13 (+-8192)
wire signed [15:0] phase16 = {cordic_out[13:0], 2'b00};  // +-pi -> +-32768, wraps for free
reg  signed [15:0] phase_prev = 0;
reg  signed [15:0] freq;          // 1 LSB = FS/65536 = 14.7 Hz; +-75 kHz -> +-5100
always @(posedge sysclk_buf) if (cordic_ready) begin
    freq       <= phase16 - phase_prev;
    phase_prev <= phase16;
end

/*
blk_mem_gen_0 instance_bram (
        .addra(mem_addr),
        .clka(sysclk_buf),
        .dina(mem_data),
        //.douta(15:0),
        .ena(1),
        .wea(do_write)
    );
    
 reg [17:0] mem_addr = 0;
 reg write_done = 0;
 reg [15:0] mem_data;
 reg do_write = 0;

always @(posedge sysclk_buf) begin : p1
    if (write_done) disable p1;
    mem_data <= mem_addr[15:0];
    mem_addr <= mem_addr + 1;
    do_write <= 1;
    if (mem_addr == 18'h3FFFF) begin
        write_done <= 1;
        do_write <= 0;
    end
end
*/

(* ram_style = "block" *) reg [15:0] inferred_ram[0:262143];
reg [17:0] mem_addr = 0;
reg write_done = 0;
reg [15:0] ram_dout;

/*
always @(posedge sysclk_buf) begin : p1
    if (write_done) disable p1;
    inferred_ram[mem_addr] <= mem_addr[15:0];
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
reg signed [31:0] mul_res;
always @(posedge sysclk_buf) begin : p1
    //if (write_done || (!fir_valid)) disable p1;
    if (write_done || (!dc_ready)) disable p1;
    //mul_res <= dds_cos *  filter_out;
    mul_res <= dds_cos *  dc_out;
    inferred_ram[mem_addr] <= mul_res[31:31-15];//filter_out;//xadc_signed[16:1];//mul_res[40:40-15];
    // Read port keeps the RAM from being optimized away; like the write it
    // stops after write_done, so the BRAM is idle during config readback.
    ram_dout <= inferred_ram[mem_addr];
    mem_addr <= mem_addr + 1;
    if (mem_addr == 18'h3FFFF) begin
        write_done <= 1;
    end
end
*/
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


assign led[0] = write_done;
assign led[1] = ^ram_dout;
assign led[3:2] = 2'b00;


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