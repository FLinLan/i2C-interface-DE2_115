`timescale 1ns/1ps

module i2c_master_single_byte_tb();

  // Parameters
  localparam CLK_PERIOD = 20; // 50 MHz clock -> 20 ns period
  localparam CLK_RATIO = 25;  // From DUT parameter
  localparam SCL_PERIOD = CLK_PERIOD * CLK_RATIO * 5; // SCL period in ns (100 kHz -> 10,000 ns)
  localparam SLAVE_ADDR = 7'h51; // Slave address as per specs
  localparam WR_DATA = 8'hAC;    // Data to write as per specs

  // Signals
  reg         r_Clock      = 0;
  reg         r_Reset      = 1;       // Active-high async reset
  reg         r_Enable     = 1;       // Keep core enabled
  reg [6:0]   r_Slave_Addr = SLAVE_ADDR;
  reg         r_Wr_Start   = 0;
  reg         r_Rd_Start   = 0;
  reg [7:0]   r_Wr_Byte    = WR_DATA;
  wire        w_Busy;
  wire [7:0]  o_Rd_Byte;
  wire        o_Error;
  wire        io_scl;
  wire        io_sda;

  // I2C bus signals for slave model
  reg         r_Sda_Slave  = 1'b1; // Slave's SDA output
  wire        w_Sda;               // Combined SDA (open-drain)
  reg         r_Scl_Slave  = 1'b1; // Slave's SCL output (for clock stretching, not used here)
  wire        w_Scl;               // Combined SCL (open-drain)

  // Pull-up simulation (open-drain behavior)
  assign w_Scl = (io_scl === 1'b0 || r_Scl_Slave === 1'b0) ? 1'b0 : 1'b1;
  assign w_Sda = (io_sda === 1'b0 || r_Sda_Slave === 1'b0) ? 1'b0 : 1'b1;

  // DUT instantiation
  i2c_master_single_byte #(.CLK_RATIO(CLK_RATIO)) UUT (
    .i_Clk        (r_Clock),
    .i_Rst        (r_Reset),
    .i_Enable     (r_Enable),
    .i_Slave_Addr (r_Slave_Addr),
    .i_Wr_Start   (r_Wr_Start),
    .i_Rd_Start   (r_Rd_Start),
    .i_Wr_Byte    (r_Wr_Byte),
    .o_Busy       (w_Busy),
    .o_Rd_Byte    (o_Rd_Byte),
    .o_Error      (o_Error),
    .io_scl       (io_scl),
    .io_sda       (io_sda)
  );

  // Clock generation (50 MHz)
  always #(CLK_PERIOD/2) r_Clock = ~r_Clock;

  // I2C Slave Model
  reg [7:0]  s_Slave_Data;
  reg [2:0]  s_Slave_State;
  localparam S_IDLE        = 3'd0;
  localparam S_ADDR        = 3'd1;
  localparam S_ACK_ADDR    = 3'd2;
  localparam S_WR_DATA     = 3'd3;
  localparam S_ACK_WR      = 3'd4;
  localparam S_RD_DATA     = 3'd5;
  localparam S_ACK_RD      = 3'd6;

  reg [7:0]  s_Received_Byte;
  reg [2:0]  s_Bit_Count;
  reg        s_Is_Read;

  // Detect START/STOP conditions
  reg        s_Sda_Delay, s_Scl_Delay;
  wire       w_Start_Detected = ~w_Sda & s_Sda_Delay & w_Scl & s_Scl_Delay;
  wire       w_Stop_Detected  = w_Sda & ~s_Sda_Delay & w_Scl & s_Scl_Delay;

  // Monitor SCL rising edge for bit sampling
  reg        s_Scl_Last;
  wire       w_Scl_Rising = w_Scl & ~s_Scl_Last;

  // Slave state machine
  always @(posedge r_Clock or posedge r_Reset) begin
    if (r_Reset) begin
      r_Sda_Slave <= 1'b1;
      s_Slave_State <= S_IDLE;
      s_Received_Byte <= 8'h00;
      s_Bit_Count <= 3'd0;
      s_Is_Read <= 1'b0;
      s_Slave_Data <= 8'h5A; // Dummy data for reads (not used in this test)
      s_Sda_Delay <= 1'b1;
      s_Scl_Delay <= 1'b1;
      s_Scl_Last <= 1'b1;
    end else begin
      s_Sda_Delay <= w_Sda;
      s_Scl_Delay <= w_Scl;
      s_Scl_Last <= w_Scl;

      r_Sda_Slave <= 1'b1;

      case (s_Slave_State)
        S_IDLE: begin
          s_Bit_Count <= 3'd7;
          if (w_Start_Detected) begin
            s_Slave_State <= S_ADDR;
            s_Received_Byte <= 8'h00;
          end
        end

        S_ADDR: begin
          if (w_Scl_Rising) begin
            s_Received_Byte[s_Bit_Count] <= w_Sda;
            if (s_Bit_Count == 0) begin
              s_Slave_State <= S_ACK_ADDR;
              s_Is_Read <= w_Sda;
            end else begin
              s_Bit_Count <= s_Bit_Count - 1;
            end
          end
        end

        S_ACK_ADDR: begin
          if (w_Scl_Rising) begin
            if (s_Received_Byte[7:1] == SLAVE_ADDR) begin
              r_Sda_Slave <= 1'b0; // Send ACK
              s_Slave_State <= s_Is_Read ? S_RD_DATA : S_WR_DATA;
              s_Bit_Count <= 3'd7;
              s_Received_Byte <= 8'h00;
            end else begin
              s_Slave_State <= S_IDLE;
            end
          end
        end

        S_WR_DATA: begin
          if (w_Scl_Rising) begin
            s_Received_Byte[s_Bit_Count] <= w_Sda;
            if (s_Bit_Count == 0) begin
              s_Slave_State <= S_ACK_WR;
            end else begin
              s_Bit_Count <= s_Bit_Count - 1;
            end
          end
        end

        S_ACK_WR: begin
          if (w_Scl_Rising) begin
            r_Sda_Slave <= 1'b0; // Send ACK
            s_Slave_State <= w_Stop_Detected ? S_IDLE : S_WR_DATA;
            s_Bit_Count <= 3'd7;
            $display("%0t: Slave received data: 0x%02X", $time, s_Received_Byte);
          end
        end

        S_RD_DATA: begin
          r_Sda_Slave <= s_Slave_Data[s_Bit_Count];
          if (w_Scl_Rising) begin
            if (s_Bit_Count == 0) begin
              s_Slave_State <= S_ACK_RD;
            end else begin
              s_Bit_Count <= s_Bit_Count - 1;
            end
          end
        end

        S_ACK_RD: begin
          if (w_Scl_Rising) begin
            if (w_Sda == 1'b0) begin
              $display("%0t: Master sent ACK, continuing read", $time);
              s_Slave_State <= S_RD_DATA;
              s_Bit_Count <= 3'd7;
            end else begin
              $display("%0t: Master sent NACK, ending read", $time);
              s_Slave_State <= S_IDLE;
            end
          end
        end

        default: s_Slave_State <= S_IDLE;
      endcase

      if (w_Stop_Detected) begin
        s_Slave_State <= S_IDLE;
        $display("%0t: STOP condition detected", $time);
      end
    end
  end

  // I2C Bus Monitor
  reg [7:0]  m_Received_Byte;
  reg [2:0]  m_Bit_Count;
  reg [2:0]  m_Monitor_State;
  localparam M_IDLE     = 3'd0;
  localparam M_ADDR     = 3'd1;
  localparam M_ACK_ADDR = 3'd2;
  localparam M_DATA     = 3'd3;
  localparam M_ACK_DATA = 3'd4;

  always @(posedge r_Clock) begin
    case (m_Monitor_State)
      M_IDLE: begin
        m_Bit_Count <= 3'd7;
        m_Received_Byte <= 8'h00;
        if (w_Start_Detected) begin
          m_Monitor_State <= M_ADDR;
          $display("%0t: START condition detected", $time);
        end
      end

      M_ADDR: begin
        if (w_Scl_Rising) begin
          m_Received_Byte[m_Bit_Count] <= w_Sda;
          if (m_Bit_Count == 0) begin
            m_Monitor_State <= M_ACK_ADDR;
            $display("%0t: Address + R/W: 0x%02X (Addr: 0x%02X, R/W: %b)",
                     $time, m_Received_Byte, m_Received_Byte[7:1], m_Received_Byte[0]);
          end else begin
            m_Bit_Count <= m_Bit_Count - 1;
          end
        end
      end

      M_ACK_ADDR: begin
        if (w_Scl_Rising) begin
          $display("%0t: Address ACK: %b", $time, w_Sda);
          if (w_Sda == 1'b0) begin
            m_Monitor_State <= M_DATA;
            m_Bit_Count <= 3'd7;
            m_Received_Byte <= 8'h00;
          end else begin
            m_Monitor_State <= M_IDLE;
          end
        end
      end

      M_DATA: begin
        if (w_Scl_Rising) begin
          m_Received_Byte[m_Bit_Count] <= w_Sda;
          if (m_Bit_Count == 0) begin
            m_Monitor_State <= M_ACK_DATA;
            $display("%0t: Data byte: 0x%02X", $time, m_Received_Byte);
          end else begin
            m_Bit_Count <= m_Bit_Count - 1;
          end
        end
      end

      M_ACK_DATA: begin
        if (w_Scl_Rising) begin
          $display("%0t: Data ACK: %b", $time, w_Sda);
          if (w_Stop_Detected) begin
            m_Monitor_State <= M_IDLE;
          end else begin
            m_Monitor_State <= M_DATA;
            m_Bit_Count <= 3'd7;
            m_Received_Byte <= 8'h00;
          end
        end
      end

      default: m_Monitor_State <= M_IDLE;
    endcase

    if (w_Stop_Detected) begin
      m_Monitor_State <= M_IDLE;
    end
  end

  // Check SDA stability during SCL high
  reg s_Sda_Stable;
  reg [15:0] s_Scl_High_Counter;
  localparam CHECK_DELAY = CLK_RATIO * 2; // Check after 2 I2C clock cycles (40 ns at 50 MHz)

  always @(posedge r_Clock or posedge r_Reset) begin
    if (r_Reset) begin
        s_Sda_Stable <= 1'b1;
        s_Scl_High_Counter <= 0;
    end else begin
        if (w_Scl_Rising) begin
            s_Scl_High_Counter <= 0;
            s_Sda_Stable <= w_Sda;
        end else if (w_Scl) begin
            s_Scl_High_Counter <= s_Scl_High_Counter + 1;
            if (s_Scl_High_Counter == CHECK_DELAY) begin
                if (s_Sda_Stable !== w_Sda) begin
                    $display("%0t: ERROR: SDA changed during SCL high!", $time);
                end
            end
        end
    end
  end

  // Test Sequence
  initial begin
    $display("Starting I2C Master Testbench");
    // Initialize
    r_Reset <= 1;
    r_Wr_Start <= 0;
    r_Rd_Start <= 0;
    r_Slave_Addr <= SLAVE_ADDR;
    r_Wr_Byte <= WR_DATA;

    // Deassert reset
    #10;
    @(posedge r_Clock);
    r_Reset <= 0;

    // Wait for initialization
    repeat (10) @(posedge r_Clock);

    // Test: Write Transaction (as per Example 1 in specs)
    $display("\n%0t: Initiating Write Transaction (Addr: 0x%02X, Data: 0x%02X)",
             $time, SLAVE_ADDR, WR_DATA);
    @(posedge r_Clock);
    r_Wr_Start <= 1'b1;
    @(posedge r_Clock);
    r_Wr_Start <= 1'b0;

    // Wait for transaction to complete
    while (w_Busy) @(posedge r_Clock);

    // Wait 3 µs to observe signals (as per waveform)
    #3000;

    // Display final status
    $display("\n%0t: Testbench done | Busy=%b | Error=%b | Rd_Byte=0x%02X",
             $time, w_Busy, o_Error, o_Rd_Byte);
    if (o_Error) $display("%0t: ERROR: Write transaction failed!", $time);
    $finish;
  end

endmodule
