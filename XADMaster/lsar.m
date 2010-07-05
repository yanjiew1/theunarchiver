#import "XADUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"

#define VERSION_STRING @"v0.1"

/*NSString *EscapeString(NSString *str)
{
	NSMutableString *res=[NSMutableString string];
	int length=[str length];
	for(int i=0;i<length;i++)
	{
		unichar c=[str characterAtIndex:i];
		if(c<32) [res appendFormat:@"^%c",c+64];
		else [res appendFormat:@"%C",c];
	}
	return res;
}

@interface Unarchiver:NSObject
{
	int indent;
}
@end

@implementation Unarchiver

-(id)initWithIndentLevel:(int)indentlevel
{
	if(self=[super init])
	{
		indent=indentlevel;
	}
	return self;
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict
{
	return nil;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	for(int i=0;i<indent;i++) [@" " print];

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];

	NSString *name=EscapeString([[dict objectForKey:XADFileNameKey] string]);
	[name print];
	[@" (" print];

	if(dir&&[dir boolValue])
	{
		[@"dir" print];
	}
	else if(link&&[link boolValue]) [@"link" print];
	else
	{
		if(size) [[NSString stringWithFormat:@"%lld",[size longLongValue]] print];
		else [@"?" print];
	}

	if(rsrc&&[rsrc boolValue]) [@", rsrc" print];

	[@")..." print];
	fflush(stdout);
}

-(void)unarchiver:(XADUnarchiver *)unarchiver finishedExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	if(!error) [@" OK.\n" print];
	else
	{
		[@" Failed! (" print];
		[[XADException describeXADError:error] print];
		[@")\n" print];
	}
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory
{
	return YES;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path
{
	indent+=2;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path error:(XADError)error
{
	indent-=2;
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path
{
	return nil;
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver
{
	return NO;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress
{
}

@end

*/


int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"lsar " VERSION_STRING @" (" @__DATE__ @")\n"
	@"\n"
	@"Available options:\n"];

	[cmdline addStringOption:@"password" description:
	@"The password to use for decrypting protected archives."];
	[cmdline addAlias:@"p" forOption:@"password"];

	[cmdline addStringOption:@"encoding" description:
	@"The encoding to use for filenames in the archive, when it is not known. "
	@"Use \"help\" or \"list\" as the argument to give a listing of all supported encodings."];
	[cmdline addAlias:@"e" forOption:@"encoding"];

	[cmdline addSwitchOption:@"test" description:
	@"Test the integrity of the files in the archive, if possible."];
	[cmdline addAlias:@"t" forOption:@"test"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to extract archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only unpack the .tar file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addHelpOption];

	//@"Usage: %@ archive [ archive2 ... ] [ destination_directory ]\n",
	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);

	NSString *encoding=[[cmdline stringValueForOption:@"encoding"] lowercaseString];
	if([encoding isEqual:@"list"]||[encoding isEqual:@"help"])
	{
		[@"Available encodings are:\n" print];

		NSEnumerator *enumerator=[[XADString availableEncodingNames] objectEnumerator];
		NSArray *encodingarray;
		while(encodingarray=[enumerator nextObject])
		{
			NSString *description=[encodingarray objectAtIndex:0];
			if((id)description==[NSNull null]||[description length]==0) description=nil;

			NSString *encoding=[encodingarray objectAtIndex:1];

			NSString *aliases=nil;
			if([encodingarray count]>2) aliases=[[encodingarray subarrayWithRange:
			NSMakeRange(2,[encodingarray count]-2)] componentsJoinedByString:@", "];

			[@"  * " print];

			[encoding print];

			if(aliases)
			{
				[@" (" print];
				[aliases print];
				[@")" print];
			}

			if(description)
			{
				[@": " print];
				[description print];
			}

			[@"\n" print];
		}

		return 0;
	}

//	NSArray *files=[cmdline stringArrayValueForOption:@"files"];
/*	NSArray *files=[cmdline remainingArguments];
	int numfiles=[files count];

	NSString *destination=nil;

	if(numfiles>1)
	{
		NSString *path=[files lastObject];
		BOOL isdir;
		if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir]||isdir)
		{
			destination=path;
			numfiles--;
		}
	}

	for(int i=0;i<numfiles;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		NSString *filename=[files objectAtIndex:i];

		[@"Extracting " print];
		[filename print];
		[@"..." print];

		fflush(stdout);

		XADUnarchiver *unarchiver=[XADUnarchiver unarchiverForPath:filename];

		if(unarchiver)
		{
			[@"\n" print];
			//[unarchiver setMacResourceForkStyle:XADVisibleAppleDoubleForkStyle];
			if(destination) [unarchiver setDestination:destination];

			[unarchiver setDelegate:[[[Unarchiver alloc] initWithIndentLevel:2] autorelease]];

			//char *pass=getenv("XADTestPassword");
			//if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

			[unarchiver parseAndUnarchive];
		}
		else
		{
			[@" Couldn't open archive.\n" print];
		}

		[pool release];
	}*/

	[pool release];

	return 0;
}
