onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /wrapper/inst_axi2ahb/HCLK
add wave -noupdate /wrapper/inst_axi2ahb/HRESETn
add wave -noupdate -divider -height 20 {AXI Slave Interface}
add wave -noupdate -divider {AW channel}
add wave -noupdate /wrapper/axi_aw_id
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_aw_addr_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_aw_len_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_aw_size_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_aw_burst_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_aw_valid_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_aw_ready_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/aw_ack
add wave -noupdate -divider {W channel}
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_w_data_i
add wave -noupdate -radix binary -childformat {{{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[7]} -radix binary} {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[6]} -radix binary} {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[5]} -radix binary} {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[4]} -radix binary} {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[3]} -radix binary} {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[2]} -radix binary} {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[1]} -radix binary} {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[0]} -radix binary}} -subitemconfig {{/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[7]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[6]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[5]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[4]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[3]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[2]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[1]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i[0]} {-height 15 -radix binary}} /wrapper/inst_axi2ahb/inst_request_path/axi_w_strb_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_w_last_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_w_valid_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_w_ready_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/w_ack
add wave -noupdate -divider {B channel}
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_b_id_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_b_resp_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_b_valid_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_b_ready_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/write_b_ack
add wave -noupdate -divider {AR channel}
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_ar_addr_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_ar_len_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_ar_size_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_ar_burst_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_ar_valid_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/axi_ar_ready_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_request_path/ar_ack
add wave -noupdate -divider {R channel}
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_r_data_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_r_resp_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_r_last_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_r_valid_o
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/axi_r_ready_i
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/r_ack
add wave -noupdate /wrapper/inst_axi2ahb/inst_response_path/r_last
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
add wave -noupdate -color {Orange Red} /wrapper/inst_axi2ahb/HREADY
add wave -noupdate /wrapper/inst_axi2ahb/HRESP
add wave -noupdate -divider {Assertion signals}
add wave -noupdate /wrapper/inst_axi2ahb/control_signals_cannot_change
add wave -noupdate /wrapper/inst_axi2ahb/addr
add wave -noupdate -divider {Unaligned address}
add wave -noupdate /wrapper/inst_axi2ahb/aligned_addr
add wave -noupdate /wrapper/inst_axi2ahb/address_is_unaligned
add wave -noupdate -divider {W strobes}
add wave -noupdate /wrapper/inst_axi2ahb/split
add wave -noupdate /wrapper/inst_axi2ahb/start_splitting
add wave -noupdate /wrapper/inst_axi2ahb/keep_splitting
add wave -noupdate -radix binary /wrapper/inst_axi2ahb/axi_w_strb_i
add wave -noupdate -radix binary /wrapper/inst_axi2ahb/w_strobes
add wave -noupdate -radix binary /wrapper/inst_axi2ahb/strobe_buffer
add wave -noupdate -radix decimal /wrapper/inst_axi2ahb/lower_byte_lane
add wave -noupdate -radix decimal /wrapper/inst_axi2ahb/upper_byte_lane
add wave -noupdate -radix binary /wrapper/inst_axi2ahb/local_strb
add wave -noupdate /wrapper/inst_axi2ahb/all_strobes_ace
add wave -noupdate -divider -height 20 {More info}
add wave -noupdate /wrapper/inst_axi2ahb/waiting_split_to_end
add wave -noupdate /wrapper/inst_axi2ahb/w_next_state_busy
add wave -noupdate /wrapper/inst_axi2ahb/aligned_address
add wave -noupdate /wrapper/inst_axi2ahb/can_accept_AW
add wave -noupdate -radix binary -childformat {{{/wrapper/inst_axi2ahb/axi_w_strb_i[7]} -radix binary} {{/wrapper/inst_axi2ahb/axi_w_strb_i[6]} -radix binary} {{/wrapper/inst_axi2ahb/axi_w_strb_i[5]} -radix binary} {{/wrapper/inst_axi2ahb/axi_w_strb_i[4]} -radix binary} {{/wrapper/inst_axi2ahb/axi_w_strb_i[3]} -radix binary} {{/wrapper/inst_axi2ahb/axi_w_strb_i[2]} -radix binary} {{/wrapper/inst_axi2ahb/axi_w_strb_i[1]} -radix binary} {{/wrapper/inst_axi2ahb/axi_w_strb_i[0]} -radix binary}} -subitemconfig {{/wrapper/inst_axi2ahb/axi_w_strb_i[7]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/axi_w_strb_i[6]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/axi_w_strb_i[5]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/axi_w_strb_i[4]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/axi_w_strb_i[3]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/axi_w_strb_i[2]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/axi_w_strb_i[1]} {-height 15 -radix binary} {/wrapper/inst_axi2ahb/axi_w_strb_i[0]} {-height 15 -radix binary}} /wrapper/inst_axi2ahb/axi_w_strb_i
add wave -noupdate -radix decimal /wrapper/inst_axi2ahb/cycle_counter
add wave -noupdate /wrapper/inst_axi2ahb/pending_write
add wave -noupdate /wrapper/inst_axi2ahb/pending_read
add wave -noupdate /wrapper/inst_axi2ahb/write_last_beat_ack
add wave -noupdate /wrapper/inst_axi2ahb/error_reg
add wave -noupdate -divider Buffers
add wave -noupdate /wrapper/inst_axi2ahb/aw_address_buffer
add wave -noupdate /wrapper/inst_axi2ahb/ar_address_buffer
add wave -noupdate /wrapper/inst_axi2ahb/aw_len_buffer
add wave -noupdate /wrapper/inst_axi2ahb/ar_len_buffer
add wave -noupdate /wrapper/inst_axi2ahb/aw_size_buffer
add wave -noupdate /wrapper/inst_axi2ahb/ar_size_buffer
add wave -noupdate -divider {ID queue}
add wave -noupdate /wrapper/inst_axi2ahb/ID_queue/push_in
add wave -noupdate /wrapper/inst_axi2ahb/ID_queue/push_data_in
add wave -noupdate /wrapper/inst_axi2ahb/ID_queue/pop_in
add wave -noupdate /wrapper/inst_axi2ahb/ID_queue/pop_data_out
add wave -noupdate /wrapper/inst_axi2ahb/ID_queue/valid
add wave -noupdate /wrapper/inst_axi2ahb/ID_queue/ready
add wave -noupdate -divider {B queue}
add wave -noupdate /wrapper/inst_axi2ahb/B_queue/push
add wave -noupdate /wrapper/inst_axi2ahb/B_queue/push_data
add wave -noupdate /wrapper/inst_axi2ahb/B_queue/pop
add wave -noupdate /wrapper/inst_axi2ahb/B_queue/pop_data
add wave -noupdate /wrapper/inst_axi2ahb/B_queue/ready
add wave -noupdate /wrapper/inst_axi2ahb/B_queue/valid
add wave -noupdate -divider {R queue}
add wave -noupdate /wrapper/inst_axi2ahb/R_queue/push_in
add wave -noupdate /wrapper/inst_axi2ahb/R_queue/push_data_in
add wave -noupdate /wrapper/inst_axi2ahb/R_queue/pop_in
add wave -noupdate /wrapper/inst_axi2ahb/R_queue/pop_data_out
add wave -noupdate /wrapper/inst_axi2ahb/R_queue/ready
add wave -noupdate /wrapper/inst_axi2ahb/R_queue/valid
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {81373 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 312
configure wave -valuecolwidth 109
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
WaveRestoreZoom {81348 ns} {81509 ns}
