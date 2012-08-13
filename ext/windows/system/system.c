#include "ruby.h"
#include <windows.h>
#include <winuser.h>
#include <tlhelp32.h>
#include <Psapi.h>
#include "autohotkey_stuff.h"
#include "input_box.h"
#include "clipboard_watcher.h"

VALUE mSystem;
VALUE mDesktop;
VALUE mScreen;
VALUE mClipboard;
VALUE cWindow;

struct KeybdEventParams {
  int vkcode;
  int scancode;
  DWORD flags;
};

struct InputBoxParams {
  LPCTSTR text;
  LPCTSTR title;
  LPTSTR result_text;
  int length;
};

struct MessageBoxParams {
  LPCWSTR text;
  LPCWSTR title;
};

static BOOL CALLBACK enum_windows_proc(HWND hwnd, LPARAM lParam)
{
  rb_yield(LONG2NUM((DWORD)hwnd));
  return TRUE;
}

static VALUE enum_windows(VALUE self) {
  EnumWindows(enum_windows_proc, 0);
  return Qnil;
}

static void call_keybd_event(struct KeybdEventParams *event) {
  #ifdef DEBUG
  printf("Sending key: vkcode: %d, scancode: %d\n", event.vkcode, event.scancode);
  #endif
  keybd_event(event->vkcode, event->scancode, event->flags, 0);
}

static VALUE f_keybd_event(int argc, VALUE* argv, VALUE self)
{
  VALUE vkcode, down, scancode, extended;
  struct KeybdEventParams event;
  rb_scan_args(argc, argv, "22", &vkcode, &down, &scancode, &extended);

  event.flags = 0;
  if (down != Qtrue)
    event.flags |= KEYEVENTF_KEYUP;
  if ( !(extended == Qnil || extended == Qfalse) )
    event.flags |= KEYEVENTF_EXTENDEDKEY;

  event.vkcode = NUM2INT(vkcode);
  event.scancode = (NIL_P(scancode) ? 0 : NUM2INT(scancode));
  rb_thread_blocking_region(call_keybd_event, &event, 0, 0);
  return Qnil;
}

static VALUE f_send_unicode_char_internal(VALUE self, VALUE character)
{
  INPUT inp[2];
  memset(inp,0,sizeof(INPUT));
  inp[0].type = INPUT_KEYBOARD;
  inp[0].ki.dwFlags = KEYEVENTF_UNICODE;
  inp[0].ki.wScan = *(LPCWSTR)RSTRING_PTR(character);
  inp[1] = inp[0];
  inp[1].ki.dwFlags |= KEYEVENTF_KEYUP;

  return SendInput(2, inp, sizeof(INPUT)) ? Qtrue : Qfalse;
}

/* Returns 'true' if successful, 'false' if not. */
static VALUE ForceWindowToFront(VALUE self)
{
  HWND TargetWindow = (HWND)NUM2ULONG(rb_iv_get(self, "@handle"));
  if (SetForegroundWindowEx(TargetWindow))
    return Qtrue;
  else
    return Qfalse;
}

static DWORD process_id(VALUE window)
{
  VALUE handle = rb_iv_get(window, "@handle");
  HWND window_handle = (HWND)NUM2ULONG(handle);

  DWORD process_id = 0;
  GetWindowThreadProcessId(window_handle, &process_id);
  return process_id;
}

static VALUE exe_path_internal(VALUE self)
{
    DWORD window_process_id = process_id(self);
    HANDLE process = OpenProcess(PROCESS_QUERY_INFORMATION,
                                 FALSE,
                                 window_process_id);
    #define BUFFER_LENGTH 512
    WCHAR buffer[BUFFER_LENGTH];
    DWORD num_chars = GetProcessImageFileNameW(process,
                                                 buffer,
                                                 BUFFER_LENGTH);
    if (num_chars) {
      return rb_str_new(buffer, sizeof(WCHAR) * num_chars);
    } else {
      return Qnil;
    }
}

static LPRECT get_window_rect(VALUE window, LPRECT rect)
{
  HWND window_handle = (HWND)NUM2ULONG(rb_iv_get(window, "@handle"));
  GetWindowRect(window_handle, rect);
  return rect;
}

static VALUE top(VALUE self)
{
  RECT rect;
  return LONG2NUM((get_window_rect(self, &rect)->top));
}


static VALUE right(VALUE self)
{
  RECT rect;
  return LONG2NUM((get_window_rect(self, &rect)->right));
}

