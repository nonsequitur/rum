#include <windows.h>

static DWORD g_MainThreadID;

void autohotkey_stuff_initialize(DWORD main_thread_id)
{
  g_MainThreadID = main_thread_id;
}

static void key_down_up(BYTE vkcode) {
    keybd_event(vkcode, 0, 0, 0);
    keybd_event(vkcode, 0, KEYEVENTF_KEYUP, 0);
}

HWND AttemptSetForeground(HWND aTargetWindow, HWND aForeWindow)
{

  BOOL result = SetForegroundWindow(aTargetWindow);
  HWND new_fore_window = GetForegroundWindow();
  Sleep(10);

  if (new_fore_window == aTargetWindow)
    {
#ifdef _DEBUG_WINACTIVATE
      if (!result)
        {
          FileAppend(LOGF, "SetForegroundWindow() indicated failure even though it succeeded: ", false);
          FileAppend(LOGF, aTargetTitle);
        }
#endif
      return aTargetWindow;
    }
  if (new_fore_window != aForeWindow && aTargetWindow == GetWindow(new_fore_window, GW_OWNER))
    // The window we're trying to get to the foreground is the owner of the new foreground window.
    // This is considered to be a success because a window that owns other windows can never be
    // made the foreground window, at least if the windows it owns are visible.
    return new_fore_window;
  // Otherwise, failure:
#ifdef _DEBUG_WINACTIVATE
  if (result)
    {
      FileAppend(LOGF, "SetForegroundWindow() indicated success even though it failed: ", false);
      FileAppend(LOGF, aTargetTitle);
    }
#endif
  return NULL;
}



