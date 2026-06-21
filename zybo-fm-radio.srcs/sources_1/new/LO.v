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
    output [3:3] je
    );
    
reg count = 0;
//assign je[3] = count;
//always @ (posedge(sysclk)) count <= count + 1;

wire mm_clk;
clk_wiz_0 instance_clk_wiz (
        .clk_in1(sysclk),
        .clk_out1(mm_clk) // Connects output to your internal clock wire mesh
    );
assign je[3] = mm_clk;
    
endmodule
