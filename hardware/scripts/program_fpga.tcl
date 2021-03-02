
set bitstream_file [lindex $argv 0]

if {![file exists $bitstream_file]} {
    puts "Invalid bitstream file!"
    exit
}

open_hw
connect_hw_server
open_hw_target

set_property PROGRAM.FILE ${bitstream_file} [get_hw_devices xc7z020_1]

current_hw_device [get_hw_devices xc7z020_1]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7z020_1] 0]
program_hw_devices [get_hw_devices xc7z020_1]
refresh_hw_device [lindex [get_hw_devices xc7z020_1] 0]
