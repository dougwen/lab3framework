setws ./vitis
platform create -name hwplat -hw ./vivado/audioplayer.xsa
domain create -name {standalone_ps7_cortexa9_0} -display-name {standalone_ps7_cortexa9_0} -os {standalone} -proc {ps7_cortexa9_0} -runtime {cpp} -arch {32-bit} -support-app {hello_world}
platform write
platform active {hwplat}
domain active {zynq_fsbl}
domain active {standalone_ps7_cortexa9_0}
platform generate -quick

platform active hwplat
app create -name lab4_app
importsources -name lab4_app -path ./src/proc_software -linker-script
app build lab4_app
sysproj build -name lab4_app_system
