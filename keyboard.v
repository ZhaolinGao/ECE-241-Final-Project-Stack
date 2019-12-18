
module keyboard (
	// Inputs
	CLOCK_50,
	KEY,

	// Bidirectionals
	PS2_CLK,
	PS2_DAT,
	
	// Outputs
	HEX0,
	HEX1,
	HEX2,
	HEX3,
	HEX4,
	HEX5,
	HEX6,
	HEX7,
	LEDR
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/

// Inputs
input				CLOCK_50;
input		[3:0]	KEY;

// Bidirectionals
inout				PS2_CLK;
inout				PS2_DAT;

// Outputs
output		[6:0]	HEX0;
output		[6:0]	HEX1;
output		[6:0]	HEX2;
output		[6:0]	HEX3;
output		[6:0]	HEX4;
output		[6:0]	HEX5;
output		[6:0]	HEX6;
output		[6:0]	HEX7;
output  		reg[9:0] LEDR = 10'b0;

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/

// Internal Wires
wire		[7:0]	ps2_key_data;
wire				ps2_key_pressed;
wire resetn;
wire left_drop;
wire right_drop;
wire left_control_speed;
wire right_control_speed;
// Internal Registers
reg			[7:0]	last_data_received;

// State Machine Registers

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/


/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/

always @(posedge CLOCK_50)
begin
	if (KEY[0] == 1'b0)
		last_data_received <= 8'h00;
	else if (ps2_key_pressed == 1'b1)
		last_data_received <= ps2_key_data;
end

/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/

assign HEX2 = 7'h7F;
assign HEX3 = 7'h7F;
assign HEX4 = 7'h7F;
assign HEX5 = 7'h7F;
assign HEX6 = 7'h7F;
assign HEX7 = 7'h7F;

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/
 
 
PS2_Controller PS2 (
	// Inputs
	.CLOCK_50				(CLOCK_50),
	.reset				(~KEY[0]),

	// Bidirectionals
	.PS2_CLK			(PS2_CLK),
 	.PS2_DAT			(PS2_DAT),

	// Outputs
	.received_data		(ps2_key_data),
	.received_data_en	(ps2_key_pressed)
);

Hexadecimal_To_Seven_Segment Segment0 (
	// Inputs
	.hex_number			(last_data_received[3:0]),

	// Bidirectional

	// Outputs
	.seven_seg_display	(HEX0)
);

Hexadecimal_To_Seven_Segment Segment1 (
	// Inputs
	.hex_number			(last_data_received[7:4]),

	// Bidirectional

	// Outputs
	.seven_seg_display	(HEX1)
);

translator t0(
	.clk(CLOCK_50), 
	.command(last_data_received),
	.pressing(ps2_key_pressed),
	.reset(resetn), 
	.start(start), 
	.left_drop(left_drop), 
	.right_drop(right_drop), 
	.left_control_speed(left_control_speed), 
	.right_control_speed(right_control_speed));
	
//assign LEDR[9] = resetn;
//assign LEDR[8] = start;
//assign LEDR[7] = left_drop;
//assign LEDR[6] = right_drop;
//assign LEDR[5] = left_control_speed;
//assign LEDR[4] = right_control_speed;
//assign LEDR[3] = ps2_key_pressed;

	
always@(posedge CLOCK_50) begin
	if(resetn) LEDR[9] <= 1;
	else LEDR[9] <= 0;
	
	if(start) LEDR[8] <= 1;
	else LEDR[8] <= 0;
	
	if(left_drop) LEDR[7] <= 1;
	else LEDR[7] <= 0;
	
	if(right_drop) LEDR[6] <= 1;
	else LEDR[6] <= 0;
	
	if(left_control_speed) LEDR[5] <= 1;
	else LEDR[5] <= 0;
	
	if(right_control_speed) LEDR[4] <= 1;
	else LEDR[4] <= 0;
//	if(ps2_key_pressed) LEDR[3] <= 1;
end


endmodule
