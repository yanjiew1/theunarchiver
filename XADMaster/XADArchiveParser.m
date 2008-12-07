#import "XADArchiveParser.h"
#import "CSFileHandle.h"
#import "CSMultiHandle.h"

#import "XADZipParser.h"
#import "XADGzipParser.h"
#import "XADBzip2Parser.h"
#import "XADRARParser.h"
#import "XADStuffItParser.h"
#import "XADStuffIt5Parser.h"
#import "XADBinHexParser.h"
#import "XADCompactProParser.h"
#import "XADCompressParser.h"
#import "XADALZipParser.h"
#import "XADPowerPackerParser.h"
#import "XADLibXADParser.h"

#include <dirent.h>

const NSString *XADFileNameKey=@"XADFileName";
const NSString *XADFileSizeKey=@"XADFileSize";
const NSString *XADCompressedSizeKey=@"XADCompressedSize";
const NSString *XADLastModificationDateKey=@"XADLastModificationDate";
const NSString *XADLastAccessDateKey=@"XADLastAccessDate";
const NSString *XADCreationDateKey=@"XADCreationDate";
const NSString *XADFileTypeKey=@"XADFileType";
const NSString *XADFileCreatorKey=@"XADFileCreator";
const NSString *XADFinderFlagsKey=@"XADFinderFlags";
const NSString *XADPosixPermissionsKey=@"XADPosixPermissions";
const NSString *XADPosixUserKey=@"XADPosixUser";
const NSString *XADPosixGroupKey=@"XADGroupUser";
const NSString *XADPosixUserNameKey=@"XADPosixUser";
const NSString *XADPosixGroupNameKey=@"XADGroupUser";
const NSString *XADIsEncryptedKey=@"XADIsEncrypted";
const NSString *XADIsDirectoryKey=@"XADIsDirectory";
const NSString *XADIsResourceForkKey=@"XADIsResourceFork";
const NSString *XADIsMacBinaryKey=@"XADIsMacBinary";
const NSString *XADLinkDestinationKey=@"XADLinkDestination";
const NSString *XADCommentKey=@"XADComment";
const NSString *XADDataOffsetKey=@"XADDataOffset";
const NSString *XADDataLengthKey=@"XADDataLength";
const NSString *XADCompressionNameKey=@"XADCompressionName";


@implementation XADArchiveParser

static NSMutableArray *parserclasses=nil;
static int maxheader=0;

+(void)initialize
{
	if(parserclasses) return;
	parserclasses=[[NSMutableArray arrayWithObjects:
		[XADZipParser class],
		[XADGzipParser class],
		[XADBzip2Parser class],
		[XADRARParser class],
		[XADStuffIt5Parser class],
		[XADStuffItParser class],
		[XADBinHexParser class],
		[XADCompactProParser class],
		[XADCompressParser class],
		[XADALZipParser class],
		[XADPowerPackerParser class],
		[XADLibXADParser class],
	nil] retain];

	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class class;
	while(class=[enumerator nextObject])
	{
		int header=[class requiredHeaderSize];
		if(header>maxheader) maxheader=header;
	}
}

+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name
{
	NSData *header=[handle readDataOfLengthAtMost:maxheader];
	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class parserclass;
	while(parserclass=[enumerator nextObject])
	{
		[handle seekToFileOffset:0];
		@try {
			if([parserclass recognizeFileWithHandle:handle firstBytes:header name:name])
			{
				[handle seekToFileOffset:0];
				return [[[parserclass alloc] initWithHandle:handle name:name] autorelease];
			}
		} @catch(id e) {} // ignore parsers that throw errors on recognition or init
	}
	return nil;
}

+(XADArchiveParser *)archiveParserForPath:(NSString *)filename
{
	CSHandle *handle;

	NSArray *volumes=[self volumesForFilename:filename];
	if(volumes)
	{
		@try
		{
			NSMutableArray *handles=[NSMutableArray array];
			NSEnumerator *enumerator=[volumes objectEnumerator];
			NSString *volume;

			while(volume=[enumerator nextObject])
			[handles addObject:[CSFileHandle fileHandleForReadingAtPath:volume]];

			return [self archiveParserForHandle:[CSMultiHandle multiHandleWithHandleArray:handles]
			name:[volumes objectAtIndex:0]];
		}
		@catch(id e) { }
	}

	trysingle:
	@try {
		handle=[CSFileHandle fileHandleForReadingAtPath:filename];
	} @catch(id e) { return nil; }

	return [self archiveParserForHandle:handle name:filename];
}


static int XADVolumeSort(NSString *str1,NSString *str2,void *classptr)
{
	Class parserclass=classptr;
	BOOL isfirst1=[parserclass isFirstVolume:str1];
	BOOL isfirst2=[parserclass isFirstVolume:str2];

	if(isfirst1&&!isfirst2) return NSOrderedAscending;
	else if(!isfirst1&&isfirst2) return NSOrderedDescending;
//	else return [str1 compare:str2 options:NSCaseInsensitiveSearch|NSNumericSearch];
	else return [str1 compare:str2 options:NSCaseInsensitiveSearch];
}

