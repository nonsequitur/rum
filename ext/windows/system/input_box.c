
/* Inspired by https://sourceforge.net/projects/cinputbox */

#define UNICODE
#include <windows.h>
#include <stdio.h>
#include "input_box.h"

#define IB_CLASS_NAME L"RumInputBox"
#define IB_WIDTH 300
#define IB_HEIGHT 130
#define IB_SPAN 10
#define IB_LEFT_OFFSET 6
#define IB_TOP_OFFSET 4
#define IB_BTN_WIDTH 60
#define IB_BTN_HEIGHT 20

typedef struct {
  HWND  main_window, text, ok, cancel, edit_control;
  LPTSTR result_text;
  INT  max_chars, result;
  HINSTANCE instance;
} InputBox;

HMODULE global_instance;

static void input_box_populate_window(InputBox *box, HWND blank_window)
{
  NONCLIENTMETRICS metrics;
  HFONT	font;
  
  box->main_window = blank_window;

  box->text = CreateWindow(L"Static", L"",
                            WS_CHILD | WS_VISIBLE,
                            IB_LEFT_OFFSET, IB_TOP_OFFSET,
                            IB_WIDTH-IB_LEFT_OFFSET*2, IB_BTN_HEIGHT*2,
                            box->main_window, NULL,
                            box->instance, NULL);
  box->edit_control = CreateWindow(L"Edit", L"",
                                   (WS_CHILD | WS_VISIBLE | WS_BORDER |
                                    ES_AUTOHSCROLL | ES_LEFT),
                                   IB_LEFT_OFFSET,
                                   IB_TOP_OFFSET + IB_BTN_HEIGHT*2,
                                   IB_WIDTH-IB_LEFT_OFFSET*3, IB_BTN_HEIGHT,
                                   box->main_window, NULL,
                                   box->instance, NULL);
  box->ok = CreateWindow(L"Button", L"OK",
                         WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
                         IB_WIDTH/2 - IB_SPAN*2 - IB_BTN_WIDTH,
                         IB_HEIGHT - IB_TOP_OFFSET*4 - IB_BTN_HEIGHT*2,
                         IB_BTN_WIDTH, IB_BTN_HEIGHT,
                         box->main_window, (HMENU)IDOK,
                         box->instance, NULL);
  box->cancel = CreateWindow(L"Button", L"Cancel",
                             WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
                             IB_WIDTH/2 + IB_SPAN,
                             IB_HEIGHT - IB_TOP_OFFSET*4 - IB_BTN_HEIGHT*2,
                             IB_BTN_WIDTH, IB_BTN_HEIGHT,
                             box->main_window, (HMENU)IDCANCEL,
                             box->instance, NULL);

  font = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
  
  SendMessage(box->text,WM_SETFONT,(WPARAM)font,FALSE);
  SendMessage(box->edit_control,WM_SETFONT,(WPARAM)font,FALSE);
  SendMessage(box->ok,WM_SETFONT,(WPARAM)font,FALSE);
  SendMessage(box->cancel,WM_SETFONT,(WPARAM)font,FALSE);
}

static void input_box_close(InputBox *box)
{
  PostMessage(box->main_window, WM_CLOSE, 0, 0);
}

static void input_box_submit(InputBox *box)
{
  int input_length = (int)SendMessage(box->edit_control, EM_LINELENGTH, 0, 0);
  if (input_length){
    // Provide the max number of chars to be copied to the buffer.
    *((LPWORD)box->result_text) = box->max_chars;
    // Although undocumented, the copied string is null-terminated.
    input_length = (WORD)SendMessage(box->edit_control, EM_GETLINE, 0,
                                     (LPARAM)box->result_text);
  }
  box->result = input_length;
}

LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
  InputBox *box = (InputBox*)GetWindowLong(hwnd, GWL_USERDATA);
  
  switch(msg)
    {
    case WM_CREATE:
      box = (InputBox *) ((CREATESTRUCT *)lParam)->lpCreateParams;
      SetWindowLong(hwnd, GWL_USERDATA, (long)box);
      input_box_populate_window(box, hwnd);
      break;
    case WM_COMMAND:
      switch(LOWORD(wParam)) {
      case IDOK:
        input_box_submit(box);
      case IDCANCEL:
        input_box_close(box);
        break;
      }
      break;
    case WM_SETFOCUS:
      SetFocus(box->edit_control);
      break;
    case WM_CLOSE:
      DestroyWindow(hwnd);
      break;
    case WM_DESTROY:
      PostQuitMessage(0);
      break;
    }
  return DefWindowProc(hwnd, msg, wParam, lParam);
}

