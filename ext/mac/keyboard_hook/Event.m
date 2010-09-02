#import "Event.h"

@implementation Event

-(id)initWithEventRef:(CGEventRef)anEventRef tapProxy:(CGEventTapProxy)aTapProxy type:(CGEventType)aType down:(BOOL)isDown {
	eventRef = anEventRef;
	tapProxy = aTapProxy;
	type = aType;
	down = isDown;
	return self;
}

@synthesize eventRef;
@synthesize tapProxy;
@synthesize type;
@synthesize down;

@end
