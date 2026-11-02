`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/01/2026 06:47:31 PM
// Design Name: 
// Module Name: phase_to_freq
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


module phase_to_freq(
    input wire aclk,
    input wire aresetn,
    input wire s_axis_tvalid, 
    output reg s_axis_tready,
    input wire s_axis_tlast,
    input wire [15:0] s_axis_tdata,
    output reg m_axis_tvalid, 
    input wire m_axis_tready, 
    output reg m_axis_tlast,
    output wire [15:0] m_axis_tdata 
    );

// CORDIC Phase_Format = Scaled_Radians: cordic_out = phase/pi, fix16_13 (+-8192)
wire signed [15:0] phase16 = s_axis_tdata;//{cordic_out[13:0], 2'b00};  // +-pi -> +-32768, wraps for free
reg  signed [15:0] phase_prev = 0;
reg  signed [15:0] freq;          // 1 LSB = FS/65536 = 14.7 Hz; +-75 kHz -> +-5100
reg freq_valid = 0;
assign m_axis_tdata = freq;

always @(posedge aclk) begin
    m_axis_tvalid <= s_axis_tvalid;
    m_axis_tlast <= s_axis_tlast;
    s_axis_tready <= m_axis_tready;
    if (s_axis_tvalid) begin
        freq       <= phase16 - phase_prev;
        phase_prev <= phase16;
    end
end

endmodule
