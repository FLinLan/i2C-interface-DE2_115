onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /i2c_master_single_byte_tb/r_Wr_Byte
add wave -noupdate /i2c_master_single_byte_tb/r_Wr_Start
add wave -noupdate /i2c_master_single_byte_tb/s_Bit_Count
add wave -noupdate /i2c_master_single_byte_tb/s_Is_Read
add wave -noupdate /i2c_master_single_byte_tb/s_Received_Byte
add wave -noupdate /i2c_master_single_byte_tb/s_Scl_Delay
add wave -noupdate /i2c_master_single_byte_tb/s_Scl_High_Counter
add wave -noupdate /i2c_master_single_byte_tb/s_Scl_Last
add wave -noupdate /i2c_master_single_byte_tb/s_Sda_Delay
add wave -noupdate /i2c_master_single_byte_tb/s_Sda_Stable
add wave -noupdate /i2c_master_single_byte_tb/s_Slave_Data
add wave -noupdate /i2c_master_single_byte_tb/s_Slave_State
add wave -noupdate /i2c_master_single_byte_tb/w_Busy
add wave -noupdate /i2c_master_single_byte_tb/w_Scl
add wave -noupdate /i2c_master_single_byte_tb/w_Scl_Rising
add wave -noupdate /i2c_master_single_byte_tb/w_Sda
add wave -noupdate /i2c_master_single_byte_tb/w_Start_Detected
add wave -noupdate /i2c_master_single_byte_tb/w_Stop_Detected
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {431004 ps} 0}
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
WaveRestoreZoom {0 ps} {3433500 ps}
