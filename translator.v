module translator(clk, command,pressing,reset, start, left_drop, right_drop, left_control_speed, right_control_speed);
	input [7:0]command;
	input pressing;
	input clk;
	output reg reset, start, left_drop, right_drop, left_control_speed, right_control_speed;
	
//	reg orderSent = 0;
	reg [2:0] current = s_initial;
	reg [2:0] next;
	localparam  s_initial = 3'b000, s_load = 3'b001, s_wait = 3'b010, s_reset = 3'b100;
					
	
	always@(*)
	begin
		case(current)
		s_initial: next = pressing?s_load:s_initial;							
		s_load: next = (command == 8'b11110000)?s_wait:s_load;
		s_wait: next = (command == 8'b11110000)?s_wait:s_reset;
		s_reset: next = pressing?s_reset:s_initial;
		default next = s_initial;
		endcase
	end
	
	
	
	
	always@(*)
	begin
//		
//		reset = 0;
//		left_drop = 0;
//		left_control_speed = 0;
//		right_drop = 0;
//		right_control_speed = 0;
//		start = 0;
		
		case(current)
		
		s_initial: begin 
//			orderSent <= 0; 
			reset <= 0;
			left_drop <= 0;
			left_control_speed <= 0;
			right_drop <= 0;
			right_control_speed <= 0;
			start <= 0;
		end
		
		s_load: begin
//			orderSent = 1;
			if(command == 8'h76)  begin reset <= 1'b1; left_drop <= 1'b0; left_control_speed <= 1'b0; right_drop <= 1'b0; right_control_speed <= 1'b0;start <= 1'b0;end //reset (Esc)
			else if(command == 8'h1b) begin left_drop <= 1'b1; reset <= 1'b0; left_control_speed <= 1'b0; right_drop <= 1'b0; right_control_speed <= 1'b0;start <= 1'b0; end // left drop (S)
			else if(command == 8'h1c) begin left_control_speed <= 1'b1; reset <= 1'b0; left_drop <= 1'b0; right_drop <= 1'b0; right_control_speed <= 1'b0;start <= 1'b0; end //left control speed (A)
			else if(command == 8'h73) begin right_drop <= 1'b1; reset <= 1'b0; left_drop <= 1'b0; left_control_speed <= 1'b0;right_control_speed <= 1'b0;start <= 1'b0; end // right drop (5)
			else if(command == 8'h6b) begin right_control_speed <= 1'b1; reset <= 1'b0; left_drop <= 1'b0; left_control_speed <= 1'b0; right_drop <= 1'b0;start <= 1'b0;end // right control speed (4)
			else if(command == 8'h5a) begin start <= 1'b1; reset <= 1'b0; left_drop <= 1'b0; left_control_speed <= 1'b0; right_drop <= 1'b0; right_control_speed <= 1'b0;end // start and restart (enter)
			else begin reset <= 1'b0; left_drop <= 1'b0; left_control_speed <= 1'b0; right_drop <= 1'b0; right_control_speed <= 1'b0;start <= 1'b0; end
		end
		
//		s_load: begin
////			orderSent = 1;
//			if(command == 8'h76)  begin reset <= 1'b1; end //reset (Esc)
//			else if(command == 8'h1b) begin left_drop <= 1'b1;  end // left drop (S)
//			else if(command == 8'h1c) begin left_control_speed <= 1'b1;  end //left control speed (A)
//			else if(command == 8'h73) begin right_drop <= 1'b1; end // right drop (5)
//			else if(command == 8'h6b) begin right_control_speed <= 1'b1; end // right control speed (4)
//			else if(command == 8'h5a) begin start <= 1'b1;end // start and restart (enter)
//		end
		
		s_wait: ;
		
		s_reset: begin
			reset <= 0;
			left_drop <= 0;
			left_control_speed <= 0;
			right_drop <= 0;
			right_control_speed <= 0;
			start <= 0;
		end
		
		endcase
	end
	
	always@(posedge clk) begin current <= next; end
	
endmodule 