HWND SetForegroundWindowEx(HWND aTargetWindow)
// Caller must have ensured that aTargetWindow is a valid window or NULL, since we
// don't call IsWindow() here.
{
  DWORD target_thread;
  HWND orig_foreground_wnd;
  HWND new_foreground_wnd;
  int is_attached_my_to_fore;
  int is_attached_fore_to_target;
  DWORD fore_thread;
  int i;
  int show_mode;

  if (!aTargetWindow)
    return NULL ;  // When called this way (as it is sometimes), do nothing.

  // v1.0.42.03: Calling IsWindowHung() once here rather than potentially more than once in AttemptSetForeground()
  // solves a crash that is not fully understood, nor is it easily reproduced (it occurs only in release mode,
  // not debug mode).  It's likely a bug in the API's IsHungAppWindow(), but that is far from confirmed.
  target_thread = GetWindowThreadProcessId(aTargetWindow, NULL) ;
  /*   if (target_thread != g_MainThreadID && IsWindowHung(aTargetWindow)) // Calls to IsWindowHung should probably be avoided if the window belongs to our thread.  Relies upon short-circuit boolean order. */
  /*     return NULL                             ; */

  orig_foreground_wnd = GetForegroundWindow() ;
  // AutoIt3: If there is not any foreground window, then input focus is on the TaskBar.
  // MY: It is definitely possible for GetForegroundWindow() to return NULL, even on XP.
  if (!orig_foreground_wnd)
    orig_foreground_wnd = FindWindow("Shell_TrayWnd", NULL) ;

  if (aTargetWindow == orig_foreground_wnd) // It's already the active window.
    return aTargetWindow                    ;

  if (IsIconic(aTargetWindow))
    show_mode = SW_RESTORE;
  else
    show_mode = SW_SHOW;
  ShowWindow(aTargetWindow, show_mode);



  // if (g_os.IsWin95() || (!g_os.IsWin9x() && !g_os.IsWin2000orLater())))  // Win95 or NT
  // Try a simple approach first for these two OS's, since they don't have
  // any restrictions on focus stealing:
#ifdef _DEBUG_WINACTIVATE
#define IF_ATTEMPT_SET_FORE if (new_foreground_wnd = AttemptSetForeground(aTargetWindow, orig_foreground_wnd, win_name))
#else
#define IF_ATTEMPT_SET_FORE if (new_foreground_wnd = AttemptSetForeground(aTargetWindow, orig_foreground_wnd))
#endif
  IF_ATTEMPT_SET_FORE
    return new_foreground_wnd               ;
  // Otherwise continue with the more drastic methods below.

  // MY: The AttachThreadInput method, when used by itself, seems to always
  // work the first time on my XP system, seemingly regardless of whether the
  // "allow focus steal" change has been made via SystemParametersInfo()
  // (but it seems a good idea to keep the SystemParametersInfo() in effect
  // in case Win2k or Win98 needs it, or in case it really does help in rare cases).
  // In many cases, this avoids the two SetForegroundWindow() attempts that
  // would otherwise be needed ; and those two attempts cause some windows
  // to flash in the taskbar, such as Metapad and Excel (less frequently) whenever
  // you quickly activate another window after activating it first (e.g. via hotkeys).
  // So for now, it seems best just to use this method by itself.  The
  // "two-alts" case never seems to fire on my system?  Maybe it will
  // on Win98 sometimes.
  // Note: In addition to the "taskbar button flashing" annoyance mentioned above
  // any SetForegroundWindow() attempt made prior to the one below will,
  // as a side-effect, sometimes trigger the need for the "two-alts" case
  // below.  So that's another reason to just keep it simple and do it this way
  // only.

#ifdef _DEBUG_WINACTIVATE
  char buf[1024]                          ;
#endif

  is_attached_my_to_fore = 0;
  is_attached_fore_to_target = 0;
  if (orig_foreground_wnd) // Might be NULL from above.
    {
      // Based on MSDN docs, these calls should always succeed due to the other
      // checks done above (e.g. that none of the HWND's are NULL):
      fore_thread = GetWindowThreadProcessId(orig_foreground_wnd, NULL) ;

      // MY: Normally, it's suggested that you only need to attach the thread of the
      // foreground window to our thread.  However, I've confirmed that doing all three
      // attaches below makes the attempt much more likely to succeed.  In fact, it
      // almost always succeeds whereas the one-attach method hardly ever succeeds the first
      // time (resulting in a flashing taskbar button due to having to invoke a second attempt)
      // when one window is quickly activated after another was just activated.
      // AutoIt3: Attach all our input threads, will cause SetForeground to work under 98/Me.
      // MSDN docs: The AttachThreadInput function fails if either of the specified threads
      // does not have a message queue (My: ok here, since any window's thread MUST have a
      // message queue).  [It] also fails if a journal record hook is installed.  ... Note
      // that key state, which can be ascertained by calls to the GetKeyState or
      // GetKeyboardState function, is reset after a call to AttachThreadInput.  You cannot
      // attach a thread to a thread in another desktop.  A thread cannot attach to itself.
      // Therefore, idAttachTo cannot equal idAttach.  Update: It appears that of the three,
      // this first call does not offer any additional benefit, at least on XP, so not
      // using it for now:
      //if (g_MainThreadID != target_thread) // Don't attempt the call otherwise.
      //	AttachThreadInput(g_MainThreadID, target_thread, TRUE) ;
      if (fore_thread && g_MainThreadID != fore_thread)
        is_attached_my_to_fore = AttachThreadInput(g_MainThreadID, fore_thread, TRUE) != 0 ;
      if (fore_thread && target_thread && fore_thread != target_thread) // IsWindowHung(aTargetWindow) was called earlier.
        is_attached_fore_to_target = AttachThreadInput(fore_thread, target_thread, TRUE) != 0 ;
    }

  // The log showed that it never seemed to need more than two tries.  But there's
  // not much harm in trying a few extra times.  The number of tries needed might
  // vary depending on how fast the CPU is:
  for (i = 0; i < 5; ++i)
    {
      IF_ATTEMPT_SET_FORE
        {
#ifdef _DEBUG_WINACTIVATE
          if (i > 0) // More than one attempt was needed.
            {
              snprintf(buf, sizeof(buf), "AttachThreadInput attempt #%d indicated success: %s"
                       , i + 1, win_name);
              FileAppend(LOGF, buf);
            }
#endif
          break;
        }
    }

  // I decided to avoid the quick minimize + restore method of activation.  It's
  // not that much more effective (if at all), and there are some significant
  // disadvantages:
  // - This call will often hang our thread if aTargetWindow is a hung window: ShowWindow(aTargetWindow, SW_MINIMIZE)
  // - Using SW_FORCEMINIMIZE instead of SW_MINIMIZE has at least one (and probably more)
  // side effect: When the window is restored, at least via SW_RESTORE, it is no longer
  // maximized even if it was before the minmize.  So don't use it.
  if (!new_foreground_wnd) // Not successful yet.
    {
      // Some apps may be intentionally blocking us by having called the API function
      // LockSetForegroundWindow(), for which MSDN says "The system automatically enables
      // calls to SetForegroundWindow if the user presses the ALT key or takes some action
      // that causes the system itself to change the foreground window (for example,
      // clicking a background window)."  Also, it's probably best to avoid doing
      // the 2-alts method except as a last resort, because I think it may mess up
      // the state of menus the user had displayed.  And of course if the foreground
      // app has special handling for alt-key events, it might get confused.
      // My original note: "The 2-alts case seems to mess up on rare occasions,
      // perhaps due to menu weirdness triggered by the alt key."
      // AutoIt3: OK, this is not funny - bring out the extreme measures (usually for 2000/XP).
      // Simulate two single ALT keystrokes.  UPDATE: This hardly ever succeeds.  Usually when
      // it fails, the foreground window is NULL (none).  I'm going to try an Win-tab instead,
      // which selects a task bar button.  This seems less invasive than doing an alt-tab
      // because not only doesn't it activate some other window first, it also doesn't appear
      // to change the Z-order, which is good because we don't want the alt-tab order
      // that the user sees to be affected by this.  UPDATE: Win-tab isn't doing it, so try
      // Alt-tab.  Alt-tab doesn't do it either.  The window itself (metapad.exe is the only
      // culprit window I've found so far) seems to resist being brought to the foreground,
      // but later, after the hotkey is released, it can be.  So perhaps this is being
      // caused by the fact that the user has keys held down (logically or physically?)
      // Releasing those keys with a key-up event might help, so try that sometime:
        key_down_up(VK_LMENU);
        key_down_up(VK_LMENU);
      //KeyEvent(KEYDOWN, VK_LWIN)                    ;
      //KeyEvent(KEYDOWN, VK_TAB)                     ;
      //KeyEvent(KEYUP, VK_TAB)                       ;
      //KeyEvent(KEYUP, VK_LWIN)                      ;
      //KeyEvent(KEYDOWN, VK_MENU)                    ;
      //KeyEvent(KEYDOWN, VK_TAB)                     ;
      //KeyEvent(KEYUP, VK_TAB)                       ;
      //KeyEvent(KEYUP, VK_MENU)                      ;
      // Also replacing "2-alts" with "alt-tab" below, for now:

#ifndef _DEBUG_WINACTIVATE
      new_foreground_wnd = AttemptSetForeground(aTargetWindow, orig_foreground_wnd) ;
#else // debug mode
      IF_ATTEMPT_SET_FORE
        FileAppend(LOGF, "2-alts ok: ", false)  ;
      else
        {
          FileAppend(LOGF, "2-alts (which is the last resort) failed.  ", false) ;
          HWND h = GetForegroundWindow()          ;
          if (h)
            {
              char fore_name[64]                      ;
              GetWindowText(h, fore_name, sizeof(fore_name)) ;
              FileAppend(LOGF, "Foreground: ", false)        ;
              FileAppend(LOGF, fore_name, false)             ;
            }
          FileAppend(LOGF, ".  Was trying to activate: ", false) ;
        }
      FileAppend(LOGF, win_name)              ;
#endif
    } // if()

  // Very important to detach any threads whose inputs were attached above,
  // prior to returning, otherwise the next attempt to attach thread inputs
  // for these particular windows may result in a hung thread or other
  // undesirable effect:
  if (is_attached_my_to_fore)
    AttachThreadInput(g_MainThreadID, fore_thread, FALSE) ;
  if (is_attached_fore_to_target)
    AttachThreadInput(fore_thread, target_thread, FALSE) ;

  if (new_foreground_wnd) // success.
    {
      BringWindowToTop(aTargetWindow)         ;
      return new_foreground_wnd ; // Return this rather than aTargetWindow because it's more appropriate.
    }
  else
    return NULL                             ;
}
