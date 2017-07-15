onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/clk
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/rst_n
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/state
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/HADDR
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/HSIZE
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/HWRITE
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/HREADY
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/HWDATA
add wave -noupdate -divider {More info}
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/write_data_phase
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/waiting_for_HREADY
add wave -noupdate /wrapper/inst_ahb_bytes_to_send_logger/address
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {50 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 380
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
WaveRestoreZoom {24 ns} {138 ns}
