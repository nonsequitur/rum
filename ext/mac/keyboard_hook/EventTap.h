#import <Cocoa/Cocoa.h>
@class Event;

@interface EventTap : NSObject {
	id delegate;
}
-(id)init;
-(Event*)handleEvent:(Event*)event;
@end

CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *eventTapObject);
