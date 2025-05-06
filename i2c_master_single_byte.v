`include "timescale.v"
//// synopsys translate_on
//
`include "i2c_master_defines.v"

module i2c_master_single_byte #(parameter CLK_RATIO = 25)
	(input i_Clk,					  // Main FPGA clock
	 input i_Rst,					  // Active-high asychronous reset
	 input i_Enable,				  // Enable for I2C master
	 //
	 input [6:0] i_Slave_Addr,	  // I2C Address of Slave device
	 input i_Wr_Start,			  // Kicks off a write when pulsed
	 input i_Rd_Start,			  // Kicks off a read when pulsed
	 input [7:0] i_Wr_Byte,		  // Data to write (if write cmd)
	 output reg o_Busy,			  // Falling edge = done
	 output [7:0] o_Rd_Byte,	  // Result of a read
	 output o_Error,				  // High if error in lost transcation
	 //
	 input io_scl,					  // Actual I2C Clock
	 input io_sda					  // Actual I2C Data
	);
	
	// Defines the pper limit of an internal counter. This sets the frequency of the I2C
	// clock, which depends on teh input clock frequency. For details on this math, see the
	// I2C User Guide, Section 3.2.1 - Prescale Register
	localparam [15:0] CLK_COUNT = CLK_RATIO / 5 - 1;
	
	localparam [2:0] IDLE 				= 3'b000;
	localparam [2:0] WAIT_SLAVE_ADDR = 3'b001;
	localparam [2:0] SEND_WR_DATA    = 3'b010;
	localparam [2:0] WAIT_WR_DATA    = 3'b011;
	localparam [2:0] CLEANUP 		   = 3'b100;
	
	
	
	wire w_sck_en, w_sda_en;
	wire w_Arb_Lost, w_Cmd_Ack, w_Slave_Ack;
	// wire w_Cmd_Start;
	reg r_Cmd_Start, r_Cmd_Stop, r_Wr_Start, r_Rd_Cmd, r_Cmd_Ack;
	reg [7:0] r_Cmd_Byte, r_Wr_Byte;
	
	reg [2:0] r_SM_Main;
	
	// right now o_done doesn't go to the high level module, is it needed?
	assign o_Done = w_Arb_Lost | w_Cmd_Ack;
	
	//	// Start can be either read or write, ensure not both. (XOR)
	//	assign w_Cmd_Start = i_Wr_Start ^ i_Rd_Start;
	
	// i2c master block instantiation
	// hookup byte controller block
	i2c_master_byte_ctrl byte_controller (
		.clk(i_clk			  ),
		.rst(1'b0			  ), 	// use async reset below only
		.nReset(~i_Rst		  ), 	// active low, invert required
		.ena(i_Enable		  ), 
		.clk_cnt(CLK_COUNT  ),	
		.start(r_Cmd_Start  ), 	// Single clock cycle pulse to start command 
		.stop(r_Cmd_Stop	  ), 	// Used to set end of command
		.read(r_Rd_Cmd	  	  ), 	// Read command
		.write(r_Wr_Cmd     ), 	// Write command
		.ack_in(1'b0		  ), 	// When Master is Receiving, 0=ACK, 1 =NACK, nac can indicate end
		.din(r_Cmd_Byte	  ), 
		.cmd_ack(w_Cmd_Ack  ), 	// From Slave. When Command is done this is set. 
		.ack_out(w_Slave_Ack),  // When Slave is Receiving. 0=ACK, 1=NACK. How to handle situation
		.dout(o_Rd_Byte	  ),
		.i2c_busy(			  ),  // This module generates its own busy signal
		.i2c_al(w_Arb_Lost  ),
		.scl_i(io_scl		  ),
		.scl_o(				  ), 	// tied to gnd inside bit_ctrl, don't need
		.scl_oen(w_sck_en	  ),
		.sda_i(io_sda		  ),
		.sda_o(				  ), 	// tied to gnd insdie bit_ctrl, don't need
		.sda_oen(w_sda_en	  )
	);
	 
	// Creates tri-state buffer.
	// When Enable is high, go high impedance (1). When low, pull low to zero.
	assign io_scl = w_sck_en ? 1'bz : 1'b0;
	assign io_sda = w_sda_en ? 1'bz : 1'b0;
	
	// Purpose: Create one clock cycle delay to detect
	// falling edge of Cmd_Ack from core. Assuem this is when command is done.
	always @(posedge i_Clk)
	begin
		r_Cmd_Ack <= w_Cmd_Ack;
	end
	 
	// Purpose: Generate Busy signal when master is transmitting or receiving.
	//	always @(posedge i_Rst or posedge i_Clk)
	//	begin
	//		if (i_Rst)
	//		begin
	//			o_Busy <= 1'b0;
	//		end
	//		else
	//		begin
	//			if (~o_Busy & (i_Wr_Start | i_Rd_Start))
	//			begin
	//				o_Busy <= 1'b1;
	//			end
	//			else if (o_Busy & (w_Cmd_Ack))
	//			begin
	//				o_Busy <= 1'b0;
	//			end
	//		end
	//	end
	
//	STOPPED HERE
	
	/*
	note: need to implement start/stop bit genration.
	// previously assumed .stop input to the core was never used
	// however this is critical signal to set the STOP bit inside the control reg.
	// this module should be automatically be handling start and stop bits, writing the slave addr,
	// create a state machine here to drive a write transaction correctly.
	*/
	
	// Purpose : MainState Machine for control
	always @(posedge i_Rst or posedge i_Clk)
	begin
		if(i_Rst)
		begin
			r_SM_Main   <= IDLE;
			r_Cmd_Start <= 1'b0;
			o_Busy      <= 1'b0;
		end
		else
		begin
		
			// Default assignments 
			r_Cmd_Start <= 1'b0;			
			
			case (r_SM_Main)
				IDLE:
				begin
					if (i_Wr_Start)
					begin
						r_Cmd_Start <= 1'b1;
						r_Wr_Cmd <= 1'b1;
						o_Busy 	  <= 1'b1;
						r_Wr_Byte <= i_Wr_Byte; // not writing until the next transaction
						r_Cmd_Byte  <= {i_Slave_Addr, 1'b0}; // 1'b0 = Write Command
						r_SM_Main  <= SEND_SLAVE_ADDR;
					end
					else
					begin
						r_Rd_Cmd <= 1'b0;
						r_Wr_Cmd <= 1'b0;
						o_Busy <= 1'b0;
					end
				end
				
				// Wait for Cmd Ack from Core to know slave addr is written
				WAIT_SLAVE_ADDR:
				begin
					// Done when Cmd Ack has falling edge
					if (r_Cmd_Ack & ~w_Cmd_Ack)
					begin
						r_SM_Main <= SEND_WR_DATA;
					end
				end
				
				// Send the data to write to the slave
				SEND_WR_DATA:
				begin
					r_Wr_Start <= 1'b1;
					r_Cmd_Byte <= r_Wr_Byte;
					r_SM_Main <= WAIT_WR_DATA;
				end
				
				// Wait for the slave to acknowledge the write.
				WAIT_WR_DATA:
				begin
					// Done when Cmd Ack has falling edge
					if (r_Cmd_Ack & ~w_Cmd_Ack)
					begin
						r_SM_Main <= CLEANUP;
					end
				end
				
				// One clock cycle for cleanup and resetting signals
				CLEANUP:
				begin
					r_SM_Main <= IDLE;
				end
				
			endcase
		end
	end
endmodule
