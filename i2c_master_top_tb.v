`timescale 1ns/1ps

module i2c_master_top_tb();

  // Parameters
  localparam CLK_PERIOD = 31.25; // 32 MHz clock -> 31.25 ns period
  localparam SLAVE_ADDR = 7'h51; // Slave address as per specs
  localparam WR_DATA = 8'hAC;    // Data to write as per specs
  localparam PRESCALE = 16'd63;  // For 32 MHz clock, 100 kHz SCL: (32e6 / (5 * 100e3)) - 1
	
  // Wishbone Signals
  reg         wb_clk_i = 0;     // 32 MHz clock
  reg         wb_rst_i = 0;     // Synchronous reset
  reg         arst_i = 0;       // Asynchronous reset (active low, set to 0 for active high)
  reg  [2:0]  wb_adr_i = 0;     // Address
  reg  [7:0]  wb_dat_i = 0;     // Data input
  wire [7:0]  wb_dat_o;         // Data output
  reg         wb_we_i = 0;      // Write enable
  reg         wb_stb_i = 0;     // Strobe
  reg         wb_cyc_i = 0;     // Cycle
  wire        wb_ack_o;         // Acknowledge
  wire        wb_inta_o;        // Interrupt

  // I2C Signals
  wire        scl_pad_i;        // SCL input
  wire        scl_pad_o;        // SCL output
  wire        scl_padoen_o;     // SCL output enable
  wire        sda_pad_i;        // SDA input
  wire        sda_pad_o;        // SDA output
  wire        sda_padoen_o;     // SDA output enable

  // I2C bus signals for slave model
  reg         r_Sda_Slave = 1'b1; // Slave's SDA output
  wire        w_Sda;              // Combined SDA (open-drain)
  reg         r_Scl_Slave = 1'b1; // Slave's SCL output (not used here)
  wire        w_Scl;              // Combined SCL (open-drain)

  // Pull-up simulation (open-drain behavior) as per specs section 2.3
  assign w_Scl = scl_padoen_o ? 1'b1 : scl_pad_o;
  assign w_Sda = sda_padoen_o ? 1'b1 : sda_pad_o;
  assign scl_pad_i = w_Scl & r_Scl_Slave;
  assign sda_pad_i = w_Sda & r_Sda_Slave;

  // DUT instantiation
  i2c_master_top #(
    .ARST_LVL(1'b0) // Active low async reset
  ) UUT (
    .wb_clk_i    (wb_clk_i),
    .wb_rst_i    (wb_rst_i),
    .arst_i      (arst_i),
    .wb_adr_i    (wb_adr_i),
    .wb_dat_i    (wb_dat_i),
    .wb_dat_o    (wb_dat_o),
    .wb_we_i     (wb_we_i),
    .wb_stb_i    (wb_stb_i),
    .wb_cyc_i    (wb_cyc_i),
    .wb_ack_o    (wb_ack_o),
    .wb_inta_o   (wb_inta_o),
    .scl_pad_i   (scl_pad_i),
    .scl_pad_o   (scl_pad_o),
    .scl_padoen_o(scl_padoen_o),
    .sda_pad_i   (sda_pad_i),
    .sda_pad_o   (sda_pad_o),
    .sda_padoen_o(sda_padoen_o)
  );

  // Clock generation (32 MHz)
  always #(CLK_PERIOD/2) wb_clk_i = ~wb_clk_i;

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

  always @(posedge wb_clk_i or negedge arst_i) begin
    if (!arst_i) begin
      r_Sda_Slave <= 1'b1;
      s_Slave_State <= S_IDLE;
      s_Received_Byte <= 8'h00;
      s_Bit_Count <= 3'd0;
      s_Is_Read <= 1'b0;
      s_Slave_Data <= 8'h5A; // Dummy data for reads
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

  always @(posedge wb_clk_i) begin
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
  localparam CHECK_DELAY = 32; // Approx 1 µs delay at 32 MHz

  always @(posedge wb_clk_i or negedge arst_i) begin
    if (!arst_i) begin
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

  // Wishbone Write Task
  task wb_write;
    input [2:0] addr;
    input [7:0] data;
    begin
      @(posedge wb_clk_i);
      wb_adr_i <= addr;
      wb_dat_i <= data;
      wb_we_i  <= 1'b1;
      wb_stb_i <= 1'b1;
      wb_cyc_i <= 1'b1;
      @(posedge wb_clk_i);
      wait (wb_ack_o);
      @(posedge wb_clk_i);
      wb_stb_i <= 1'b0;
      wb_cyc_i <= 1'b0;
      wb_we_i  <= 1'b0;
    end
  endtask

  // Wishbone Read Task
  task wb_read;
    input  [2:0] addr;
    output [7:0] data;
    begin
      @(posedge wb_clk_i);
      wb_adr_i <= addr;
      wb_we_i  <= 1'b0;
      wb_stb_i <= 1'b1;
      wb_cyc_i <= 1'b1;
      @(posedge wb_clk_i);
      wait (wb_ack_o);
      @(posedge wb_clk_i);
      data = wb_dat_o;
      wb_stb_i <= 1'b0;
      wb_cyc_i <= 1'b0;
    end
  endtask

  // Test Sequence
  reg [7:0] status;
  initial begin
    $display("Starting I2C Master Top Testbench");
    // Reset
    arst_i = 1'b0;
    wb_rst_i = 1'b1;
    #100;
    arst_i = 1'b1;
    wb_rst_i = 1'b0;
    #100;

    // Step 1: Configure the core
    // Set prescale register for 100 kHz SCL (32 MHz clock)
    wb_write(3'h0, PRESCALE[7:0]);  // PRERlo
    wb_write(3'h1, PRESCALE[15:8]); // PRERhi
    // Enable core and interrupts
    wb_write(3'h2, 8'hC0); // CTR: EN=1, IEN=1

    // Step 2: Write address + write bit (0xA2), set STA and WR (Example 1, Step 1)
    wb_write(3'h3, 8'hA2); // TXR: Address 0x51 + W (0)
    wb_write(3'h4, 8'h90); // CR: STA=1, WR=1

    // Step 3: Wait for interrupt or TIP flag to negate
    wait (wb_inta_o);
    wb_read(3'h4, status); // SR
    $display("%0t: Status after address: RxACK=%b, TIP=%b", $time, status[7], status[1]);
    if (status[7] != 1'b0) $display("%0t: ERROR: Slave did not acknowledge address", $time);
    // Clear interrupt
    wb_write(3'h4, 8'h01); // CR: IACK=1

    // Step 4: Write data (0xAC), set STO and WR (Example 1, Step 2)
    wb_write(3'h3, WR_DATA); // TXR: Data 0xAC
    wb_write(3'h4, 8'h50);   // CR: STO=1, WR=1

    // Step 5: Wait for interrupt or TIP flag to negate
    wait (wb_inta_o);
    wb_read(3'h4, status); // SR
    $display("%0t: Status after data: RxACK=%b, TIP=%b", $time, status[7], status[1]);
    if (status[7] != 1'b0) $display("%0t: ERROR: Slave did not acknowledge data", $time);
    // Clear interrupt
    wb_write(3'h4, 8'h01); // CR: IACK=1

    // Wait to observe signals
    #100000;

    $display("\n%0t: Testbench Complete", $time);
    $finish;
  end

endmodule