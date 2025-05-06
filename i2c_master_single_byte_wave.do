onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /i2c_master_single_byte_tb/io_scl
add wave -noupdate /i2c_master_single_byte_tb/io_sda
add wave -noupdate /i2c_master_single_byte_tb/o_Busy
add wave -noupdate /i2c_master_single_byte_tb/o_Error
add wave -noupdate /i2c_master_single_byte_tb/o_Rd_Byte
add wave -noupdate /i2c_master_single_byte_tb/r_Clock
add wave -noupdate /i2c_master_single_byte_tb/r_Enable
add wave -noupdate /i2c_master_single_byte_tb/r_Rd_Start
add wave -noupdate /i2c_master_single_byte_tb/r_Reset
add wave -noupdate /i2c_master_single_byte_tb/r_Slave_Addr
add wave -noupdate /i2c_master_single_byte_tb/r_Wr_Byte
add wave -noupdate /i2c_master_single_byte_tb/r_Wr_Start
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
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
WaveRestoreZoom {300249050 ps} {300250050 ps}
