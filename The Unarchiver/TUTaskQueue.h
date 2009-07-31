#import <Cocoa/Cocoa.h>

@interface TUTaskQueue:NSObject
{
	NSMutableArray *tasks;
	BOOL running,stalled;
}

-(id)init;
-(void)dealloc;

-(id)taskWithTarget:(id)target;
-(void)newTaskWithTarget:(id)target invocation:(NSInvocation *)invocation;

-(void)stallCurrentTask;
-(void)finishCurrentTask;

-(BOOL)isRunning;
-(BOOL)isStalled;

-(void)restart;

@end

@interface TUTaskTrampoline:NSProxy
{
	id actual;
	TUTaskQueue *parent;
}

-(id)initWithTarget:(id)target queue:(TUTaskQueue *)queue;
-(void)dealloc;

-(NSMethodSignature *)methodSignatureForSelector:(SEL)sel;
-(void)forwardInvocation:(NSInvocation *)invocation;

@end
