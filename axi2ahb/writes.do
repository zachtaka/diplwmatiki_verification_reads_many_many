onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /wrapper/inst_axi2ahb/HCLK
add wave -noupdate /wrapper/inst_axi2ahb/HRESETn
add wave -noupdate -divider -height 20 {AXI Slave Interface}
add wave -noupdate -divider {AW channel}
add wave -noupdate /wrapper/inst_axi2ahb/axi_aw_addr_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_aw_len_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_aw_size_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_aw_burst_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_burst
add wave -noupdate /wrapper/inst_axi2ahb/axi_aw_valid_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_aw_ready_o
add wave -noupdate -divider {W channel}
add wave -noupdate /wrapper/inst_axi2ahb/axi_w_data_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_w_strb_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_w_last_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_w_valid_i
add wave -noupdate /wrapper/inst_axi2ahb/axi_w_ready_o
add wave -noupdate -divider {B channel}
add wave -noupdate /wrapper/inst_axi2ahb/axi_b_resp_o
add wave -noupdate /wrapper/inst_axi2ahb/axi_b_valid_o
add wave -noupdate /wrapper/inst_axi2ahb/axi_b_ready_i
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
WaveRestoreCursors {{Cursor 1} {44 ns} 0}
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
WaveRestoreZoom {101 ns} {311 ns}
