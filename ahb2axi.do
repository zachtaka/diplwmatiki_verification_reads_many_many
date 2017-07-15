onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider -height 25 {AHB 2 AXI}
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HCLK
add wave -noupdate -divider AHB
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HBURST
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/burst_type
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HSIZE
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HTRANS
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/state
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HADDR
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HREADY
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HWRITE
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HWDATA
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/HRESP
add wave -noupdate -divider AXI
add wave -noupdate -divider {AW signals}
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_aw_burst_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_burst
add wave -noupdate -radix decimal /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_aw_size_o
add wave -noupdate -radix decimal /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_aw_len_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_aw_addr_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_aw_valid_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_aw_ready_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_aw_ack
add wave -noupdate -divider {W signals}
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_w_data_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_w_strb_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_w_last_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_w_valid_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_w_ready_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_w_ack
add wave -noupdate -divider {B signals}
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_b_resp_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_b_valid_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_b_ready_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_write_ack
add wave -noupdate -divider {Further info signals}
add wave -noupdate -radix decimal /top/inst_axi2ahb_ahb2axi/ahb2axi/current_beat
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/loose_logic
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/burst_buffer
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/pending_write
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/pending_read
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/write_data_phase
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/addr_buffer
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_read_ack
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/valid_wait_aw_ready
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/valid_wait_ar_ready
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/valid_wait_w_ready
add wave -noupdate -divider {AR signals}
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_ar_burst_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_ar_size_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_ar_len_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_ar_addr_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_ar_valid_o
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_ar_ready_i
add wave -noupdate -divider {R signals}
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_r_data_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_r_last_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_r_resp_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_r_valid_i
add wave -noupdate /top/inst_axi2ahb_ahb2axi/ahb2axi/axi_r_ready_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1083 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 312
configure wave -valuecolwidth 136
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
configure wave -timelineunits us
update
WaveRestoreZoom {564 ns} {1919 ns}
