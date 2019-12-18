module frame_counter(
	input clk,
	input resetn,
	input [25:0] frequency,
	
	output reg refresh
	);
	
	reg [25:0] counter;
	
	always@(posedge clk) begin
		if (!resetn) begin
			counter <= frequency;
			refresh <= 1'b0;
			end
		else if (counter == 26'b0) begin
			refresh <= 1'b1;
			counter <= frequency;
			end
		else begin 
			refresh <= 1'b0;
			counter <= counter - 1'b1;
			end
	end
	
endmodule

module control(
	input drop, //~KEY[1]
	input clk, 
	input resetn, start_game, //KEY[0], ~KEY[3]
	input done, //handshake from draw module
	input control_speed,
	
	output reg clear_current, clear_all, draw_rectangle, draw_start, draw_line, draw_number, draw_gameover,//commands
	
	output reg [3:0] color_code, //color to draw
	output reg [6:0] Y, 
	output reg [7:0] X, //location of the top left of the rectangle/score to draw 
	output reg [7:0] L, //rectangle length
	output reg [3:0] score_to_draw, //score to draw
	output 	   [2:0] LEDR); //FSM
	
	//control variables
	reg [3:0] 	current_state = 4'b0000, next_state;
	reg [0:0] 	done_cut = 1'b0, 
				done_movedown = 1'b0, 
				done_draw_start = 1'b0, 
				done_draw_gameover = 1'b0,
				done_reset_variable = 1'b0,
				done_draw_line = 1'b0,
				game_over = 1'b0,
				done_slide = 1'b0,
				done_update_score = 1'b0,
				done_clear_current = 1'b0,
				done_draw_rectangle = 1'b0;
	
	//debugger
	assign LEDR = current_state;
	
	//current block
	reg [7:0] X_c = 8'b00010100, L_c = 8'b00101000;
	reg [3:0] C_c = 4'b1100;
	
	//Blocks' locations below the current one
	reg [7:0] 	X_0 = 8'b00010100, X_1 = 8'b00010100, X_2 = 8'b00010100, 
				X_3 = 8'b00010100, X_4 = 8'b00010100, X_5 = 8'b00010100, 
				X_6 = 8'b00010100, X_7 = 8'b00010100, X_8 = 8'b00010100, 
				X_9 = 8'b00010100; 
				
	//Blocks' length below the current one
	reg [7:0] 	L_0 = 8'b00101000, L_1 = 8'b00101000, L_2 = 8'b00101000, 
				L_3 = 8'b00101000, L_4 = 8'b00101000, L_5 = 8'b00101000, 
				L_6 = 8'b00101000, L_7 = 8'b00101000, L_8 = 8'b00101000, 
				L_9 = 8'b00101000;
				
	//Blocks' color below the current one, 1100
	reg [3:0] 	c_0 = 4'b0000, c_1 = 4'b0001, c_2 = 4'b0010, 
				c_3 = 4'b0011, c_4 = 4'b0100, c_5 = 4'b0101, 
				c_6 = 4'b0110, c_7 = 4'b0111, c_8 = 4'b1000, 
				c_9 = 4'b1001; 
	
	//score on scoreboard
	reg [6:0] 	rank_1 = 7'b0, rank_2 = 7'b0, rank_3 = 7'b0,
				rank_4 = 7'b0, rank_5 = 7'b0;
	reg [3:0] 	rank_1_tens = 4'b0, rank_1_ones = 4'b0,
				rank_2_tens = 4'b0, rank_2_ones = 4'b0,
				rank_3_tens = 4'b0, rank_3_ones = 4'b0,
				rank_4_tens = 4'b0, rank_4_ones = 4'b0,
				rank_5_tens = 4'b0, rank_5_ones = 4'b0;
	
	localparam 	S_DRAW_START			= 5'b00000,
				S_RERANK				= 5'b00001,
				S_DRAW_SCORE_BOARD		= 5'b00010,
				S_DRAW_SCORE_BOARD_wait	= 5'b00011,
				S_RESET_VARIABLE		= 5'b00100,
				S_DRAW_LINE				= 5'b00101,
				S_MOVE_DOWN				= 5'b00110,
				S_UPDATE_SCORE			= 5'b00111,
				S_CLEAR_CURRENT			= 5'b01000,
				S_DRAW_CURRENT			= 5'b01001,
				S_DRAW_WAIT				= 5'b01010,
				S_DROP					= 5'b01011,
				S_CUT					= 5'b01100,
				S_GAMEOVER				= 5'b01101,
				S_GAMEOVER_WAIT			= 5'b01110,
				S_GAMEOVER_BEFORE_START = 5'b01111;
				
	//counters
	reg [4:0] movedown_counter = 5'b0;
	reg [4:0] score_board_counter = 5'b0;
	reg [0:0] direction;
	
	//game logistics
	reg [6:0] score = 7'b0;
	reg [3:0] tens = 4'b0, ones = 4'b0;
	reg [25:0] frequency = 26'b1011111010111100001000;
	
	//speed control
	wire frame_clk;
	frame_counter f0 (clk, resetn, frequency, frame_clk);
	reg go_redraw = 1'b0;
	
	//State Table
	always@(*)
	begin: state_table
		case (current_state)
		
			S_DRAW_START: 				next_state = done_draw_start ? S_RERANK : S_DRAW_START;
			S_RERANK: 					next_state = S_DRAW_SCORE_BOARD;
			S_DRAW_SCORE_BOARD: 		next_state = start_game ? S_DRAW_SCORE_BOARD_wait : S_DRAW_SCORE_BOARD;
			S_DRAW_SCORE_BOARD_wait: 	next_state = start_game ? S_DRAW_SCORE_BOARD_wait : S_RESET_VARIABLE;
			S_RESET_VARIABLE: 			next_state = done_reset_variable ? S_DRAW_LINE : S_RESET_VARIABLE;
			S_DRAW_LINE: 				next_state = done_draw_line ? S_MOVE_DOWN : S_DRAW_LINE;
			S_MOVE_DOWN: 				next_state = done_movedown ? S_UPDATE_SCORE : S_MOVE_DOWN;
			S_UPDATE_SCORE: 			next_state = done_update_score ? S_CLEAR_CURRENT : S_UPDATE_SCORE;
			S_CLEAR_CURRENT:			next_state = done_clear_current ? S_DRAW_CURRENT : S_CLEAR_CURRENT;
			S_DRAW_CURRENT: 			next_state = done_draw_rectangle ? S_DRAW_WAIT : S_DRAW_CURRENT;
			S_DRAW_WAIT:				case ({go_redraw, drop})
											2'b10: next_state = S_CLEAR_CURRENT;
											2'b01: next_state = S_DROP;
										default: next_state = S_DRAW_WAIT;
										endcase
			S_DROP: 					next_state = drop ? S_DROP : S_CUT;
			S_CUT:					 	next_state = game_over ? S_GAMEOVER : S_DRAW_LINE;
			S_GAMEOVER: 				next_state = done_draw_gameover ? S_GAMEOVER_WAIT : S_GAMEOVER;
			S_GAMEOVER_WAIT: 			next_state = start_game ? S_GAMEOVER_BEFORE_START : S_GAMEOVER_WAIT;
			S_GAMEOVER_BEFORE_START:	next_state = start_game ? S_GAMEOVER_BEFORE_START : S_DRAW_START;
			
		default: next_state = S_DRAW_START;
		endcase
	end
	
	always@(posedge clk) //clk
	begin: state_FFs
		//state transition
		if(!resetn) begin
			current_state <= S_DRAW_START;
			movedown_counter <= 5'b00000;
			score_board_counter <= 5'b0;
			
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_gameover <= 1'b0;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_slide <= 1'b0;
			done_update_score <= 1'b0;
			score <= 7'b0;
			frequency <= 26'b1011111010111100001000;
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_rectangle <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			draw_number <= 1'b0;
			draw_gameover <= 1'b0;
		end
		else begin
			current_state <= next_state;
		end
		
		//state actions
		if (current_state == S_DRAW_START) begin
		
			//draw the start screen
			
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_slide <= 1'b0;
			done_update_score <= 1'b0;
			done_draw_gameover <= 1'b0;
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_rectangle <= 1'b0;
			draw_line <= 1'b0;
			draw_number <= 1'b0;
			draw_gameover <= 1'b0;
			
			if (done == 1'b0) begin
				draw_start <= 1'b1;
				done_draw_start <= 1'b0;
			end
			else if (done == 1'b1) begin
				draw_start <= 1'b0;
				done_draw_start <= 1'b1;
			end
			
		end
		
		else if (current_state == S_RERANK) begin
			
			if (score >= rank_1) begin
				rank_1 <= score;
				rank_2 <= rank_1;
				rank_3 <= rank_2;
				rank_4 <= rank_3;
				rank_5 <= rank_4;
			end
			else if (score >= rank_2) begin
				rank_2 <= score;
				rank_3 <= rank_2;
				rank_4 <= rank_3;
				rank_5 <= rank_4;
			end
			else if (score >= rank_3) begin
				rank_3 <= score;
				rank_4 <= rank_3;
				rank_5 <= rank_4;
			end
			else if (score >= rank_4) begin
				rank_4 <= score;
				rank_5 <= rank_4;
			end
			else if (score >= rank_5) begin
				rank_5 <= score;
			end
		end
		
		else if (current_state == S_DRAW_SCORE_BOARD) begin
			//draw scoreboard
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_slide <= 1'b0;
			done_update_score <= 1'b0; 
			done_draw_rectangle <= 1'b0;
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_rectangle <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			
			if(rank_1 < 7'd10) begin rank_1_ones <= rank_1; rank_1_tens <= 4'b0; end
			else if (rank_1 >= 7'd10 && rank_1 < 7'd20) begin rank_1_ones <= rank_1 - 10; rank_1_tens <= 4'b0001; end
			else if (rank_1 >= 7'd20 && rank_1 < 7'd30) begin rank_1_ones <= rank_1 - 20; rank_1_tens <= 4'b0010; end
			else if (rank_1 >= 7'd30 && rank_1 < 7'd40) begin rank_1_ones <= rank_1 - 30; rank_1_tens <= 4'b0011; end
			else if (rank_1 >= 7'd40 && rank_1 < 7'd50) begin rank_1_ones <= rank_1 - 40; rank_1_tens <= 4'b0100; end
			else if (rank_1 >= 7'd50 && rank_1 < 7'd60) begin rank_1_ones <= rank_1 - 50; rank_1_tens <= 4'b0101; end
			else if (rank_1 >= 7'd60 && rank_1 < 7'd70) begin rank_1_ones <= rank_1 - 60; rank_1_tens <= 4'b0110; end
			else if (rank_1 >= 7'd70 && rank_1 < 7'd80) begin rank_1_ones <= rank_1 - 70; rank_1_tens <= 4'b0111; end
			else if (rank_1 >= 7'd80 && rank_1 < 7'd90) begin rank_1_ones <= rank_1 - 80; rank_1_tens <= 4'b1000; end
			else if (rank_1 >= 7'd90 && rank_1 < 7'd100) begin rank_1_ones <= rank_1 - 90; rank_1_tens <= 4'b1001; end
			
			if(rank_2 < 7'd10) begin rank_2_ones <= rank_2; rank_2_tens <= 4'b0; end
			else if (rank_2 >= 7'd10 && rank_2 < 7'd20) begin rank_2_ones <= rank_2 - 10; rank_2_tens <= 4'b0001; end
			else if (rank_2 >= 7'd20 && rank_2 < 7'd30) begin rank_2_ones <= rank_2 - 20; rank_2_tens <= 4'b0010; end
			else if (rank_2 >= 7'd30 && rank_2 < 7'd40) begin rank_2_ones <= rank_2 - 30; rank_2_tens <= 4'b0011; end
			else if (rank_2 >= 7'd40 && rank_2 < 7'd50) begin rank_2_ones <= rank_2 - 40; rank_2_tens <= 4'b0100; end
			else if (rank_2 >= 7'd50 && rank_2 < 7'd60) begin rank_2_ones <= rank_2 - 50; rank_2_tens <= 4'b0101; end
			else if (rank_2 >= 7'd60 && rank_2 < 7'd70) begin rank_2_ones <= rank_2 - 60; rank_2_tens <= 4'b0110; end
			else if (rank_2 >= 7'd70 && rank_2 < 7'd80) begin rank_2_ones <= rank_2 - 70; rank_2_tens <= 4'b0111; end
			else if (rank_2 >= 7'd80 && rank_2 < 7'd90) begin rank_2_ones <= rank_2 - 80; rank_2_tens <= 4'b1000; end
			else if (rank_2 >= 7'd90 && rank_2 < 7'd100) begin rank_2_ones <= rank_2 - 90; rank_2_tens <= 4'b1001; end
			
			if(rank_3 < 7'd10) begin rank_3_ones <= rank_3; rank_3_tens <= 4'b0; end
			else if (rank_3 >= 7'd10 && rank_3 < 7'd20) begin rank_3_ones <= rank_3 - 10; rank_3_tens <= 4'b0001; end
			else if (rank_3 >= 7'd20 && rank_3 < 7'd30) begin rank_3_ones <= rank_3 - 20; rank_3_tens <= 4'b0010; end
			else if (rank_3 >= 7'd30 && rank_3 < 7'd40) begin rank_3_ones <= rank_3 - 30; rank_3_tens <= 4'b0011; end
			else if (rank_3 >= 7'd40 && rank_3 < 7'd50) begin rank_3_ones <= rank_3 - 40; rank_3_tens <= 4'b0100; end
			else if (rank_3 >= 7'd50 && rank_3 < 7'd60) begin rank_3_ones <= rank_3 - 50; rank_3_tens <= 4'b0101; end
			else if (rank_3 >= 7'd60 && rank_3 < 7'd70) begin rank_3_ones <= rank_3 - 60; rank_3_tens <= 4'b0110; end
			else if (rank_3 >= 7'd70 && rank_3 < 7'd80) begin rank_3_ones <= rank_3 - 70; rank_3_tens <= 4'b0111; end
			else if (rank_3 >= 7'd80 && rank_3 < 7'd90) begin rank_3_ones <= rank_3 - 80; rank_3_tens <= 4'b1000; end
			else if (rank_3 >= 7'd90 && rank_3 < 7'd100) begin rank_3_ones <= rank_3 - 90; rank_3_tens <= 4'b1001; end
			
			if(rank_4 < 7'd10) begin rank_4_ones <= rank_4; rank_4_tens <= 4'b0; end
			else if (rank_4 >= 7'd10 && rank_4 < 7'd20) begin rank_4_ones <= rank_4 - 10; rank_4_tens <= 4'b0001; end
			else if (rank_4 >= 7'd20 && rank_4 < 7'd30) begin rank_4_ones <= rank_4 - 20; rank_4_tens <= 4'b0010; end
			else if (rank_4 >= 7'd30 && rank_4 < 7'd40) begin rank_4_ones <= rank_4 - 30; rank_4_tens <= 4'b0011; end
			else if (rank_4 >= 7'd40 && rank_4 < 7'd50) begin rank_4_ones <= rank_4 - 40; rank_4_tens <= 4'b0100; end
			else if (rank_4 >= 7'd50 && rank_4 < 7'd60) begin rank_4_ones <= rank_4 - 50; rank_4_tens <= 4'b0101; end
			else if (rank_4 >= 7'd60 && rank_4 < 7'd70) begin rank_4_ones <= rank_4 - 60; rank_4_tens <= 4'b0110; end
			else if (rank_4 >= 7'd70 && rank_4 < 7'd80) begin rank_4_ones <= rank_4 - 70; rank_4_tens <= 4'b0111; end
			else if (rank_4 >= 7'd80 && rank_4 < 7'd90) begin rank_4_ones <= rank_4 - 80; rank_4_tens <= 4'b1000; end
			else if (rank_4 >= 7'd90 && rank_4 < 7'd100) begin rank_4_ones <= rank_4 - 90; rank_4_tens <= 4'b1001; end
			
			if(rank_5 < 7'd10) begin rank_5_ones <= rank_5; rank_5_tens <= 4'b0; end
			else if (rank_5 >= 7'd10 && rank_5 < 7'd20) begin rank_5_ones <= rank_5 - 10; rank_5_tens <= 4'b0001; end
			else if (rank_5 >= 7'd20 && rank_5 < 7'd30) begin rank_5_ones <= rank_5 - 20; rank_5_tens <= 4'b0010; end
			else if (rank_5 >= 7'd30 && rank_5 < 7'd40) begin rank_5_ones <= rank_5 - 30; rank_5_tens <= 4'b0011; end
			else if (rank_5 >= 7'd40 && rank_5 < 7'd50) begin rank_5_ones <= rank_5 - 40; rank_5_tens <= 4'b0100; end
			else if (rank_5 >= 7'd50 && rank_5 < 7'd60) begin rank_5_ones <= rank_5 - 50; rank_5_tens <= 4'b0101; end
			else if (rank_5 >= 7'd60 && rank_5 < 7'd70) begin rank_5_ones <= rank_5 - 60; rank_5_tens <= 4'b0110; end
			else if (rank_5 >= 7'd70 && rank_5 < 7'd80) begin rank_5_ones <= rank_5 - 70; rank_5_tens <= 4'b0111; end
			else if (rank_5 >= 7'd80 && rank_5 < 7'd90) begin rank_5_ones <= rank_5 - 80; rank_5_tens <= 4'b1000; end
			else if (rank_5 >= 7'd90 && rank_5 < 7'd100) begin rank_5_ones <= rank_5 - 90; rank_5_tens <= 4'b1001; end
			
			if (score_board_counter == 5'b0) begin
				X <= 8'd105;
				Y <= 7'd18;
				score_to_draw <= rank_1_tens;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b00001;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b00001) begin
				score_board_counter <= 5'b00010;
			end
			
			else if (score_board_counter == 5'b00010) begin
				X <= 8'd112;
				Y <= 7'd18;
				score_to_draw <= rank_1_ones;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b00011;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b00011) begin
				score_board_counter <= 5'b00100;
			end
			
			else if (score_board_counter == 5'b00100) begin
				X <= 8'd105;
				Y <= 7'd30;
				score_to_draw <= rank_2_tens;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b00101;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b00101) begin
				score_board_counter <= 5'b00110;
			end
			
			else if (score_board_counter == 5'b00110) begin
				X <= 8'd112;
				Y <= 7'd30;
				score_to_draw <= rank_2_ones;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b00111;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b00111) begin
				score_board_counter <= 5'b01000;
			end
			
			else if (score_board_counter == 5'b01000) begin
				X <= 8'd105;
				Y <= 7'd42;
				score_to_draw <= rank_3_tens;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b01001;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b01001) begin
				score_board_counter <= 5'b01010;
			end
			
			else if (score_board_counter == 5'b01010) begin
				X <= 8'd112;
				Y <= 7'd42;
				score_to_draw <= rank_3_ones;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b01011;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b01011) begin
				score_board_counter <= 5'b01100;
			end
			
			else if (score_board_counter == 5'b01100) begin
				X <= 8'd105;
				Y <= 7'd54;
				score_to_draw <= rank_4_tens;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b01101;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b01101) begin
				score_board_counter <= 5'b01110;
			end
			
			else if (score_board_counter == 5'b01110) begin
				X <= 8'd112;
				Y <= 7'd54;
				score_to_draw <= rank_4_ones;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b01111;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b01111) begin
				score_board_counter <= 5'b10000;
			end
			
			else if (score_board_counter == 5'b10000) begin
				X <= 8'd105;
				Y <= 7'd66;
				score_to_draw <= rank_5_tens;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b10001;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b10001) begin
				score_board_counter <= 5'b10010;
			end
			
			else if (score_board_counter == 5'b10010) begin
				X <= 8'd112;
				Y <= 7'd66;
				score_to_draw <= rank_5_ones;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b10011;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b10011) begin
				score_board_counter <= 5'b11111;
			end
		end
		
		else if (current_state == S_RESET_VARIABLE) begin
			
			score_board_counter <= 5'b0;
		
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b1;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_slide <= 1'b0;
			done_update_score <= 1'b0; 
			done_draw_gameover <= 1'b0;
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_rectangle <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			draw_number <= 1'b0;
			draw_gameover <= 1'b0;
			
			score <= 7'b0;
			
			//current block
			X_c <= 8'b00010100; 
			L_c <= 8'b00101000;
			C_c <= 4'b1100;
	
			//Blocks' locations below the current one
			X_0 <= 8'b00010100; X_1 <= 8'b00010100; X_2 <= 8'b00010100; 
			X_3 <= 8'b00010100; X_4 <= 8'b00010100; X_5 <= 8'b00010100; 
			X_6 <= 8'b00010100; X_7 <= 8'b00010100; X_8 <= 8'b00010100; 
			X_9 <= 8'b00010100; 
				
			//Blocks' length below the current one
			L_0 <= 8'b00101000; L_1 <= 8'b00101000; L_2 <= 8'b00101000; 
			L_3 <= 8'b00101000; L_4 <= 8'b00101000; L_5 <= 8'b00101000; 
			L_6 <= 8'b00101000; L_7 <= 8'b00101000; L_8 <= 8'b00101000; 
			L_9 <= 8'b00101000;
				
			//Blocks' color below the current one, 1100
			c_0 <= 4'b0000; c_1 <= 4'b0001; c_2 <= 4'b0010;
			c_3 <= 4'b0011; c_4 <= 4'b0100; c_5 <= 4'b0101; 
			c_6 <= 4'b0110; c_7 <= 4'b0111; c_8 <= 4'b1000; 
			c_9 <= 4'b1001; 
			
			frequency <= 26'b1011111010111100001000;
			
		end
		
		else if (current_state == S_DRAW_LINE) begin
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			game_over <= 1'b0;
			done_slide <= 1'b0;
			done_update_score <= 1'b0; 
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_rectangle <= 1'b0;
			draw_start <= 1'b0;
			draw_number <= 1'b0;
			
			if (!done) begin
				done_draw_line <= 1'b0;
				draw_line <= 1'b1;
			end
			else if (done) begin
				done_draw_line <= 1'b1;
				draw_line <= 1'b0;
			end
		end
		
		else if (current_state == S_MOVE_DOWN) begin
		
			done_cut <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_slide <= 1'b0;
			done_update_score <= 1'b0; 
			score_board_counter <= 5'b0;
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			draw_number <= 1'b0;
		
			if (movedown_counter == 5'b0) begin
				color_code <= c_1;
				X <= X_1;
				Y <= 7'b1110011;
				L <= L_1;
				X_0 <= X_1;
				L_0 <= L_1;
				c_0 <= c_1;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b00001;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b00001) begin
				movedown_counter <= 5'b00010;
			end
			
			else if (movedown_counter == 5'b00010) begin
				color_code <= c_2;
				X <= X_2;
				Y <= 7'b1101110;
				L <= L_2;
				X_1 <= X_2;
				L_1 <= L_2;
				c_1 <= c_2;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b00011;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b00011) begin
				movedown_counter <= 5'b00100;
			end
			
			else if (movedown_counter == 5'b00100) begin
				color_code <= c_3;
				X <= X_3;
				Y <= 7'b1101001;
				L <= L_3;
				X_2 <= X_3;
				L_2 <= L_3;
				c_2 <= c_3;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b00101;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b00101) begin
				movedown_counter <= 5'b00110;
			end
			
			else if (movedown_counter == 5'b00110) begin
				color_code <= c_4;
				X <= X_4;
				Y <= 7'b1100100;
				L <= L_4;
				X_3 <= X_4;
				L_3 <= L_4;
				c_3 <= c_4;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b00111;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b00111) begin
				movedown_counter <= 5'b01000;
			end
			
			else if (movedown_counter == 5'b01000) begin
				color_code <= c_5;
				X <= X_5;
				Y <= 7'b1011111;
				L <= L_5;
				X_4 <= X_5;
				L_4 <= L_5;
				c_4 <= c_5;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b01001;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b01001) begin
				movedown_counter <= 5'b01010;
			end
			
			else if (movedown_counter == 5'b01010) begin
				color_code <= c_6;
				X <= X_6;
				Y <= 7'b1011010;
				L <= L_6;
				X_5 <= X_6;
				L_5 <= L_6;
				c_5 <= c_6;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b01011;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b01011) begin
				movedown_counter <= 5'b01100;
			end
			
			else if (movedown_counter == 5'b01100) begin
				color_code <= c_7;
				X <= X_7;
				Y <= 7'b1010101;
				L <= L_7;
				X_6 <= X_7;
				L_6 <= L_7;
				c_6 <= c_7;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b01101;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b01101) begin
				movedown_counter <= 5'b01110;
			end
			
			else if (movedown_counter == 5'b01110) begin
				color_code <= c_8;
				X <= X_8;
				Y <= 7'b1010000;
				L <= L_8;
				X_7 <= X_8;
				L_7 <= L_8;
				c_7 <= c_8;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b01111;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b01111) begin
				movedown_counter <= 5'b10000;
			end
			
			else if (movedown_counter == 5'b10000) begin
				color_code <= c_9;
				X <= X_9;
				Y <= 7'b1001011;
				L <= L_9;
				X_8 <= X_9;
				L_8 <= L_9;
				c_8 <= c_9;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b10001;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b10001) begin
				movedown_counter <= 5'b10010;
			end
			
			else if (movedown_counter == 5'b10010) begin
				color_code <= C_c;
				X <= X_c;
				Y <= 7'b1000110;
				L <= L_c;
				X_9 <= X_c;
				L_9 <= L_c;
				c_9 <= C_c;
				draw_rectangle <= 1'b1;
				if (done) begin
					movedown_counter <= 5'b10011;
					draw_rectangle <= 1'b0;
				end
			end
			
			else if (movedown_counter == 5'b10011) begin
				movedown_counter <= 5'b10100;
			end
			
			else if (movedown_counter == 5'b10100) begin 
				movedown_counter <= 5'b0000;
				done_movedown <= 1'b1;
				
				//set up for slide
				X_c <= 8'b0;
				if (c_9 == 4'b1100 | c_9 == 4'b1011) begin
					C_c <= 4'b0;
				end
				else begin
					C_c <= c_9 + 1'b1;
				end
			end
		end
		
		else if (current_state == S_UPDATE_SCORE) begin
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_slide <= 1'b0;
			done_clear_current <= 1'b0;
			done_draw_rectangle <= 1'b0;
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_rectangle <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			
			if(score < 7'd10) begin ones <= score; tens <= 4'b0; end
			else if (score >= 7'd10 && score < 7'd20) begin ones <= score - 10; tens <= 4'b0001; end
			else if (score >= 7'd20 && score < 7'd30) begin ones <= score - 20; tens <= 4'b0010; end
			else if (score >= 7'd30 && score < 7'd40) begin ones <= score - 30; tens <= 4'b0011; end
			else if (score >= 7'd40 && score < 7'd50) begin ones <= score - 40; tens <= 4'b0100; end
			else if (score >= 7'd50 && score < 7'd60) begin ones <= score - 50; tens <= 4'b0101; end
			else if (score >= 7'd60 && score < 7'd70) begin ones <= score - 60; tens <= 4'b0110; end
			else if (score >= 7'd70 && score < 7'd80) begin ones <= score - 70; tens <= 4'b0111; end
			else if (score >= 7'd80 && score < 7'd90) begin ones <= score - 80; tens <= 4'b1000; end
			else if (score >= 7'd90 && score < 7'd100) begin ones <= score - 90; tens <= 4'b1001; end
			
			if (score_board_counter == 5'b0) begin
				X <= 0;
				Y <= 0;
				score_to_draw <= tens;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b00001;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b00001) begin
				score_board_counter <= 5'b00010;
			end
			
			else if (score_board_counter == 5'b00010) begin
				X <= 8'b111;
				Y <= 0;
				score_to_draw <= ones;
				draw_number <= 1'b1;
				if (done) begin
					score_board_counter <= 5'b00011;
					draw_number <= 1'b0;
				end
			end
			
			else if (score_board_counter == 5'b00011) begin
				score_board_counter <= 5'b00100;
			end
			
			else if (score_board_counter == 5'b00100) begin 
				score_board_counter <= 5'b0;
				done_update_score <= 1'b1;
			end
		end
		
		else if (current_state == S_CLEAR_CURRENT) begin
			
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_update_score <= 1'b0; 
			done_draw_rectangle <= 1'b0;
			
			clear_all <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			draw_number <= 1'b0;
			draw_rectangle <= 1'b0;
		
			L <= L_9;
			Y <= 7'b1000001;
			X <= X_c;
			color_code <= C_c;
			
			if (X_c == 8'b01001110 - L_9) begin
				direction <= 1'b1;
			end
			else if (X_c == 8'b0) begin
				direction <= 1'b0;
			end
			
			if (control_speed) begin
				frequency <= 26'b101111101011110000100;
			end
			else begin
				frequency <= 26'b1011111010111100001000;
			end
			
			if (!done) begin
				done_clear_current <= 1'b0;
				clear_current <= 1'b1;
			end
			else begin
				done_clear_current <= 1'b1;
				clear_current <= 1'b0;
				if (direction) begin
					X_c <= X_c - 1'b1;
				end
				else begin
					X_c <= X_c + 1'b1;
				end
			end
			
		end
		
		else if (current_state == S_DRAW_CURRENT) begin
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_line <= 1'b0;
			game_over <= 1'b0;
			done_update_score <= 1'b0; 
			done_clear_current <= 1'b0;
			
			clear_all <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			draw_number <= 1'b0;
			clear_current <= 1'b0;
		
			L <= L_9;
			Y <= 7'b1000001;
			X <= X_c;
			color_code <= C_c;
			
			if (!done) begin
				draw_rectangle <= 1'b1;
				done_draw_rectangle <= 1'b0;
			end
			else begin
				draw_rectangle <= 1'b0;
				done_draw_rectangle <= 1'b1;
				go_redraw <= 1'b0;
			end
		end
		
		else if (current_state == S_DRAW_WAIT) begin
			if (frame_clk) begin
				go_redraw <= 1'b1;
			end
		end
		
		else if (current_state == S_DROP) begin
			
			done_cut <= 1'b0;
			done_movedown <= 1'b0;
			done_draw_start <= 1'b0;
			done_reset_variable <= 1'b0;
			done_draw_line <= 1'b0;
			done_slide <= 1'b0;
			done_update_score <= 1'b0; 
			done_draw_gameover <= 1'b0;
			
			clear_current <= 1'b0;
			clear_all <= 1'b0;
			draw_rectangle <= 1'b0;
			draw_start <= 1'b0;
			draw_line <= 1'b0;
			draw_number <= 1'b0;
			draw_gameover <= 1'b0;
			
			//game logistics
			if (X_c > (X_9 + L_9) | (X_9 > L_9 & X_c < (X_9 - L_9))) begin
				game_over <= 1'b1;
			end
			
		end
		
		else if (current_state == S_CUT) begin
		
			//game logistics
			if (!(X_c > (X_9 + L_9) | (X_9 > L_9 & X_c < (X_9 - L_9)))) begin
				score <= score + 1'b1;
			end
			
			if (X_9 > X_c) begin
				L_c <= L_9 - (X_9 - X_c);
				X_c <= X_9;
			end
			else if (X_c > X_9) begin
				L_c <= L_9 - (X_c - X_9);
			end
			
		end
		
		else if (current_state == S_GAMEOVER) begin
			
			if (done == 1'b0) begin
				draw_gameover <= 1'b1;
				done_draw_gameover <= 1'b0;
			end
			else if (done == 1'b1) begin
				draw_gameover <= 1'b0;
				done_draw_gameover <= 1'b1;
			end
			
		end
	end
		
endmodule


module draw(
	input clk, //CLOCK_50
	input resetn, 
	input clear_current, clear_all, draw_rectangle, draw_start, draw_line, draw_number, draw_gameover,
	input [3:0] color_code, //color to draw
	input [6:0] Y, 
	input [7:0] X, //location of the top left of the rectangle to draw 
	input [7:0] L, //horizontal size of the rectangle
	input [3:0] score_to_draw,
	
	output reg writeEn,
	output reg [5:0] color_out,
	output reg [6:0] pos_Y,
	output reg [7:0] pos_X,
	output reg done);
	
	reg [7:0] horizontal_couter;
	reg [6:0] vertical_counter;
	
	parameter thickness = 4; //thickness of the block
	
	//mifs
	reg [14:0] start_address = 15'b0;
	reg [5:0] score_address = 6'b0;
	wire [5:0] start_color, gameover_color, score_color_0, score_color_1, score_color_2, score_color_3, score_color_4,
				score_color_5, score_color_6, score_color_7, score_color_8, score_color_9;
	
	reg [7:0] x_initial = 8'b0;
	reg [6:0] y_initial = 7'b0;
	
	start s0(start_address, clk, start_color);
	gameover (start_address, clk, gameover_color);
	score_0 (score_address, clk, score_color_0);
	score_1 (score_address, clk, score_color_1);
	score_2 (score_address, clk, score_color_2);
	score_3 (score_address, clk, score_color_3);
	score_4 (score_address, clk, score_color_4);
	score_5 (score_address, clk, score_color_5);
	score_6 (score_address, clk, score_color_6);
	score_7 (score_address, clk, score_color_7);
	score_8 (score_address, clk, score_color_8);
	score_9 (score_address, clk, score_color_9);
	
	always@(posedge clk) begin
	
		if (!resetn) begin
			
			writeEn <= 1'b0;
			horizontal_couter <= 8'b0;
			vertical_counter <= 7'b0;
			done <= 1'b0;
			start_address <= 15'b0;
			score_address <= 6'b10;
			x_initial <= 8'b0;
			y_initial <= 7'b0;
			
		end
		
		else if (!draw_gameover & !clear_current & !clear_all & !draw_rectangle & !draw_start & !draw_line & !draw_number) begin
			
			writeEn <= 1'b0;
			horizontal_couter <= 8'b0;
			vertical_counter <= 7'b0;
			done <= 1'b0;
			start_address <= 15'b0;
			score_address <= 6'b10;
			x_initial <= 8'b0;
			y_initial <= 7'b0;
			
		end
		
		else if (draw_rectangle) begin
			
			if (color_code == 4'b0) begin
				color_out <= 6'b110000;
			end
			else if (color_code == 4'b0001) begin
				color_out <= 6'b111000;
			end
			else if (color_code == 4'b0010) begin
				color_out <= 6'b111100;
			end
			else if (color_code == 4'b0011) begin
				color_out <= 6'b101100;
			end
			else if (color_code == 4'b0100) begin
				color_out <= 6'b001100;
			end
			else if (color_code == 4'b0101) begin
				color_out <= 6'b001110;
			end
			else if (color_code == 4'b0110) begin
				color_out <= 6'b001111;
			end
			else if (color_code == 4'b0111) begin
				color_out <= 6'b001011;
			end
			else if (color_code == 4'b1000) begin
				color_out <= 6'b000011;
			end
			else if (color_code == 4'b1001) begin
				color_out <= 6'b100011;
			end
			else if (color_code == 4'b1010) begin
				color_out <= 6'b110011;
			end
			else if (color_code == 4'b1011) begin
				color_out <= 6'b110010;
			end
			else if (color_code == 4'b1100) begin
				color_out <= 6'b111111;
			end
			
			writeEn <= 1'b1;
			if (horizontal_couter == L) begin
				horizontal_couter <= 8'b0;
				if (vertical_counter == thickness) begin
					vertical_counter <= 7'b0;
					done <= 1'b1;
				end
				else begin
					vertical_counter <= vertical_counter + 1'b1;
				end
			end
			else begin
				horizontal_couter <= horizontal_couter + 1;
			end
			
			pos_X <= X + horizontal_couter;
			pos_Y <= Y + vertical_counter;
			
		end
		
		else if (clear_current) begin
		
			color_out <= 6'b010101;
			writeEn <= 1'b1;
			if (horizontal_couter == L) begin
				horizontal_couter <= 8'b0;
				if (vertical_counter == thickness) begin
					vertical_counter <= 7'b0;
					done <= 1'b1;
				end
				else begin
					vertical_counter <= vertical_counter + 1'b1;
				end
			end
			else begin
				horizontal_couter <= horizontal_couter + 1;
			end
			
			pos_X <= X + horizontal_couter;
			pos_Y <= Y + vertical_counter;
			
		end
		
		else if (draw_line) begin
			
			writeEn <= 1'b1;
			if (horizontal_couter == 8'b10100000) begin
				horizontal_couter <= 8'b0;
				if (vertical_counter == 7'b1111000) begin
					vertical_counter <= 7'b0;
					done <= 1'b1;
				end
				else begin
					vertical_counter <= vertical_counter + 1'b1;
				end
			end
			else begin
				horizontal_couter <= horizontal_couter + 1;
			end
			
			if (horizontal_couter == 8'b01010000) begin
				color_out <= 6'b111111;
			end
			else begin
				color_out <= 6'b010101;
			end
			
			pos_X <= horizontal_couter;
			pos_Y <= vertical_counter;
			
		end
		
		else if (draw_start) begin
		
			writeEn <= 1'b1;
			
			if (horizontal_couter == 8'b10011111) begin
				horizontal_couter <= 8'b0;
				if (vertical_counter == 7'b1111000) begin
					vertical_counter <= 7'b0;
					done <= 1'b1;
				end
				else begin
					vertical_counter <= vertical_counter + 1'b1;
				end
			end
			else begin
				horizontal_couter <= horizontal_couter + 1;
			end
			
			color_out <= start_color;
			
			start_address <= start_address + 1'b1;
			pos_X <= horizontal_couter;
			pos_Y <= vertical_counter;
			
		end
		
		else if (draw_number) begin
			
			writeEn <= 1'b1;
			
			if(score_to_draw == 7'd0)begin
				color_out <= score_color_0;
			end
			else if(score_to_draw == 7'd1)begin
				color_out <= score_color_1;
			end
			else if(score_to_draw == 7'd2)begin
				color_out <= score_color_2;
			end
			else if(score_to_draw == 7'd3)begin
				color_out <= score_color_3;
			end
			else if(score_to_draw == 7'd4)begin
				color_out <= score_color_4;
			end
			else if(score_to_draw == 7'd5)begin
				color_out <= score_color_5;
			end
			else if(score_to_draw == 7'd6)begin
				color_out <= score_color_6;
			end
			else if(score_to_draw == 7'd7)begin
				color_out <= score_color_7;
			end
			else if(score_to_draw == 7'd8)begin
				color_out <= score_color_8;
			end
			else if(score_to_draw == 7'd9)begin
				color_out <= score_color_9;
			end
			
			if (horizontal_couter == 8'b110) begin
				horizontal_couter <= 8'b0;
				if (vertical_counter == 7'b1000) begin
					vertical_counter <= 7'b0;
					done <= 1'b1;
				end
				else begin
					vertical_counter <= vertical_counter + 1'b1;
				end
			end
			else begin
				horizontal_couter <= horizontal_couter + 1;
			end
			score_address <= score_address + 1'b1;
			pos_X <= X + horizontal_couter;
			pos_Y <= Y + vertical_counter;
			
		end
		
		else if (draw_gameover) begin
			writeEn <= 1'b1;
			
			if (horizontal_couter == 8'd78) begin
				horizontal_couter <= 8'b0;
				if (vertical_counter == 7'd119) begin
					vertical_counter <= 7'b0;
					done <= 1'b1;
				end
				else begin
					vertical_counter <= vertical_counter + 1'b1;
				end
			end
			else begin
				horizontal_couter <= horizontal_couter + 1;
			end
			
			color_out <= gameover_color;
			
			start_address <= start_address + 1'b1;
			pos_X <= 1'b1 + horizontal_couter;
			pos_Y <= vertical_counter;
		end
		
	end

	
endmodule

module GameModule
	(
		CLOCK_50,						//	On Board 50 MHz
		
		KEY,							// On Board Keys
		SW,
		LEDR,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input	[3:0]	KEY;
	input   [9:0]   SW;
	output  [9:0] 	LEDR;
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;			//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire [5:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 2;
		defparam VGA.BACKGROUND_IMAGE = "start.mif";
				
	wire done, clear_current, clear_all, draw_rectangle, draw_start, draw_line, draw_number, draw_gameover;
	wire [3:0] color_code;
	wire [6:0] Y;
	wire [3:0] score_to_draw;
	wire [7:0] X, L;
	
	control(
		.drop(~KEY[1]),
		.clk(CLOCK_50),
		.resetn(resetn),
		.start_game(~KEY[3]),
		.done(done),
		.control_speed(~KEY[2]),
		
		.clear_current(clear_current),
		.clear_all(clear_all),
		.draw_rectangle(draw_rectangle),
		.draw_start(draw_start),
		.draw_line(draw_line),
		.draw_number(draw_number),
		.draw_gameover(draw_gameover),
		
		.color_code(color_code),
		.Y(Y),
		.X(X),
		.L(L),
		.score_to_draw(score_to_draw),
		.LEDR(LEDR[2:0]));
			
	draw(
		.clk(CLOCK_50), //CLOCK_50
		.resetn(resetn),
		
		.clear_current(clear_current),
		.clear_all(clear_all),
		.draw_rectangle(draw_rectangle),
		.draw_start(draw_start),
		.draw_line(draw_line),
		.draw_number(draw_number),
		.draw_gameover(draw_gameover),
		
		.color_code(color_code),
		.Y(Y), 
		.X(X),
		.L(L),
		.score_to_draw(score_to_draw),
	
		.writeEn(writeEn),
		.color_out(colour),
		.pos_Y(y),
		.pos_X(x),
		.done(done));

endmodule
