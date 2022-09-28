vivado -nolog -nojournal -mode batch -source ./tcl/make_project.tcl
vivado -nolog -nojournal -mode batch -source ./tcl/impl.tcl
xsct ./tcl/make_sw.tcl