+(NSArray *)volumesForFilename:(NSString *)name
{
	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class parserclass;
	while(parserclass=[enumerator nextObject])
	{
		XADRegex *regex=[parserclass volumeRegexForFilename:name];
		if(!regex) continue;

		NSMutableArray *volumes=[NSMutableArray array];
		NSString *dirname=[name stringByDeletingLastPathComponent];
		DIR *dir=opendir([dirname fileSystemRepresentation]);

		struct dirent *ent;
		while(ent=readdir(dir))
		{
			NSString *filename=[dirname stringByAppendingPathComponent:[NSString stringWithUTF8String:ent->d_name]];
			if([regex matchesString:filename]) [volumes addObject:filename];
		}

		closedir(dir);

		[volumes sortUsingFunction:XADVolumeSort context:parserclass];

		if([volumes count]>1) return volumes;
	}
	return nil;
}





-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super init])
	{
		sourcehandle=[handle retain];
		archivename=[[name lastPathComponent] retain];

		skiphandle=nil;
		delegate=nil;
		password=nil;
		isencrypted=NO;

		stringsource=[XADStringSource new];
	}
	return self;
}

-(void)dealloc
{
	[sourcehandle release];
	[skiphandle release];
	[archivename release];
	[stringsource release];
	[super dealloc];
}

-(id)delegate { return delegate; }

-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(BOOL)isEncrypted { return isencrypted; }

-(void)setPassword:(NSString *)newpassword
{
	[password autorelease];
	password=[newpassword retain];
}

-(NSString *)password { return password; }



-(NSString *)name { return archivename; }

-(CSHandle *)handle { return sourcehandle; }

-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict
{
	[sourcehandle seekToFileOffset:[[dict objectForKey:XADDataOffsetKey] longLongValue]];

	CSHandle *handle=skiphandle?skiphandle:sourcehandle;

	NSNumber *length=[dict objectForKey:XADDataLengthKey];
	if(length) return [handle nonCopiedSubHandleOfLength:[length longLongValue]];
	else return handle;
}

-(XADSkipHandle *)skipHandle
{
	if(!skiphandle) skiphandle=[[XADSkipHandle alloc] initWithHandle:sourcehandle];
	return skiphandle;
}



-(NSArray *)volumes
{
	if([sourcehandle respondsToSelector:@selector(handles)]) return [(id)sourcehandle handles];
	else return nil;
}

-(off_t)offsetForVolume:(int)disk offset:(off_t)offset
{
	if([sourcehandle respondsToSelector:@selector(handles)])
	{
		NSArray *handles=[(id)sourcehandle handles];
		int count=[handles count];
		for(int i=0;i<count&&i<disk;i++) offset+=[[handles objectAtIndex:i] fileSize];
	}

	return offset;
}




-(void)addEntryWithDictionary:(NSDictionary *)dictionary
{
	[self addEntryWithDictionary:dictionary retainPosition:NO];
}

-(void)addEntryWithDictionary:(NSDictionary *)dictionary retainPosition:(BOOL)retainpos
{
	// If an encrypted file is added, set the global encryption flag
	NSNumber *num=[dictionary objectForKey:XADIsEncryptedKey];
	if(num&&[num boolValue]) [self setEncrypted:YES];

	if(retainpos)
	{
		off_t pos=[sourcehandle offsetInFile];
		[delegate archiveParser:self foundEntryWithDictionary:dictionary];
		[sourcehandle seekToFileOffset:pos];
	}
	else [delegate archiveParser:self foundEntryWithDictionary:dictionary];
}


-(XADString *)XADStringWithString:(NSString *)string
{
	return [stringsource XADStringWithString:string];
}

-(XADString *)XADStringWithData:(NSData *)data
{
	return [stringsource XADStringWithData:data];
}

-(XADString *)XADStringWithData:(NSData *)data encoding:(NSStringEncoding)encoding
{
	return [XADString XADStringWithString:[[[NSString alloc] initWithData:data encoding:encoding] autorelease]];
}

-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length
{
	return [stringsource XADStringWithData:[NSData dataWithBytes:bytes length:length]];
}

-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length encoding:(NSStringEncoding)encoding
{
	return [XADString XADStringWithString:[[[NSString alloc] initWithData:
	[NSData dataWithBytes:bytes length:length] encoding:encoding] autorelease]];
}

-(XADString *)XADStringWithCString:(const void *)string
{
	return [stringsource XADStringWithData:[NSData dataWithBytes:string length:strlen(string)]];
}

-(XADString *)XADStringWithCString:(const void *)string encoding:(NSStringEncoding)encoding
{
	return [XADString XADStringWithString:[[[NSString alloc] initWithData:
	[NSData dataWithBytes:string length:strlen(string)] encoding:encoding] autorelease]];
}

-(NSData *)encodedPassword
{
	if(!password) return [NSData data];
	else return [password dataUsingEncoding:[stringsource encoding]];
}

-(const char *)encodedCStringPassword
{
	NSMutableData *data=[NSMutableData dataWithData:[self encodedPassword]];
	[data increaseLengthBy:1];
	return [data bytes];
}

-(void)setEncrypted:(BOOL)encryptedflag
{
	isencrypted=encryptedflag;
}



+(int)requiredHeaderSize { return 0; }
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name { return NO; }
+(XADRegex *)volumeRegexForFilename:(NSString *)filename { return nil; }
+(BOOL)isFirstVolume:(NSString *)filename { return NO; }

-(void)parse {}
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum { return nil; }
-(NSString *)formatName { return nil; }

@end


@implementation NSObject (XADArchiveParserDelegate)

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict {}
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser { return NO; }

@end
