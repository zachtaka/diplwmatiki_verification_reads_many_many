onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /wrapper/inst_ahb_s/HCLK
add wave -noupdate /wrapper/inst_ahb_s/HRESETn
add wave -noupdate -divider {AHB SLAVE}
add wave -noupdate /wrapper/inst_ahb_s/HTRANS
add wave -noupdate /wrapper/inst_ahb_s/state
add wave -noupdate /wrapper/inst_ahb_s/HBURST
add wave -noupdate /wrapper/inst_ahb_s/burst_type
add wave -noupdate /wrapper/inst_ahb_s/HADDR
add wave -noupdate /wrapper/inst_ahb_s/HSIZE
add wave -noupdate /wrapper/inst_ahb_s/HWRITE
add wave -noupdate /wrapper/inst_ahb_s/HWDATA
add wave -noupdate /wrapper/inst_ahb_s/HRDATA
add wave -noupdate /wrapper/inst_ahb_s/HREADY
add wave -noupdate -divider {more info}
add wave -noupdate /wrapper/inst_ahb_s/HRESP
add wave -noupdate /wrapper/inst_ahb_s/HEXOKAY
add wave -noupdate /wrapper/inst_ahb_s/size
add wave -noupdate /wrapper/inst_ahb_s/response
add wave -noupdate /wrapper/inst_ahb_s/will_i_stall
add wave -noupdate /wrapper/inst_ahb_s/start_address
add wave -noupdate /wrapper/inst_ahb_s/aligned_address
add wave -noupdate /wrapper/inst_ahb_s/number_bytes
add wave -noupdate /wrapper/inst_ahb_s/upper_byte_lane
add wave -noupdate /wrapper/inst_ahb_s/lower_byte_lane
add wave -noupdate /wrapper/inst_ahb_s/data_bus_bytes
add wave -noupdate /wrapper/inst_ahb_s/data
add wave -noupdate /wrapper/inst_ahb_s/tmp0
add wave -noupdate /wrapper/inst_ahb_s/pending
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {82 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 316
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
WaveRestoreZoom {0 ns} {291 ns}
