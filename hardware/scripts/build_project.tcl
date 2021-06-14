
#set project_name "z1top"
set project_name [lindex $argv 0]
set target_clock [lindex $argv 1]

set sources_file scripts/${project_name}.tcl

if {![file exists $sources_file]} {
    puts "Invalid project name!"
    exit
}

if {[file exists ${project_name}_proj/${project_name}_proj.xpr]} {
  open_project ${project_name}_proj/${project_name}_proj.xpr
} elseif {${project_name} eq "a7top"} {
  create_project -force ${project_name}_proj ${project_name}_proj -part xc7a100tcsg324-1
  set_property board_part digilentinc.com:arty-a7-100:part0:1.0 [current_project]
} else {
  create_project -force ${project_name}_proj ${project_name}_proj -part xc7z020clg400-1
  set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]
}

source $sources_file

# Add constraint file
if {${project_name} eq "a7top"} {
  add_files -fileset constrs_1 -norecurse constr/arty-a7.xdc
} else {
  add_files -fileset constrs_1 -norecurse constr/pynq-z1.xdc
}

update_compile_order -fileset sources_1

check_syntax

update_compile_order -fileset sources_1
