`timescale 1ns/1ps

module i2c_master_single_byte_tb();

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Signals
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  reg         r_Clock      = 0;
  reg         r_Reset      = 1;       // active-high async reset
  reg         r_Enable     = 1;       // keep core enabled
  reg  [6:0]  r_Slave_Addr = 7'h51;   // as in your waveform
  reg         r_Wr_Start   = 0;
  reg         r_Rd_Start   = 0;
  reg  [7:0]  r_Wr_Byte    = 8'hAC;   // data to send

  wire        o_Busy;
  wire [7:0]  o_Rd_Byte;
  wire        o_Error;

  // open-drain lines driven by DUT
  wire        io_scl;
  wire        io_sda;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // DUT instantiation
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  i2c_master_single_byte #(.CLK_RATIO(25)) UUT (
    .i_Clk        (r_Clock),
    .i_Rst        (r_Reset),
    .i_Enable     (r_Enable),
    .i_Slave_Addr (r_Slave_Addr),
    .i_Wr_Start   (r_Wr_Start),
    .i_Rd_Start   (r_Rd_Start),
    .i_Wr_Byte    (r_Wr_Byte),
    .o_Busy       (o_Busy),
    .o_Rd_Byte    (o_Rd_Byte),
    .o_Error      (o_Error),
    .io_scl       (io_scl),
    .io_sda       (io_sda)
  );

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // 50 MHz clock → 20 ns period
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  always #10 r_Clock = ~r_Clock;

  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  // Test sequence
  //–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
  initial begin
    // wait a bit, then deassert reset
    #10;
    @(posedge r_Clock);
    r_Reset <= 0;

    // give master time to initialize
    repeat (10) @(posedge r_Clock);

    // Pulse a single-byte write
    r_Wr_Start <= 1;
    @(posedge r_Clock);
    r_Wr_Start <= 0;

    // wait ~3 µs so you can see the entire transaction on SCL/SDA
    #300000;

    // report final status
    $display("\n\n%0t TEST COMPLETE | Busy=%b | Error=%b | Rd_Byte=0x%02X",
             $time, o_Busy, o_Error, o_Rd_Byte);
    $finish;
  end

endmodule
