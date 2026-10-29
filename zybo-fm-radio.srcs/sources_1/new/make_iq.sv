`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/27/2026 10:44:07 PM
// Design Name: 
// Module Name: make_iq
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


module make_iq(
    input clk,
    input in_valid,
    input signed [15:0] in_signal,
    input signed [15:0] in_cos,
    input signed [15:0] in_msin,
    output wire signed [15:0] out_i,
    output wire signed [15:0] out_q,
    output reg out_ready
);
    reg signed [31:0] long_i;
    reg signed [31:0] long_q;
    assign out_i = long_i[30:30-15];
    assign out_q = long_q[30:30-15];

    always @(posedge clk) begin : p1
        out_ready <= in_valid;
        if (!in_valid) disable p1;
        long_i <= in_signal * in_cos;
        long_q <= in_signal * in_msin;
    end
endmodule