void input_box_register_window_class(HINSTANCE instance)
{
  WNDCLASSEX wndInputBox;

  wndInputBox.cbSize = sizeof(wndInputBox);
  wndInputBox.style = CS_HREDRAW | CS_VREDRAW;
  wndInputBox.lpszClassName = IB_CLASS_NAME;
  wndInputBox.lpfnWndProc = window_proc;
  wndInputBox.lpszMenuName = NULL;
  wndInputBox.cbClsExtra = 0;
  wndInputBox.cbWndExtra = 0;
  wndInputBox.hInstance = instance;
  wndInputBox.hIcon = LoadIcon(NULL, IDI_QUESTION);
  wndInputBox.hIconSm = NULL;
  wndInputBox.hCursor = LoadCursor(NULL, IDC_ARROW);
  wndInputBox.hbrBackground = (HBRUSH)(COLOR_WINDOW);

  if(!RegisterClassEx(&wndInputBox))
    {
      MessageBox(NULL, L"Window Registration Failed!", L"Error!",
                 MB_ICONEXCLAMATION | MB_OK);
    }
}

void input_box_unregister_window_class(InputBox *box)
{
  UnregisterClass(IB_CLASS_NAME, box->instance);
}

static void input_box_show(InputBox *box, LPCTSTR title, LPCTSTR text,
                           LPTSTR result_text, int max_chars)
{
  box->result_text = result_text;
  box->max_chars   = max_chars;
  box->result      = 0;

  SetWindowText(box->main_window, title);
  SetWindowText(box->edit_control, result_text);
  SetWindowText(box->text, text);
  SendMessage(box->edit_control, EM_LIMITTEXT,
              max_chars-1, // Leave room for the terminating null char.
              0);
  SendMessage(box->edit_control, EM_SETSEL, 0, -1); // Select the whole text
  ShowWindow(box->main_window, SW_SHOWNORMAL);
}

static void input_box_create(InputBox *box, HINSTANCE instance)
{
  RECT rect;

  GetWindowRect(GetDesktopWindow(), &rect);
  
  box->instance    = instance;
  box->main_window = CreateWindowEx(WS_EX_TOPMOST,
                                    IB_CLASS_NAME, L"",
                                    (WS_BORDER | WS_CAPTION | WS_SYSMENU),
                                    (rect.left + rect.right - IB_WIDTH)/2,
                                    (rect.top + rect.bottom - IB_HEIGHT)/2,
                                    IB_WIDTH, IB_HEIGHT,
                                    GetForegroundWindow(), 0,
                                    instance, box);
}



static void input_box_destroy(InputBox *box)
{
  SendMessage(box->main_window, WM_DESTROY, 0, 0);
}


void input_box_initialize(HINSTANCE instance)
{
  global_instance = instance;
  input_box_register_window_class(instance);
}

int input_box(LPCTSTR text, LPCTSTR title,
              LPTSTR result_text, int max_chars)
{
  MSG msg;
  InputBox box;
  
  input_box_create(&box, global_instance);
  
  input_box_show(&box, title, text, result_text, max_chars);

  while(GetMessage(&msg, NULL, 0, 0) > 0)
    {
      if (msg.message == WM_KEYDOWN) {
        switch (msg.wParam) {
        case VK_RETURN:
          input_box_submit(&box);
        case VK_ESCAPE:
          input_box_close(&box);
          break;
        default:
          TranslateMessage(&msg);
        }
      } else {
        TranslateMessage(&msg);
      }
      DispatchMessage(&msg);	
    }

  input_box_destroy(&box);
  
  return(box.result);
}

/* void input_box_demo() */
/* { */
/*   input_box_initialize(GetModuleHandle(NULL)); */
/*   #define chars 100 */
/*   /\* UTF-16LE: 2 bytes per char. *\/ */
/*   char buffer[chars*2] = {187, 3, 184, 3, 4, 4}; */
/*   input_box(L"text", L"title", (LPTSTR)buffer, chars); */
/* } */
