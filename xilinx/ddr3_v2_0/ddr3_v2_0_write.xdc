create_clock -name ddr3_refclk -period 5 [get_pins *_sys_clk_200mhz_buf/O] 
create_generated_clock -name ddr3_usrclk -source [get_pins *sys_clk_200mhz_buf/O] -multiply_by 5 -divide_by 5 [get_pins *ddr3_ctrl/CLK]

set_clock_groups -asynchronous -group {clk_125mhz} -group {ddr3_usrclk}
set_clock_groups -asynchronous -group {clk_125mhz} -group {ddr3_refclk}
