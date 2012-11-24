// Based on Nathan Sobo's ControlFreak
// http://github.com/nathansobo/control_freak
//
// This project is a temporary provision.
// A future MacRuby release will allow KeyboardHook.framework
// to be implemented in pure Ruby.


#import <Carbon/Carbon.h> // for keycode aliases
#import <ApplicationServices/ApplicationServices.h>
#import "EventTap.h"
#import "Event.h"
#import <MacRuby/MacRuby.h>

CFMachPortRef keyboard_event_tap;

@interface NSObject (RubyMethods)
-(Event*)onEvent:(Event*)event;
@end

@implementation EventTap
-(id)init {
	[super init];
	keyboard_event_tap = CGEventTapCreate(kCGHIDEventTap,
                                          kCGHeadInsertEventTap,
                                          kCGEventTapOptionDefault,
                                          CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged),
                                          &eventCallback,
                                          self);
	CFRunLoopSourceRef tapSource = CFMachPortCreateRunLoopSource(NULL, keyboard_event_tap, 0);
	CFRunLoopAddSource((CFRunLoopRef) [[NSRunLoop currentRunLoop] getCFRunLoop], tapSource, kCFRunLoopCommonModes);

	return self;
}

-(Event*)handleKeyEvent:(Event*)event {
	// to be overridden by ruby code
	return event;
}

@end

int modifier_flags[] = { kCGEventFlagMaskCommand,     // command
                         kCGEventFlagMaskShift,       // shift
                         kCGEventFlagMaskAlphaShift,  // capslock
                         kCGEventFlagMaskAlternate,   // option
                         kCGEventFlagMaskControl,     // control
                         kCGEventFlagMaskShift,       // rightshift
                         kCGEventFlagMaskAlternate,   // rightoption
                         kCGEventFlagMaskControl,     // rightcontrol
                         kCGEventFlagMaskSecondaryFn  // function
};

CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type,
                         CGEventRef event, void *eventTapObject) {
  BOOL is_down;
  int keycode;

  switch (type) {
  case kCGEventKeyDown:
    is_down = true;
    break;
  case kCGEventKeyUp:
    is_down = false;
    break;
  case kCGEventFlagsChanged:
    keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    is_down = ((CGEventGetFlags(event) & modifier_flags[keycode - kVK_Command]) != 0);
    break;
  case kCGEventTapDisabledByTimeout:
    CGEventTapEnable(keyboard_event_tap, true);
  default:
    return event;
  }

  return [((id) eventTapObject) handleKeyEvent:[[Event alloc] initWithEventRef:event tapProxy:proxy type:type down:is_down]].eventRef;
}
