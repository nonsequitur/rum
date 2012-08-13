#include "ruby.h"
#include <windows.h>

static BOOL observe_messages() {
  MSG msg;
  while (GetMessage(&msg, 0, 0, 0) == 1) {
    switch (msg.message)
      {
      case WM_APP:
        return 1;
      case WM_TIMER:
        return 0;
      }
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }
  return 0;
}

static LRESULT APIENTRY
clipboard_hook(HWND hwnd, UINT umsg, WPARAM wparam, LPARAM lparam) {
  HWND next_viewer = (HWND)GetWindowLongPtr(hwnd, GWL_USERDATA);
  switch (umsg)
    {
    case WM_DRAWCLIPBOARD:
      /* A stop signal for observe_messages() */
      PostMessage(hwnd, WM_APP, 0, 0);
      if (next_viewer != 0)
        PostMessage(next_viewer, umsg, wparam, lparam);
      return 0;
    case WM_CHANGECBCHAIN:
      if ((HWND)wparam == next_viewer)
        SetWindowLongPtr(hwnd, GWL_USERDATA, (LONG_PTR)lparam);
      else if (next_viewer != 0)
        PostMessage(next_viewer, umsg, wparam, lparam);
      return 0;
    default:
      return DefWindowProc(hwnd, umsg, wparam, lparam);
    }
}

VALUE install_watcher(VALUE self)
{
  HWND hwnd = (HWND)CreateWindow("static", "rum-clipboard-watcher",
                                   0, 0, 0, 0, 0, 0, 0, 0, 0);
  SetWindowLongPtr(hwnd, GWL_USERDATA, (LONG_PTR)SetClipboardViewer(hwnd));
  SetWindowLongPtr(hwnd, GWL_WNDPROC,  (LONG_PTR)clipboard_hook);
  return LONG2NUM((ULONG_PTR)hwnd);
}

VALUE evaluate_watcher(VALUE self, VALUE window, VALUE timeout)
{
  HWND hwnd   = (HWND)NUM2ULONG(window);
  UINT timer  = SetTimer(hwnd, 1, NUM2INT(timeout), 0);
  BOOL result = rb_thread_blocking_region(observe_messages, 0, 0, 0);
  DestroyWindow(hwnd); /* The timer is destroyed along with the window */
  return(result ? Qtrue : Qfalse);
}
