`timescale 1ns / 1ps

module dc_filter(
    input clk,
    input in_valid,
    input signed [15:0] x0,
    output reg signed [15:0] y1,
    output reg dc_valid
);
    reg signed [15:0] x1 = 0;
    always @(posedge clk) begin : p1
        dc_valid <= in_valid;
        if (!in_valid) disable p1;
        y1 <= x0 - x1 + (y1 - (y1 >>> 5));
        x1 <= x0;
    end
endmodule

