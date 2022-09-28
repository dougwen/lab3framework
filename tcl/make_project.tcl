 
set project_name "audioplayer"
create_project ${project_name} ./vivado -part xc7z020clg400-1 -force

set proj_dir [get_property directory [current_project]]
set obj [current_project]
 
add_files -fileset constrs_1 -norecurse ./src/toplevel.xdc
add_files -fileset sources_1 -norecurse ./src/toplevel.vhd
add_files -fileset sources_1 -norecurse ./src/lowlevel_dac_intfc.vhd
add_files -fileset sources_1 -norecurse ./src/clkdivider.vhd

# setup IP repository path and a couple other project options 
set_property target_language VHDL [current_project]

# Don't need an IP repository in this project since no IP
#set_property  ip_repo_paths  ./ip_repo [current_project]
#update_ip_catalog
 
#########################################################
# make block design, this is created by exporting the BD
#########################################################

source tcl/proc_system.tcl 


close_project

 
