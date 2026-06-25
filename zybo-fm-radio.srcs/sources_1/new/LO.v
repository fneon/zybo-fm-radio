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
    //input mm_clk,
    input  [3:0] btn,   // btn[0] = increment level, btn[1] = decrement level
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

wire mm_clk;
clk_wiz_0 instance_clk_wiz_0 (
        .clk_in1(sysclk_buf),
        .clk_out1(mm_clk) // Connects output to your internal clock wire mesh
    );
assign je[3] = mm_clk;

/*
wire mm_station;
clk_station instance_clk_station (
        .clk_in1(sysclk_buf),
        .clk_out1(mm_station) // Connects output to your internal clock wire mesh
    );
assign je[2] = mm_station;*/

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