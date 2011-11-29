require 'mkmf'
$LIBS << ' gdi32.lib' # needed for input_box.c
$LIBS << ' Psapi.lib' # for GetProcessImageFileName
create_makefile("system")
