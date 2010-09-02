require 'mkmf'
$LIBS << ' gdi32.lib' # needed for input_box.c
create_makefile("system")
