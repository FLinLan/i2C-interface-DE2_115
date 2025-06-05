module DE1_SoC (
    // Clock and Reset
    input  logic CLOCK_50,
    input  logic [3:0] KEY,         // Push buttons (active low)
    input  logic [17:0] SW,         // Toggle switches
    
    // LED outputs
    output logic [17:0] LEDR,       // Red LEDs
    output logic [8:0] LEDG,        // Green LEDs
    
    // Seven-segment displays
    output logic [6:0] HEX0,
    output logic [6:0] HEX1,
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,
    output logic [6:0] HEX4,
    output logic [6:0] HEX5,
    output logic [6:0] HEX6,
    output logic [6:0] HEX7,
    
    // GPIO for SPI (keep for later)
    input  logic GPIO_0_4,  // MISO
    output logic GPIO_0_2,  // MOSI
    output logic GPIO_0_0,  // SCLK
    output logic GPIO_0_6   // SS_N
);

    // Commented out SPI master for testing other peripherals first
    /*
    spi_master spi_inst (
        .CLOCK_50(CLOCK_50),
        .RESET_N(KEY[0]),
        .MISO(GPIO_0_4),
        .MOSI(GPIO_0_2),
        .SCLK(GPIO_0_0),
        .SS_N(GPIO_0_6),
        .HEX0(HEX0)
    );
    */

    // Test 1: Direct switch to LED mapping
    assign LEDR = SW;  // Red LEDs follow switches
    
    // Test 2: Green LED counter (proves clock is working)
    logic [26:0] counter;
    always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) 
            counter <= 0;
        else 
            counter <= counter + 1;
    end
    
    // Green LEDs show different counter bits for different blink rates
    assign LEDG[0] = counter[23];  // Fast blink
    assign LEDG[1] = counter[24];  // Medium blink
    assign LEDG[2] = counter[25];  // Slow blink
    assign LEDG[3] = counter[26];  // Very slow blink
    
    // Test if KEY buttons work - light up green LEDs when pressed
    assign LEDG[4] = ~KEY[0];  // KEY[0] pressed
    assign LEDG[5] = ~KEY[1];  // KEY[1] pressed
    assign LEDG[6] = ~KEY[2];  // KEY[2] pressed
    assign LEDG[7] = ~KEY[3];  // KEY[3] pressed
    assign LEDG[8] = &(~KEY);   // All keys pressed
    
    // Test 3: Seven-segment displays
    // Try both active-low and active-high patterns
    
    // HEX0 - Simple test pattern (all segments on/off based on SW[0])
    assign HEX0 = SW[0] ? 7'b0000000 : 7'b1111111;  // All on or all off
    
    // HEX1 - Test each segment individually based on SW[7:1]
    assign HEX1 = ~SW[7:1];  // Direct switch control of segments
    
    // HEX2 - Display switch value SW[3:0]
    always_comb begin
        case (SW[3:0])
            4'h0: HEX2 = 7'b1000000; // 0
            4'h1: HEX2 = 7'b1111001; // 1
            4'h2: HEX2 = 7'b0100100; // 2
            4'h3: HEX2 = 7'b0110000; // 3
            4'h4: HEX2 = 7'b0011001; // 4
            4'h5: HEX2 = 7'b0010010; // 5
            4'h6: HEX2 = 7'b0000010; // 6
            4'h7: HEX2 = 7'b1111000; // 7
            4'h8: HEX2 = 7'b0000000; // 8
            4'h9: HEX2 = 7'b0010000; // 9
            4'hA: HEX2 = 7'b0001000; // A
            4'hB: HEX2 = 7'b0000011; // b
            4'hC: HEX2 = 7'b1000110; // C
            4'hD: HEX2 = 7'b0100001; // d
            4'hE: HEX2 = 7'b0000110; // E
            4'hF: HEX2 = 7'b0001110; // F
            default: HEX2 = 7'b1111111;
        endcase
    end
    
    // HEX3 - Try inverted pattern in case display is active high
    always_comb begin
        case (SW[7:4])
            4'h0: HEX3 = ~7'b1000000; // 0 inverted
            4'h1: HEX3 = ~7'b1111001; // 1 inverted
            4'h2: HEX3 = ~7'b0100100; // 2 inverted
            4'h3: HEX3 = ~7'b0110000; // 3 inverted
            4'h4: HEX3 = ~7'b0011001; // 4 inverted
            4'h5: HEX3 = ~7'b0010010; // 5 inverted
            4'h6: HEX3 = ~7'b0000010; // 6 inverted
            4'h7: HEX3 = ~7'b1111000; // 7 inverted
            4'h8: HEX3 = ~7'b0000000; // 8 inverted
            4'h9: HEX3 = ~7'b0010000; // 9 inverted
            4'hA: HEX3 = ~7'b0001000; // A inverted
            4'hB: HEX3 = ~7'b0000011; // b inverted
            4'hC: HEX3 = ~7'b1000110; // C inverted
            4'hD: HEX3 = ~7'b0100001; // d inverted
            4'hE: HEX3 = ~7'b0000110; // E inverted
            4'hF: HEX3 = ~7'b0001110; // F inverted
            default: HEX3 = 7'b0000000;
        endcase
    end
    
    // HEX4-7: Counter display (shows that sequential logic works)
    logic [15:0] slow_counter;
    always_ff @(posedge CLOCK_50 or negedge KEY[1]) begin
        if (!KEY[1])
            slow_counter <= 0;
        else if (counter[23:0] == 0)  // Increment slowly
            slow_counter <= slow_counter + 1;
    end
    
    // Display counter on HEX4-7
    hex_decoder h4(.value(slow_counter[3:0]),   .hex(HEX4));
    hex_decoder h5(.value(slow_counter[7:4]),   .hex(HEX5));
    hex_decoder h6(.value(slow_counter[11:8]),  .hex(HEX6));
    hex_decoder h7(.value(slow_counter[15:12]), .hex(HEX7));
    
    // Tie off SPI signals for now
    assign GPIO_0_2 = 1'b0;
    assign GPIO_0_0 = 1'b0;
    assign GPIO_0_6 = 1'b1;

endmodule

// Helper module for hex decoding
module hex_decoder (
    input  logic [3:0] value,
    output logic [6:0] hex
);
    always_comb begin
        case (value)
            4'h0: hex = 7'b1000000;
            4'h1: hex = 7'b1111001;
            4'h2: hex = 7'b0100100;
            4'h3: hex = 7'b0110000;
            4'h4: hex = 7'b0011001;
            4'h5: hex = 7'b0010010;
            4'h6: hex = 7'b0000010;
            4'h7: hex = 7'b1111000;
            4'h8: hex = 7'b0000000;
            4'h9: hex = 7'b0010000;
            4'hA: hex = 7'b0001000;
            4'hB: hex = 7'b0000011;
            4'hC: hex = 7'b1000110;
            4'hD: hex = 7'b0100001;
            4'hE: hex = 7'b0000110;
            4'hF: hex = 7'b0001110;
            default: hex = 7'b1111111;
        endcase
    end
endmodule