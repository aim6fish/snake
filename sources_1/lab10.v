 `timescale 1ns / 1ps

module lab10(
input  clk,
input  reset_n,
input  [3:0] usr_sw,
input  [3:0] usr_btn,
output [3:0] usr_led,
input uart_rx,
output uart_tx,

// VGA specific I/O ports
output VGA_HSYNC,
output VGA_VSYNC,
output [3:0] VGA_RED,
output [3:0] VGA_GREEN,
output [3:0] VGA_BLUE
);

// Declare system variables
reg  [40:0] snake_clock, barrier_clock;
wire [9:0]  pos;
wire [5:0] dir;
wire       snake_region, dead_region, snake_body_region, barrier_region1, score_region, score_region2;
wire barrier_ctrl, background_ctrl;

// declare SRAM control signals
wire [17:0] sram_addr0, sram_addr1, sram_addr2, sram_addr3, sram_addr4, sram_addr5, sram_addr6;
wire [11:0] data_in;
wire [11:0] data_out0, data_out1, data_out2, data_out3, data_out4, data_out5, data_out6;
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
         // synchronization signals to the display device.

wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
         // based for the new coordinate (pixel_x, pixel_y)

wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)

reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel

// Application-specific VGA signals
reg  [17:0] pixel_addr0, pixel_addr1, pixel_addr2, pixel_addr3, pixel_addr4, pixel_addr5, pixel_addr6;

reg [3:0] P = 0, P_next, B = 0, B_next;
localparam [3:0] S_MAIN_INIT = 0, S_MAIN_RIGHT = 1, S_MAIN_UP = 2, S_MAIN_DOWN = 3, S_MAIN_LEFT = 4;
localparam [1:0] B_MAIN_STAY = 0, B_MAIN_MOVE = 1;

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height
localparam SNAKE_BODY_SIZE = 10;
reg [4:0] snake_length = 3;
reg [11:0] SNAKE_BODY_X [0:15];
reg [11:0] SNAKE_BODY_Y [0:15];
// Set parameters for the fish images
wire [11:0] SNAKE_VPOS; // Vertical location of the fish in the sea image.
localparam SNAKE_W      = 10; // Width of the fish.
localparam SNAKE_H      = 10; // Height of the fish.
localparam BARRIER_W    = 20;
localparam BARRIER_H    = 10;
wire [11:0] BARRIER_X   ;
localparam BARRIER_Y    = 80;
reg [17:0] snake_addr = 0;   // Address array for up to 8 fish images.
reg [17:0] snake_addr2 = 0;
// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
//since there's only two picture, and no GIF problems
// Instiantiate the VGA sync signal generator
vga_sync vs0( .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC), .visible(video_on), .p_tick(pixel_tick), .pixel_x(pixel_x), .pixel_y(pixel_y) );
clk_divider#(2) clk_divider0( .clk(clk), .reset(~reset_n), .clk_out(vga_clk) );

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram0 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H))
       ram0 (.clk(clk), .we(sram_we), .en(sram_en),
       .addr(sram_addr0), .data_i(data_in), .data_o(data_out0));
sram1 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(SNAKE_W*SNAKE_H))
       ram1 (.clk(clk), .we(sram_we), .en(sram_en),
       .addr(sram_addr1), .data_i(data_in), .data_o(data_out1));    
sram2 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(201*144))
       ram2 (.clk(clk), .we(sram_we), .en(sram_en),
       .addr(sram_addr2), .data_i(data_in), .data_o(data_out2));
sram3 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(SNAKE_W*SNAKE_H))
       ram3 (.clk(clk), .we(sram_we), .en(sram_en),
       .addr(sram_addr3), .data_i(data_in), .data_o(data_out3));
sram4 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(BARRIER_W*BARRIER_H))
       ram4 (.clk(clk), .we(sram_we), .en(sram_en),
       .addr(sram_addr4), .data_i(data_in), .data_o(data_out4));
sram5 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(15*25*10))
       ram5 (.clk(clk), .we(sram_we), .en(sram_en),
       .addr(sram_addr5), .data_i(data_in), .data_o(data_out5));
sram5 #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(15*25*10))
       ram6 (.clk(clk), .we(sram_we), .en(sram_en),
       .addr(sram_addr6), .data_i(data_in), .data_o(data_out6));

assign sram_we = usr_sw[0]; // In this demo, we do not write the SRAM. However, if you set 'sram_we' to 0, Vivado fails to synthesize ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr0 = pixel_addr0;
assign sram_addr1 = pixel_addr1;
assign sram_addr2 = pixel_addr2;
assign sram_addr3 = pixel_addr3;
assign sram_addr4 = pixel_addr4;
assign sram_addr5 = pixel_addr5;
assign sram_addr6 = pixel_addr6;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------
// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;
// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
reg [40:0] snake_head_y1;
assign pos = snake_clock[33:23]; // the x position of the right edge of the fish image in the 640x480 VGA screen
assign SNAKE_VPOS = snake_head_y1[33:23];
reg [31:0] counter_head;
reg dead = 0;
reg [12:0] score_addr [0:7];
reg [4:0] score_val = 0;
reg [4:0] score_val2 = 0;

assign BARRIER_X = barrier_clock[33:23];

reg right = 1;
initial begin
   right = 1;
   barrier_clock = 0;
   barrier_clock[33:23] = 80;
end
always @(posedge clk) begin
   if( ~reset_n) barrier_clock[33:23] = 80;
   if( B == B_MAIN_STAY) barrier_clock <= barrier_clock;
   else if( B == B_MAIN_MOVE) begin
       if(right) barrier_clock <= barrier_clock + 4;
       else barrier_clock <= barrier_clock - 4;
       if(barrier_clock[33:23] > 632 && right) right <= 0;
       else if(barrier_clock[33:23] < 50 && !right) right <= 1;
   end
end

initial begin
   snake_head_y1=0;
   snake_head_y1[33:23]=200;
   snake_clock=0;
   snake_clock[33:23]=100;
   counter_head <= 0;
end
assign usr_led = counter_head[23:20];
reg turn = 0;
initial begin
   score_addr[0] = 0;
   score_addr[1] = 15*25;
   score_addr[2] = 15*25*2;
   score_addr[3] = 15*25*3;
   score_addr[4] = 15*25*4;
   score_addr[5] = 15*25*5;
   score_addr[6] = 15*25*6;
   score_addr[7] = 15*25*7;
   score_addr[8] = 15*25*8;
   score_addr[9] = 15*25*9;
end

assign usr_led = counter_head[23:20];

always @(posedge clk) begin
   if( ~reset_n)begin
       snake_head_y1 <= 0;
       snake_head_y1[33:23] <= 100;
       dead <= 0;
       snake_clock <= 0;
       snake_clock[33:23] <= 100;
       counter_head <= 0;
       end
   else begin
       if(counter_head >50000000)begin
           counter_head <= 0;
           if( P == S_MAIN_INIT ) snake_clock <= snake_clock;
           else if( P == S_MAIN_RIGHT && snake_clock[33:23] >= 312*2 - 5) dead <= 1;
           else if( P == S_MAIN_RIGHT ) snake_clock[33:23] <= snake_clock[33:23] + 20;
           else if( P == S_MAIN_LEFT && snake_clock[33:23] <= SNAKE_W + 35) dead <= 1;
           else if( P == S_MAIN_LEFT && snake_clock[33:23] > 0) snake_clock[33:23] <= snake_clock[33:23] - 20;
           else if( P == S_MAIN_DOWN && snake_head_y1[33:23] >= 230 - SNAKE_H) dead <= 1;
           else if( P == S_MAIN_DOWN) snake_head_y1[33:23] <= snake_head_y1[33:23] + 10;
           else if( P == S_MAIN_UP && snake_head_y1[33:23] <= 39) dead <= 1;
           else if( P == S_MAIN_UP) snake_head_y1[33:23] <= snake_head_y1[33:23] - 10;
           end
       else counter_head <= counter_head + 1;
       end
end

always @(posedge clk)
   if (!reset_n) begin P <= S_MAIN_INIT; B <= B_MAIN_STAY; end
   else begin P <= P_next; B <= B_next; end

move m (clk, !reset_n, uart_rx, uart_tx, dir, background_ctrl, barrier_ctrl);

always@(*)begin
   case (B)
   B_MAIN_STAY:
       if(barrier_ctrl) B_next = B_MAIN_MOVE;
       else B_next = B_MAIN_STAY;
   B_MAIN_MOVE:
       if(barrier_ctrl) B_next = B_MAIN_STAY;
       else B_next = B_MAIN_MOVE;
   endcase
end

always@(*)begin
   case (P)
   S_MAIN_INIT:
       if (dir == 3) P_next = S_MAIN_RIGHT;
       else if (dir == 2) P_next = S_MAIN_LEFT;
       else if (dir == 1) P_next = S_MAIN_DOWN;
       else if (dir == 0) P_next = S_MAIN_UP;
       else P_next = S_MAIN_INIT;
   S_MAIN_RIGHT:
       if (dir == 0) P_next = S_MAIN_UP;
       else if (dir == 1) P_next = S_MAIN_DOWN;
       else P_next = S_MAIN_RIGHT;
   S_MAIN_LEFT:
       if (dir == 1) P_next = S_MAIN_DOWN;
       else if (dir == 0) P_next = S_MAIN_UP;
       else P_next = S_MAIN_LEFT;
   S_MAIN_UP:
       if(dir == 2) P_next = S_MAIN_LEFT;
       else if(dir == 3) P_next = S_MAIN_RIGHT;
       else P_next = S_MAIN_UP;
   S_MAIN_DOWN:
       if (dir == 3) P_next = S_MAIN_RIGHT;
       else if (dir == 2) P_next = S_MAIN_LEFT;
       else P_next = S_MAIN_DOWN;
   endcase
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg [20:0] food_clk = 100;
wire [9:0] food_x, food_y;
wire food_gen, food_valid, food_eat, food_region;
wire [15:0] on_body;
foodgen fg (clk, !reset_n, food_gen, food_clk, food_x, food_y);
always @(posedge clk)
  if (food_gen) food_clk[20:0] <= food_clk[20:0] ^ (snake_clock[20:0] + snake_head_y1[31:11]);
  else food_clk <= food_clk+1;
assign food_gen = (!reset_n) || food_eat || on_body;
assign food_eat = (pos >= food_x-12) && (pos-20 <= food_x) && ((SNAKE_VPOS<<1)+20 >= food_y) && ((SNAKE_VPOS<<1) <= food_y+12);
assign food_region = (!on_body) && (pixel_x <= food_x) && (pixel_x > food_x-12) &&
                  (pixel_y >= food_y) && (pixel_y < food_y+12);
genvar idx;
for (idx = 15;idx >= 1;idx = idx-1)
 begin
   assign on_body[idx] = (idx < snake_length) &&
               (SNAKE_BODY_X[idx] >= food_x-12) && (SNAKE_BODY_X[idx]-20 <= food_x) &&
               ((SNAKE_BODY_Y[idx]<<1)+20 >= food_y) && ((SNAKE_BODY_Y[idx]<<1) <= food_y+12);
 end
assign on_body[0] = 0;
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// End of the animation clock code.
// ------------------------------------------------------------------------
// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.

reg [35:0] counter_body;
integer counterl;
initial begin
   SNAKE_BODY_Y[0] <= 100;
   SNAKE_BODY_X[0] <= 80;
end
always @ (posedge clk) begin
   if(~reset_n) begin
       SNAKE_BODY_Y[0] <= 100;
       SNAKE_BODY_X[0] <= 80;
       counter_body <= 0;
       for(counterl = 15/*snake_length*/; counterl >=1 ; counterl = counterl - 1)begin
           if(counterl < snake_length) begin
               SNAKE_BODY_Y[counterl] <= SNAKE_BODY_Y[counterl - 1];
               SNAKE_BODY_X[counterl] <= SNAKE_BODY_X[counterl - 1];
               end
           else begin
               SNAKE_BODY_Y[counterl] <= VBUF_H<<1;
               SNAKE_BODY_X[counterl] <= 0;
               end
       end
       end
   else if(counter_body <= 50000000) counter_body <= counter_body + 1 ;
   else if(P!=S_MAIN_INIT) begin
       for(counterl = 15/*snake_length*/; counterl >=1 ; counterl = counterl - 1)begin
           if(counterl < snake_length) begin
               SNAKE_BODY_Y[counterl] <= SNAKE_BODY_Y[counterl - 1];
               SNAKE_BODY_X[counterl] <= SNAKE_BODY_X[counterl - 1];
               end
       end
       SNAKE_BODY_Y[0] <= SNAKE_VPOS;
       SNAKE_BODY_X[0] <= pos ;
       counter_body <= 0;
       end
end
reg flag = 0;
reg [25:0] buff = 0;
always @ (posedge clk) begin
   if(~reset_n) begin
       snake_length <= 3;
       flag <= 0;
       score_val <= 0;
       score_val2 <= 0;
       buff <= 0;
   end    
   else if(food_eat && snake_length < 15 && buff > 10000000) begin
       snake_length <= snake_length + 1;
       score_val2 <= (score_val>=9) ? score_val2 + 1 : score_val2;
       score_val <= (score_val>=9) ? 0 : score_val + 1;
       flag <= 1;
       buff <= 0;
   end    
   else if(snake_length>=15) begin
       snake_length <= snake_length;
   end
   if(buff <= 10000000) buff <= buff + 1;
end
assign snake_region =
pixel_y >= (SNAKE_VPOS<<1) && pixel_y < (SNAKE_VPOS+SNAKE_H)<<1 &&
(pixel_x + 19) >= pos && pixel_x < pos + 1;

assign snake_body_region =
pixel_y >= (SNAKE_BODY_Y[0]<<1) && pixel_y < (SNAKE_BODY_Y[0]+SNAKE_H)<<1 &&
(pixel_x + 19) >= SNAKE_BODY_X[0] && pixel_x < SNAKE_BODY_X[0] + 1;

assign score_region = 
pixel_y >= 6 && pixel_y <= 56 && pixel_x >= 555 && pixel_x <= 585;
assign score_region2 = 
pixel_y >= 6 && pixel_y <= 56 && pixel_x >= 520 && pixel_x <= 550;

reg [15:0] snk_bd_region = 0;
integer i;
always @ (*) begin
   for(i = 15; i >= 1 ; i = i - 1) begin
       if(i<snake_length)
           snk_bd_region[i] = pixel_y >= (SNAKE_BODY_Y[i]<<1) && pixel_y < (SNAKE_BODY_Y[i]+SNAKE_H)<<1 &&
           (pixel_x + 19) >= SNAKE_BODY_X[i] && pixel_x < SNAKE_BODY_X[i] + 1;
       end
end

assign dead_region =
pixel_y >= 96 && pixel_y <= 384 && pixel_x >= 120 && pixel_x <= 522; //

assign barrier_region1 =
pixel_y >= (BARRIER_Y<<1) && pixel_y < (BARRIER_Y+BARRIER_H)<<1 &&
(pixel_x + 39) >= BARRIER_X && pixel_x < BARRIER_X + 1;

reg dead2 = 0;
always @ (posedge clk) begin
   if(~reset_n) dead2 <= 0;
   else if((barrier_region1 && snk_bd_region) || (barrier_region1 && snake_region)||(snk_bd_region && snake_region)) dead2 <= 1;
end
//||(snk_bd_region && barrier_region1)
reg dead_snake = 0;
reg [5:0] counter_print;
integer j;

always @ (posedge clk) begin
if (~reset_n) begin
   pixel_addr0 <= 0;
   pixel_addr1 <= 0;
   pixel_addr2 <= 0;
   pixel_addr3 <= 0;
   pixel_addr4 <= 0;
   end
else begin
   if (snake_region) begin
       pixel_addr1 <= snake_addr +
           ((pixel_y>>1)-SNAKE_VPOS)*SNAKE_W +
           ((pixel_x +(SNAKE_W*2-1)-pos)>>1);
     
       pixel_addr0 <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
       end
   else if (snake_body_region || snk_bd_region) begin
       for (j = 15/*snake_length*/; j >= 1 ; j = j - 1) begin
           if(j<snake_length) begin
               pixel_addr3 <= snake_addr +
                   ((pixel_y>>1)-SNAKE_BODY_Y[j])*SNAKE_BODY_SIZE +
                   ((pixel_x +(SNAKE_BODY_SIZE*2-1)-SNAKE_BODY_X[j])>>1);
                     
               pixel_addr0 <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
               end
           end
       end
   else if (barrier_region1) begin
       pixel_addr4 <= snake_addr +
           ((pixel_y>>1)-BARRIER_Y)*BARRIER_W +
           ((pixel_x +(BARRIER_W*2-1)-BARRIER_X)>>1);
                         
       pixel_addr0 <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
       end
// Scale up a 320x240 image for the 640x480 display.
// (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
   pixel_addr0 <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
   pixel_addr2 <= (pixel_y - 96 >> 1) * 201 + (pixel_x - 120 >> 1);
   pixel_addr5 <= score_addr[score_val] + ((pixel_y - 6) >> 1) * 15 + ((pixel_x - 555) >> 1);
   pixel_addr6 <= score_addr[score_val2] + ((pixel_y - 6) >> 1) * 15 + ((pixel_x - 520) >> 1);
   end
end
// End of the AGU code.
// ------------------------------------------------------------------------
// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) if (pixel_tick) rgb_reg <= rgb_next;

reg black = 0;
always @(*) begin
   if(background_ctrl) black = ~black;
end

always @(*) begin
   if (~video_on) rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
   else if(dead || dead2) begin
           if(dead_region) begin
               if(data_out2 == 12'h0f0) rgb_next <= 12'h000;
               else rgb_next <= data_out2;
           end
           else rgb_next <= 12'h000;
   end
   else begin
       if(snake_region) rgb_next = data_out1;
       else if (food_region) rgb_next = 12'hf0f;
       else if(snake_body_region || snk_bd_region) rgb_next = 12'hff0;
       else if(barrier_region1) rgb_next = data_out4;
       else if(score_region2) rgb_next = data_out6;
       else if(score_region) rgb_next = data_out5;
       else if(black) rgb_next = 12'hfff; // RGB value at (pixel_x, pixel_y)
       else rgb_next <= data_out0;
   end
end
// End of the video data display code.
// ------------------------------------------------------------------------
endmodule