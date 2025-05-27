module de2_115_i2c_top (
    input         CLOCK_50,        // 50 MHz clock on DE2-115
    input         RESET_N,         // Active-low reset (e.g., from KEY[0])
    output        I2C_SCL,         // I2C SCL pin (PIN_F15)
    inout         I2C_SDA          // I2C SDA pin (PIN_F14)
);
    // Wishbone signals
    wire [2:0] wb_adr_i;
    wire [7:0] wb_dat_i;
    wire [7:0] wb_dat_o;
    wire       wb_we_i;
    wire       wb_stb_i;
    wire       wb_cyc_i;
    wire       wb_ack_o;
    wire       wb_inta_o;

    // I2C signals
    wire scl_pad_i, scl_pad_o, scl_padoen_o;
    wire sda_pad_i, sda_pad_o, sda_padoen_o;

    // Tri-state buffers for I2C lines (as per i2c_specs.pdf, page 6)
    assign I2C_SCL = scl_padoen_o ? 1'bz : scl_pad_o;
    assign I2C_SDA = sda_padoen_o ? 1'bz : sda_pad_o;
    assign scl_pad_i = I2C_SCL;
    assign sda_pad_i = I2C_SDA;

    // Instantiate I2C Master Core
    i2c_master_top #(
        .ARST_LVL(1'b0) // Active-low asynchronous reset
    ) i2c_master (
        .wb_clk_i(CLOCK_50),
        .wb_rst_i(1'b0),        // Synchronous reset (tie low if not used)
        .arst_i(RESET_N),       // Asynchronous reset
        .wb_adr_i(wb_adr_i),
        .wb_dat_i(wb_dat_i),
        .wb_dat_o(wb_dat_o),
        .wb_we_i(wb_we_i),
        .wb_stb_i(wb_stb_i),
        .wb_cyc_i(wb_cyc_i),
        .wb_ack_o(wb_ack_o),
        .wb_inta_o(wb_inta_o),
        .scl_pad_i(scl_pad_i),
        .scl_pad_o(scl_pad_o),
        .scl_padoen_o(scl_padoen_o),
        .sda_pad_i(sda_pad_i),
        .sda_pad_o(sda_pad_o),
        .sda_padoen_o(sda_padoen_o)
    );

    // Wishbone Controller (simplified example)
    reg [2:0] state;
    localparam IDLE = 3'd0, CONFIG = 3'd1, ADDR = 3'd2, DATA = 3'd3, WAIT = 3'd4;
    reg [7:0] data_to_write = 8'hAC; // Example data
    reg [6:0] slave_addr = 7'h51;    // Example slave address

    always @(posedge CLOCK_50 or negedge RESET_N) begin
        if (!RESET_N) begin
            state <= IDLE;
            wb_adr_i <= 3'b0;
            wb_dat_i <= 8'b0;
            wb_we_i <= 1'b0;
            wb_stb_i <= 1'b0;
            wb_cyc_i <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    state <= CONFIG;
                end
                CONFIG: begin
                    // Set prescale for 100 kHz SCL (50 MHz clock)
                    // prescale = (50e6 / (5 * 100e3)) - 1 = 99 = 0x63
                    wb_adr_i <= 3'h0; // PRERlo
                    wb_dat_i <= 8'h63;
                    wb_we_i <= 1'b1;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        wb_stb_i <= 1'b0;
                        wb_cyc_i <= 1'b0;
                        state <= CONFIG + 1;
                    end
                end
                CONFIG + 1: begin
                    wb_adr_i <= 3'h1; // PRERhi
                    wb_dat_i <= 8'h00;
                    wb_we_i <= 1'b1;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        wb_stb_i <= 1'b0;
                        wb_cyc_i <= 1'b0;
                        state <= CONFIG + 2;
                    end
                end
                CONFIG + 2: begin
                    wb_adr_i <= 3'h2; // CTR: Enable core
                    wb_dat_i <= 8'h80; // EN=1, IEN=0
                    wb_we_i <= 1'b1;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        wb_stb_i <= 1'b0;
                        wb_cyc_i <= 1'b0;
                        state <= ADDR;
                    end
                end
                ADDR: begin
                    // Write slave address + write bit (0xA2 = 0x51 << 1 | 0)
                    wb_adr_i <= 3'h3; // TXR
                    wb_dat_i <= {slave_addr, 1'b0};
                    wb_we_i <= 1'b1;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        wb_stb_i <= 1'b0;
                        wb_cyc_i <= 1'b0;
                        state <= ADDR + 1;
                    end
                end
                ADDR + 1: begin
                    wb_adr_i <= 3'h4; // CR: STA=1, WR=1
                    wb_dat_i <= 8'h90;
                    wb_we_i <= 1'b1;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        wb_stb_i <= 1'b0;
                        wb_cyc_i <= 1'b0;
                        state <= WAIT;
                    end
                end
                WAIT: begin
                    // Wait for TIP to negate or interrupt
                    wb_adr_i <= 3'h4; // SR
                    wb_we_i <= 1'b0;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        if (wb_dat_o[1] == 1'b0 && wb_dat_o[7] == 1'b0) begin // TIP=0, RxACK=0
                            wb_stb_i <= 1'b0;
                            wb_cyc_i <= 1'b0;
                            state <= DATA;
                        end
                    end
                end
                DATA: begin
                    // Write data
                    wb_adr_i <= 3'h3; // TXR
                    wb_dat_i <= data_to_write;
                    wb_we_i <= 1'b1;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        wb_stb_i <= 1'b0;
                        wb_cyc_i <= 1'b0;
                        state <= DATA + 1;
                    end
                end
                DATA + 1: begin
                    wb_adr_i <= 3'h4; // CR: STO=1, WR=1
                    wb_dat_i <= 8'h50;
                    wb_we_i <= 1'b1;
                    wb_stb_i <= 1'b1;
                    wb_cyc_i <= 1'b1;
                    if (wb_ack_o) begin
                        wb_stb_i <= 1'b0;
                        wb_cyc_i <= 1'b0;
                        state <= WAIT;
                    end
                end
            endcase
        end
    end

endmodule
