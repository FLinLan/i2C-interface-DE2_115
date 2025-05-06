# NOTES:
#  - Make sure your working directory (cd) in ModelSim is
#    the folder containing this .do file and all the .v/.sv files.
#  - Adjust the quoted paths if your sources live in sub-folders.

# 1) Create work library
vlib work

# 2) Compile Verilog/SystemVerilog sources in dependency order
#    (timescale.v first, then macros, then controllers, then top, then wrapper)

vlog  "./timescale.v"
vlog  "./i2c_master_defines.v"
vlog  "./i2c_master_bit_ctrl.v"
vlog  "./i2c_master_byte_ctrl.v"
vlog  "./i2c_master_top.v"
vlog  "./i2c_master_single_byte.v"

# 3) Compile your testbench last
vlog  "./i2c_master_single_byte_tb.v"

# 4) Launch simulation
vsim -voptargs="+acc" -t 1ps -lib work i2c_master_single_byte_tb

# 5) Source your waveform setup
do    i2c_master_single_byte_wave.do

# 6) Open the views you like
view  wave
view  structure
view  signals

# 7) Run
run   -all

# End of script
