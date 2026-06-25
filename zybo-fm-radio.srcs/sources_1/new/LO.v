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

wire mm_station;
clk_station instance_clk_station (
        .clk_in1(sysclk_buf),
        .clk_out1(mm_station) // Connects output to your internal clock wire mesh
    );
assign je[2] = mm_station;

pwm instance_pwm (
        .clk(sysclk_buf),
        .duty(256*6/33),    // 256/3.3*0.6 -> 256/33*6
        .pwm_out (je[1])
);
    
endmodule

module pwm (
    input  wire        clk,
    input  wire [7:0]  duty,
    output reg         pwm_out
);

    reg [7:0] counter;

    always @(posedge clk) begin
        counter <= counter + 1;
        pwm_out <= (counter < duty);
    end

endmodule