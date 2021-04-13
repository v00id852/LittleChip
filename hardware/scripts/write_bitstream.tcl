
#set project_name "z1top"
set project_name [lindex $argv 0]

set sources_file scripts/${project_name}.tcl

if {![file exists $sources_file]} {
    puts "Invalid project name!"
    exit
}
open_project ${project_name}_proj/${project_name}_proj.xpr

set sources_file scripts/${project_name}.tcl
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1
wait_on_run synth_1 -verbose

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {   
  error "ERROR: synth_1 failed"   
} 

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1 -verbose

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {   
  error "ERROR: impl_1 failed"   
} 

write_hwdef -force  -file ${project_name}_proj/${project_name}_proj.sdk/hwdef.zip
exec unzip ${project_name}_proj/${project_name}_proj.sdk/hwdef.zip -d ${project_name}_proj/${project_name}_proj.sdk

# Backup bitstream
file mkdir bitstream_files
file copy -force [glob ${project_name}_proj/${project_name}_proj.runs/impl_1/*.bit] bitstream_files/${project_name}.bit

