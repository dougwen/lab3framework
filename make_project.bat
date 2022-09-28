call vivado -nolog -nojournal -mode=batch -source=./tcl/make_project.tcl
call vivado -nolog -nojournal -mode=batch -source=./tcl/impl.tcl
call xsct ./tcl/make_sw.tcl
