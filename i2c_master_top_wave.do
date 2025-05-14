onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Wishbone Interface}
add wave -noupdate /i2c_master_top_tb/wb_clk_i
add wave -noupdate /i2c_master_top_tb/wb_rst_i
add wave -noupdate /i2c_master_top_tb/arst_i
add wave -noupdate -radix hexadecimal /i2c_master_top_tb/wb_adr_i
add wave -noupdate -radix hexadecimal /i2c_master_top_tb/wb_dat_i
add wave -noupdate -radix hexadecimal /i2c_master_top_tb/wb_dat_o
add wave -noupdate /i2c_master_top_tb/wb_we_i
add wave -noupdate /i2c_master_top_tb/wb_stb_i
add wave -noupdate /i2c_master_top_tb/wb_cyc_i
add wave -noupdate /i2c_master_top_tb/wb_ack_o
add wave -noupdate /i2c_master_top_tb/wb_inta_o
add wave -noupdate -divider {I2C Interface}
add wave -noupdate /i2c_master_top_tb/scl_pad_o
add wave -noupdate /i2c_master_top_tb/scl_padoen_o
add wave -noupdate /i2c_master_top_tb/scl_pad_i
add wave -noupdate /i2c_master_top_tb/sda_pad_o
add wave -noupdate /i2c_master_top_tb/sda_padoen_o
add wave -noupdate -divider {I2C Bus (Testbench)}
add wave -noupdate /i2c_master_top_tb/r_Sda_Slave
add wave -noupdate /i2c_master_top_tb/w_Sda
add wave -noupdate /i2c_master_top_tb/r_Scl_Slave
add wave -noupdate /i2c_master_top_tb/w_Scl
add wave -noupdate -divider {I2C Slave Model}
add wave -noupdate -radix hexadecimal /i2c_master_top_tb/s_Slave_Data
add wave -noupdate /i2c_master_top_tb/s_Slave_State
add wave -noupdate -radix hexadecimal /i2c_master_top_tb/s_Received_Byte
add wave -noupdate /i2c_master_top_tb/s_Bit_Count
add wave -noupdate /i2c_master_top_tb/s_Is_Read
add wave -noupdate /i2c_master_top_tb/s_Sda_Delay
add wave -noupdate /i2c_master_top_tb/s_Scl_Delay
add wave -noupdate /i2c_master_top_tb/s_Scl_Last
add wave -noupdate /i2c_master_top_tb/w_Start_Detected
add wave -noupdate /i2c_master_top_tb/w_Stop_Detected
add wave -noupdate /i2c_master_top_tb/w_Scl_Rising
add wave -noupdate -divider {I2C Bus Monitor}
add wave -noupdate -radix hexadecimal /i2c_master_top_tb/m_Received_Byte
add wave -noupdate /i2c_master_top_tb/m_Bit_Count
add wave -noupdate /i2c_master_top_tb/m_Monitor_State
add wave -noupdate -divider {SDA Stability Check}
add wave -noupdate /i2c_master_top_tb/s_Sda_Stable
add wave -noupdate -radix decimal /i2c_master_top_tb/s_Scl_High_Counter
add wave -noupdate -divider {Test Sequence}
add wave -noupdate -radix hexadecimal /i2c_master_top_tb/status
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {33359761 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {344082103 ps}