static VALUE bottom(VALUE self)
{
  RECT rect;
  return LONG2NUM((get_window_rect(self, &rect)->bottom));
}

static VALUE left(VALUE self)
{
  RECT rect;
  return LONG2NUM((get_window_rect(self, &rect)->left));
}

static VALUE desktop_top(VALUE self)
{
  RECT work_area;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  return LONG2NUM(work_area.top);
}

static VALUE desktop_right(VALUE self)
{
  RECT work_area;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  return LONG2NUM(work_area.right);
}

static VALUE desktop_bottom(VALUE self)
{
  RECT work_area;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  return LONG2NUM(work_area.bottom);
}

static VALUE desktop_left(VALUE self)
{
  RECT work_area;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  return LONG2NUM(work_area.left);
}

static VALUE screen_width(VALUE self)
{
  return INT2NUM(GetSystemMetrics(SM_CXSCREEN));
}

static VALUE screen_height(VALUE self)
{
  return INT2NUM(GetSystemMetrics(SM_CYSCREEN));
}

static VALUE get_console_window(VALUE self)
{
  /* Cast to ULONG_PTR to neutralize a compiler warning. */
  return LONG2NUM((ULONG_PTR)GetConsoleWindow());
}

static VALUE call_message_box(struct MessageBoxParams *params)
{
  int result = MessageBoxW(0, params->text, params->title,
                           MB_OKCANCEL | MB_TOPMOST | MB_SETFOREGROUND);
  return result == IDOK ? Qtrue : Qfalse;
}

static VALUE message_box_internal(VALUE self, VALUE text, VALUE title)
{
  struct MessageBoxParams params;
  params.text  = (LPCWSTR)RSTRING_PTR(text);
  params.title = (LPCWSTR)RSTRING_PTR(title);
  return rb_thread_blocking_region(call_message_box, &params, 0, 0);
}

static VALUE call_input_box(struct InputBoxParams *params)
{
  return INT2FIX(input_box(params->text, params->title,
                           params->result_text, params->length));
}

static VALUE input_box_internal(VALUE self, VALUE text, VALUE title,
                                VALUE result_text)
{
  struct InputBoxParams params;
  params.text        = RSTRING_PTR(text);
  params.title       = RSTRING_PTR(title);
  params.result_text = RSTRING_PTR(result_text);
  params.length      = RSTRING_LEN(result_text)/2;

  return rb_thread_blocking_region(call_input_box, &params, 0, 0);
}


void Init_system() {
  input_box_initialize(GetModuleHandle(NULL));
  autohotkey_stuff_initialize(GetCurrentThreadId());

  mSystem    = rb_define_module_under(rb_define_module("Rum"), "System");
  mDesktop   = rb_define_module_under(mSystem, "Desktop");
  mScreen    = rb_define_module_under(mSystem, "Screen");
  mClipboard = rb_define_module_under(mSystem, "Clipboard");
  cWindow    = rb_define_class_under(mSystem, "Window", rb_cObject);

  rb_define_method(mSystem, "enum_windows", enum_windows, 0);
  rb_define_method(mSystem, "keybd_event", f_keybd_event, -1);
  rb_define_method(mSystem, "send_unicode_char_internal", f_send_unicode_char_internal, 1);
  rb_define_method(mSystem, "get_console_window", get_console_window, 0);
  rb_define_method(mSystem, "message_box_internal", message_box_internal, 2);
  rb_define_method(mSystem, "input_box_internal", input_box_internal, 3);

  rb_define_method(cWindow, "show", ForceWindowToFront, 0);
  rb_define_method(cWindow, "exe_path_internal", exe_path_internal, 0);
  rb_define_method(cWindow, "left", left, 0);
  rb_define_method(cWindow, "right", right, 0);
  rb_define_method(cWindow, "top", top, 0);
  rb_define_method(cWindow, "bottom", bottom, 0);

  rb_define_module_function(mDesktop, "top", desktop_top, 0);
  rb_define_module_function(mDesktop, "left", desktop_left, 0);
  rb_define_module_function(mDesktop, "bottom", desktop_bottom, 0);
  rb_define_module_function(mDesktop, "right", desktop_right, 0);

  rb_define_module_function(mScreen, "width", screen_width, 0);
  rb_define_module_function(mScreen, "height", screen_height, 0);

  rb_define_method(mClipboard, "install_watcher", install_watcher, 0);
  rb_define_method(mClipboard, "evaluate_watcher", evaluate_watcher, 2);
}
