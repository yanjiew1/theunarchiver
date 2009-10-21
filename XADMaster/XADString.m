#import "XADString.h"

#import <UniversalDetector/UniversalDetector.h>



@implementation XADString

+(XADString *)XADStringWithString:(NSString *)knownstring
{
	return [[[self alloc] initWithString:knownstring] autorelease];
}

-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
{
	// Make sure the detector sees the data, and decode it directly if it is just ASCII
	if([stringsource analyzeDataAndCheckForASCII:bytedata])
	return [self initWithString:[[[NSString alloc] initWithData:bytedata encoding:NSASCIIStringEncoding] autorelease]];

	if(self=[super init])
	{
		data=[bytedata retain];
		string=nil;
		source=[stringsource retain];
	}
	return self;
}

-(id)initWithString:(NSString *)knownstring
{
	if(self=[super init])
	{
		string=[knownstring retain];
		data=nil;
		source=nil;
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[string release];
	[source release];
	[super dealloc];
}



-(NSString *)string
{
	return [self stringWithEncoding:[source encoding]];
}

-(NSString *)stringWithEncoding:(NSStringEncoding)encoding
{
	if(string) return string;

	NSString *decstr=[[[NSString alloc] initWithData:data encoding:encoding] autorelease];
	if(decstr) return decstr;

	// Fall back on escaped ASCII if the encoding was unusable
	const uint8_t *bytes=[data bytes];
	int length=[data length];
	NSMutableString *str=[NSMutableString stringWithCapacity:length];

	for(int i=0;i<length;i++)
	{
		if(bytes[i]<0x80) [str appendFormat:@"%c",bytes[i]];
		else [str appendFormat:@"%%%02x",bytes[i]];
	}

	return [NSString stringWithString:str];
}

-(NSData *)data
{
	if(data) return data;

	return [string dataUsingEncoding:NSNonLossyASCIIStringEncoding];
}



-(BOOL)encodingIsKnown
{
	if(!source) return YES;
	if([source hasFixedEncoding]) return YES;
	return NO;
}

-(NSStringEncoding)encoding
{
	if(!source) return NSUTF8StringEncoding; // TODO: what should this really return?
	return [source encoding];
}

-(float)confidence
{
	if(!source) return 1;
	return [source confidence];
}



-(XADStringSource *)source { return source; }



-(BOOL)hasASCIIPrefix:(NSString *)asciiprefix
{
	if(string) return [string hasPrefix:asciiprefix];
	else
	{
		int length=[asciiprefix length];
		if([data length]<length) return NO;

		char cstr[length+1];
		if(![asciiprefix getCString:cstr maxLength:length+1 encoding:NSASCIIStringEncoding]) return NO;

		return !strncmp([data bytes],cstr,length);
	}
}

-(XADString *)XADStringByStrippingASCIIPrefixOfLength:(int)length
{
	if(string) return [[[XADString alloc] initWithString:[string substringFromIndex:length]] autorelease];
	else return [[[XADString alloc] initWithData:[data subdataWithRange:NSMakeRange(length,[data length]-length)] source:source] autorelease];
}



-(BOOL)isEqual:(id)other
{
	if([other isKindOfClass:[NSString class]]) return [[self string] isEqual:other];
	else if([other isKindOfClass:[self class]])
	{
		XADString *xadstr=(XADString *)other;

		if(string&&xadstr->string) return [string isEqual:xadstr->string];
		else if(data&&xadstr->data&&source==xadstr->source) return [data isEqual:xadstr->data];
		else return NO;

/*		if(string) return [string isEqual:[xadstr string]];
		else if(xadstr->string) return [xadstr->string isEqual:[self string]];
		else if(source==xadstr->source||[source encoding]==[xadstr->source encoding]) return [data isEqual:xadstr->data];
		else return [[self string] isEqual:[xadstr string]];*/
	}
	else return NO;
}

-(NSUInteger)hash
{
	if(string) return [string hash];
	else return [data hash];
}



-(NSString *)description
{
	// TODO: more info?
	return [self string];
}

-(id)copyWithZone:(NSZone *)zone
{
	if(string) return [[XADString allocWithZone:zone] initWithString:string];
	else return [[XADString allocWithZone:zone] initWithData:data source:source];
}

@end



@implementation XADStringSource

-(id)init
{
	if(self=[super init])
	{
		detector=[UniversalDetector new]; // can return nil if UniversalDetector is not found
		fixedencoding=0;
		mac=NO;
	}
	return self;
}

-(void)dealloc
{
	[detector release];
	[super dealloc];
}

-(BOOL)analyzeDataAndCheckForASCII:(NSData *)data
{
	[detector analyzeData:data];

	// check if string is ASCII
	const char *ptr=[data bytes];
	int length=[data length];
	for(int i=0;i<length;i++) if(ptr[i]&0x80) return NO;

	return YES;
}

-(NSStringEncoding)encoding
{
	if(fixedencoding) return fixedencoding;
	if(!detector) return NSWindowsCP1252StringEncoding;

	NSStringEncoding encoding=[detector encoding];
	if(!encoding) encoding=NSWindowsCP1252StringEncoding;

	// Kludge to use Mac encodings instead of the similar Windows encodings for Mac archives
	// TODO: improve
	if(mac)
	{
		if(encoding==NSWindowsCP1252StringEncoding) return NSMacOSRomanStringEncoding;

		NSStringEncoding macjapanese=CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese);
		if(encoding==NSShiftJISStringEncoding) return macjapanese;
		//else if(encoding!=NSUTF8StringEncoding&&encoding!=macjapanese) encoding=NSMacOSRomanStringEncoding;
	}

	return encoding;
}

-(float)confidence
{
	if(fixedencoding) return 1;
	if(!detector) return 0;
	NSStringEncoding encoding=[detector encoding];
	if(!encoding) return 0;
	return [detector confidence];
}

-(UniversalDetector *)detector
{
	return detector;
}

-(void)setFixedEncoding:(NSStringEncoding)encoding
{
	fixedencoding=encoding;
}

-(BOOL)hasFixedEncoding
{
	return fixedencoding!=0;
}

-(void)setPrefersMacEncodings:(BOOL)prefermac
{
	mac=prefermac;
}

@end
