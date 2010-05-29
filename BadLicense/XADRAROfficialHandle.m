#import "XADRAROfficialHandle.h"
#import "../XADMaster/SystemSpecific.h"

@implementation XADRAROfficialHandle

-(id)initWithRARParser:(XADRARParser *)parent version:(int)version parts:(NSArray *)partarray
{
	if(self=[super initWithName:[parent name]])
	{
		parser=parent;
		parts=[partarray retain];
		method=version;

		unpacker=AllocRARUnpacker(
		(RARReadFunc)[self methodForSelector:@selector(provideInput:buffer:)],
		self,@selector(provideInput:buffer:));

		currhandle=nil;
	}
	return self;
}

-(void)dealloc
{
	FreeRARUnpacker(unpacker);
	[parts release];
	[currhandle release];
	[super dealloc];
}

-(void)resetBlockStream
{
	part=0;

	[self constructInputHandle];
	StartRARUnpacker(unpacker,currsize,method,0);
	bytesdone=0;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(bytesdone>=currsize)
	{
		// Try to go on to the next part
		if(++part<[parts count])
		{
			[self constructInputHandle];
			StartRARUnpacker(unpacker,currsize,method,1);
			bytesdone=0;
		}
		else return 0;
	}

	int length;
	[self setBlockPointer:NextRARBlock(unpacker,&length)];

	bytesdone+=length;

	return length;
}

-(void)constructInputHandle
{
	[currhandle release];
	currhandle=nil;

	NSDictionary *dict=[parts objectAtIndex:part];

	currhandle=[[parser dataHandleFromSkipOffset:[[dict objectForKey:@"SkipOffset"] longLongValue]
	length:[[dict objectForKey:@"InputLength"] longLongValue]
	encrypted:[[dict objectForKey:@"Encrypted"] longLongValue]
	cryptoVersion:method salt:[dict objectForKey:@"Salt"]] retain];

	currsize=[[dict objectForKey:@"OutputLength"] longLongValue];
}

-(int)provideInput:(int)length buffer:(void *)buffer
{
	return [currhandle readAtMost:length toBuffer:buffer];
}

@end
