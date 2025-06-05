module spi_master (
    input  logic CLOCK_50,      // 50 MHz system clock
    input  logic RESET_N,       // Active-low reset (e.g., from KEY)
    input  logic MISO,          // SPI MISO from Arduino
    output logic MOSI,          // SPI MOSI to Arduino
    output logic SCLK,          // SPI Clock
    output logic SS_N,          // Slave Select (active low)
    output logic [6:0] HEX0     // Seven-segment display
);

    // Parameters
    localparam CLK_FREQ = 50_000_000; // 50 MHz
    localparam SPI_FREQ = 500_000;    // SPI clock ~500 kHz
    localparam CLK_DIV = CLK_FREQ / (2 * SPI_FREQ); // Clock divider

    // SPI States
    typedef enum logic [2:0] {IDLE, INIT, SETUP, SHIFT, SAMPLE, DONE} state_t;
    state_t state;

    // Signals
    logic [7:0] tx_data;        // Data to send
    logic [7:0] rx_data;        // Data received
    logic [3:0] bit_cnt;        // Bit counter (8 bits)
    logic [15:0] clk_cnt;       // Clock divider counter
    logic transfer_done;        // Flag for transfer completion
    logic spi_clk_edge;         // Edge detection flag
    logic [3:0] hex_value;      // Value to display

    // Seven-segment decoder (combinational)
    always_comb begin
        case (hex_value)
            4'h0: HEX0 = 7'b1000000; // 0
            4'h1: HEX0 = 7'b1111001; // 1
            4'h2: HEX0 = 7'b0100100; // 2
            4'h3: HEX0 = 7'b0110000; // 3
            4'h4: HEX0 = 7'b0011001; // 4
            4'h5: HEX0 = 7'b0010010; // 5
            4'h6: HEX0 = 7'b0000010; // 6
            4'h7: HEX0 = 7'b1111000; // 7
            4'h8: HEX0 = 7'b0000000; // 8
            4'h9: HEX0 = 7'b0010000; // 9
            4'hA: HEX0 = 7'b0001000; // A
            4'hB: HEX0 = 7'b0000011; // b
            4'hC: HEX0 = 7'b1000110; // C
            4'hD: HEX0 = 7'b0100001; // d
            4'hE: HEX0 = 7'b0000110; // E
            4'hF: HEX0 = 7'b0001110; // F
            default: HEX0 = 7'b1111111; // All segments off
        endcase
    end

    // Clock divider for SPI timing
    always_ff @(posedge CLOCK_50 or negedge RESET_N) begin
        if (!RESET_N) begin
            clk_cnt <= 0;
            spi_clk_edge <= 0;
        end else begin
            if (state == IDLE || state == DONE) begin
                clk_cnt <= 0;
                spi_clk_edge <= 0;
            end else if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
                spi_clk_edge <= 1;
            end else begin
                clk_cnt <= clk_cnt + 1;
                spi_clk_edge <= 0;
            end
        end
    end

    // SPI state machine
    always_ff @(posedge CLOCK_50 or negedge RESET_N) begin
        if (!RESET_N) begin
            state <= IDLE;
            MOSI <= 0;
            SCLK <= 0;
            SS_N <= 1;
            bit_cnt <= 0;
            tx_data <= 8'h55; // Data to send (0x55)
            rx_data <= 0;
            transfer_done <= 0;
            hex_value <= 4'h0; // Display '0' initially
        end else begin
            case (state)
                IDLE: begin
                    SCLK <= 0;
                    SS_N <= 1;
                    bit_cnt <= 0;
                    MOSI <= 0;
                    if (!transfer_done) begin
                        state <= INIT;
                        tx_data <= 8'h55; // Reload data to send
                    end
                end
                
                INIT: begin
                    SS_N <= 0; // Activate slave
                    // Wait for slave to be ready
                    if (spi_clk_edge) begin
                        state <= SETUP;
                    end
                end
                
                SETUP: begin
                    // Setup data on MOSI while SCLK is low
                    MOSI <= tx_data[7];
                    if (spi_clk_edge) begin
                        state <= SHIFT;
                    end
                end
                
                SHIFT: begin
                    // Rising edge of SCLK - slave samples MOSI
                    SCLK <= 1;
                    if (spi_clk_edge) begin
                        state <= SAMPLE;
                    end
                end
                
                SAMPLE: begin
                    // Falling edge of SCLK - sample MISO and prepare next bit
                    SCLK <= 0;
                    rx_data <= {rx_data[6:0], MISO}; // Sample MISO
                    
                    if (spi_clk_edge) begin
                        bit_cnt <= bit_cnt + 1;
                        
                        if (bit_cnt == 7) begin
                            state <= DONE;
                        end else begin
                            tx_data <= {tx_data[6:0], 1'b0}; // Shift for next bit
                            state <= SETUP;
                        end
                    end
                end
                
                DONE: begin
                    SCLK <= 0;
                    SS_N <= 1;
                    MOSI <= 0;
                    transfer_done <= 1;
                    
                    // Update display value
                    if (rx_data == 8'hAA) begin
                        hex_value <= 4'hA; // Display 'A'
                    end else if (rx_data == 8'h55) begin
                        hex_value <= 4'h5; // Display '5'
                    end else begin
                        hex_value <= rx_data[3:0]; // Display lower nibble
                    end
                    
                    if (spi_clk_edge) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
