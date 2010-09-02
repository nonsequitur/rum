#import <Cocoa/Cocoa.h>

@interface Event : NSObject {
	CGEventRef eventRef;
	CGEventTapProxy tapProxy;
	CGEventType type;
        BOOL down;
}

@property CGEventRef eventRef;
@property CGEventTapProxy tapProxy;
@property CGEventType type;
@property BOOL down;

-(id)initWithEventRef:(CGEventRef)eventRef tapProxy:(CGEventTapProxy)tapProxy type:(CGEventType)type down:(BOOL)down;

@end
