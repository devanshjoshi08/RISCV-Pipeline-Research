## Clock-only constraint for OOC synthesis (no IOSTANDARD — no pads in OOC mode)
create_clock -period 5.000 -name clk [get_ports clk]
