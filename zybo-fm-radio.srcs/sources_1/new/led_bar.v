`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: led_bar
//
// Description: Thermometer-style level indicator. Takes a value in the range
//              0..4 and lights that many of the 4 user LEDs, starting from
//              led[0]:
//                  value = 0 -> 0000  (no LEDs)
//                  value = 1 -> 0001
//                  value = 2 -> 0011
//                  value = 3 -> 0111
//                  value = 4 -> 1111  (all LEDs)
//
//              Values above 4 are clamped to 4 (all LEDs on) so the output is
//              always well defined.
//
// Target: Digilent Zybo Z7-20, drives led[3:0] from the master XDC.
//////////////////////////////////////////////////////////////////////////////////

module led_bar (
    input  wire [2:0] value,   // level to display, expected 0..4
    output reg  [3:0] led      // thermometer-coded LED outputs
);

    always @(*) begin
        case (value)
            3'd0:    led = 4'b0000;
            3'd1:    led = 4'b0001;
            3'd2:    led = 4'b0011;
            3'd3:    led = 4'b0111;
            default: led = 4'b1111;   // 4 and above -> all LEDs on
        endcase
    end

endmodule
