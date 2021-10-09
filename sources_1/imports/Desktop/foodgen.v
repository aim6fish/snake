`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/01/01 15:01:14
// Design Name: 
// Module Name: foodgen
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


module foodgen( input clk, reset, gen, input [20:0] cnt, output reg [9:0] x = 552, y = 350
    );

reg p, p_next;

always @(posedge clk)
    if (p == 1)
    begin
        if (cnt[9:0] < 6+20) x <= 640-cnt[9:0]-8;
        else if (cnt[9:0] > 640-8) x <= cnt[9:0]-(640-8)+6+20;
        else x <= cnt[9:0];
        
        if (cnt[18:10] < 58) y <= 480-10-cnt[18:10]-50;
        else if (cnt[18:10] > 480-40) y <= 58+(cnt[18:10]-440);
        else y <= cnt[18:10];
    end

always @(posedge clk)
    if (reset)
      begin
        p <= 0; p_next <= 0;
      end
    else
      begin
        p <= p_next; p_next <= (gen);
      end
endmodule
