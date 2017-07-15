onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /wrapper/inst_axi2ahb/HCLK
add wave -noupdate /wrapper/inst_axi2ahb/HRESETn
add wave -noupdate -divider -height 20 {AXI Slave Interface}
add wave -noupdate -divider {AR channel}
add wave -noupdate /wrapper/inst_axi2ahb/axi_ar_addr_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_ar_len_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_ar_size_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_ar_burst_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_ar_valid_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_ar_ready_o
add wave -noupdate -divider {R channel}
add wave -noupdate /wrapper/inst_axi2ahb/axi_r_data_o
add wave -noupdate /wrapper/inst_axi2ahb/axi_r_resp_o
add wave -noupdate /wrapper/inst_axi2ahb/axi_r_last_o
add wave -noupdate /wrapper/inst_axi2ahb/axi_r_valid_o
add wave -noupdate /wrapper/inst_axi2ahb/axi_r_ready_i
add wave -noupdate -divider {AHB Master Interface}
add wave -noupdate /wrapper/inst_axi2ahb/HTRANS
add wave -noupdate /wrapper/inst_axi2ahb/state
add wave -noupdate /wrapper/inst_axi2ahb/HADDR
add wave -noupdate /wrapper/inst_axi2ahb/HSIZE
add wave -noupdate /wrapper/inst_axi2ahb/HBURST
add wave -noupdate /wrapper/inst_axi2ahb/burst_type
add wave -noupdate /wrapper/inst_axi2ahb/HWRITE
add wave -noupdate /wrapper/inst_axi2ahb/HWDATA
add wave -noupdate /wrapper/inst_axi2ahb/HRDATA
add wave -noupdate /wrapper/inst_axi2ahb/HREADY
add wave -noupdate /wrapper/inst_axi2ahb/HRESP
add wave -noupdate /wrapper/inst_axi2ahb/response
add wave -noupdate -divider {More info}
add wave -noupdate /wrapper/inst_axi2ahb/r_ack
add wave -noupdate /wrapper/inst_axi2ahb/r_last
add wave -noupdate /wrapper/inst_axi2ahb/pending_read
add wave -noupdate /wrapper/inst_axi2ahb/ar_len_buffer
add wave -noupdate /wrapper/inst_axi2ahb/ar_size_buffer
add wave -noupdate /wrapper/inst_axi2ahb/ar_address_buffer
add wave -noupdate /wrapper/inst_axi2ahb/read_data_phase
add wave -noupdate /wrapper/inst_axi2ahb/aw_ack
add wave -noupdate /wrapper/inst_axi2ahb/w_ack
add wave -noupdate -radix decimal /wrapper/inst_axi2ahb/cycle_counter
add wave -noupdate /wrapper/inst_axi2ahb/pending_write
add wave -noupdate /wrapper/inst_axi2ahb/waiting_for_slave_response
add wave -noupdate /wrapper/inst_axi2ahb/write_last_beat_ack
add wave -noupdate /wrapper/inst_axi2ahb/write_b_ack
add wave -noupdate /wrapper/inst_axi2ahb/write_data_phase
add wave -noupdate /wrapper/inst_axi2ahb/aw_len_buffer
add wave -noupdate /wrapper/inst_axi2ahb/aw_size_buffer
add wave -noupdate /wrapper/inst_axi2ahb/aw_address_buffer
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {40 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 330
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {195 ns}
