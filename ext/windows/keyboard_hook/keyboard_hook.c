#include "ruby.h"
#include <windows.h>
#include <stdio.h>
/* #define DEBUG */

VALUE mKeyboardHook;
VALUE cEvent;
VALUE ruby_callback_proc;
int id_call;
HHOOK keyboard_hook;
BOOL in_ruby_level = 0;
DWORD thread=0;
struct KeyEvent {
  int vkcode;
  int scancode;
  BOOL down;
  BOOL injected;
};

static BOOL pass_key_event_to_ruby(struct KeyEvent *key_event) {
  VALUE event_attributes[] = { INT2NUM(key_event->vkcode),
                               INT2NUM(key_event->scancode),
                               (key_event->down ? Qtrue : Qfalse) };
  VALUE event = rb_class_new_instance(3, event_attributes, cEvent);
  
  return (Qtrue == rb_funcall(ruby_callback_proc, id_call, 1, event));
}

static LRESULT CALLBACK
callback_function(int Code, WPARAM wParam, LPARAM lParam)
{
  PKBDLLHOOKSTRUCT kbd = (PKBDLLHOOKSTRUCT)lParam;
  BOOL pass;
  struct KeyEvent key_event;

  #ifdef DEBUG
  puts("Enter Callback");
  #endif
  
  key_event.vkcode   = kbd->vkCode;
  key_event.scancode = kbd->scanCode;
  key_event.down     = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
  key_event.injected = (kbd->flags & 0x10);

  #ifdef DEBUG
  printf(key_event.down ? "Down" : "Up");
  printf(": Vkcode: %d, Scancode: %d\n", kbd->vkCode, kbd->scanCode);
  #endif

  if (Code < 0) {
    #ifdef DEBUG
    puts("Skipping event.");
    #endif
    pass=1;
  }
  else if (key_event.injected) {
    #ifdef DEBUG
    puts("Injected. Skipping event.");
    #endif
    pass=1;
  }
  else if (in_ruby_level) {
    #ifdef DEBUG
    puts("Already in Ruby level. Pass event to Ruby.");
    #endif
    pass=pass_key_event_to_ruby(&key_event);
  }
  else {
    #ifdef DEBUG
    puts("Pass event to Ruby.");
    #endif
    in_ruby_level = 1;
    pass=rb_thread_call_with_gvl(pass_key_event_to_ruby, &key_event);
    in_ruby_level = 0;
  }
  #ifdef DEBUG
  puts("Exit Callback\n\n");
  #endif
  if (pass)
    return CallNextHookEx(keyboard_hook, Code, wParam, lParam);
  else
    return 1;
}

static void pump_messages() {
  MSG msg;
  while (GetMessage(&msg, 0, 0, 0) == 1) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }
  /* Missing: Error handling when GetMessage returns -1 */
}

static VALUE start(int argc, VALUE* argv, VALUE self)
{
    HMODULE module = GetModuleHandle(NULL);
    thread = GetCurrentThreadId();
    rb_scan_args(argc, argv, "0&", &ruby_callback_proc);
    
    keyboard_hook = SetWindowsHookEx(WH_KEYBOARD_LL, (HOOKPROC)callback_function,
                                     module, 0);
    rb_thread_blocking_region(pump_messages, 0, 0, 0);
    UnhookWindowsHookEx(keyboard_hook);
    return self;
}

static VALUE stop(VALUE self)
{
  if (thread) {
    PostThreadMessage(thread, WM_QUIT, 0, 0);
    thread = 0;
    return Qtrue;
  } else {
    return Qfalse;
  }
}

void Init_keyboard_hook() {
  mKeyboardHook = rb_define_module("KeyboardHook");
  rb_define_module_function(mKeyboardHook, "start", start, -1);
  rb_define_module_function(mKeyboardHook, "stop", stop, 0);
  id_call = rb_intern("call");
  cEvent = rb_const_get(rb_const_get(rb_cObject, rb_intern("KeyboardHook")),
                       rb_intern("Event"));
  rb_global_variable(&ruby_callback_proc);
}
