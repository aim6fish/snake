`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/30 11:33:06
// Design Name: 
// Module Name: move
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

module move (input clk, reset,input rx, output tx, output reg [5:0] dir, output background, barrier_control);

reg [2:0] d, d_next;

localparam [2:0] D_INIT = 0, D_GET = 1;
localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1, S_UART_SEND = 2, S_UART_INCR = 3;
localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz

wire print_enable, print_done;
reg [1:0] Q, Q_next;
reg [$clog2(INIT_DELAY):0] init_counter;


wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
wire [7:0] tx_byte;
wire [7:0] echo_key; // keystrokes to be echoed to the terminal
wire is_num_key;
wire is_receiving;
wire is_transmitting;
wire recv_error;

uart uart(
  .clk(clk),
  .rst(reset),
  .rx(rx),
  .tx(tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);

always @(posedge clk)
    if (reset)
        d <= D_INIT;
    else if (d == D_INIT && init_counter < INIT_DELAY)
        d <= D_INIT;
    else
        d <= D_GET;
        
always @(posedge clk)
    if (reset)
        dir <= 7;
    else if(received)
        //else 
        case (rx_byte)
            "w": dir <= 0;
            "s": dir <= 1;
            "a": dir <= 2;
            "d": dir <= 3;
            default: dir <= dir;
        endcase

assign background = (received && (rx_byte == "b"));
assign barrier_control = (received && (rx_byte == "k"));

assign transmit = 0;
assign tx_byte = 0;

always @(posedge clk) begin
    if (d == D_INIT) init_counter <= init_counter + 1;
      else init_counter <= 0;
    end


always @(posedge clk) begin
  rx_temp <= (received)? rx_byte : 8'h0;
end

assign print_enable = 0;

endmodule
