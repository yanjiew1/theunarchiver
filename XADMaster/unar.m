#import "XADUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v0.2"


BOOL recurse;
NSString *password,*encoding;



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

	NSString *name=[[[dict objectForKey:XADFileNameKey] string] stringByEscapingControlCharacters];
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




int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"unar " VERSION_STRING @" (" @__DATE__ @"), a tool for extracting the contents of archive files.\n"
	@"Usage: unar [options] archive... [destination]\n"
	@"\n"
	@"Available options:\n"];

	[cmdline addStringOption:@"password" description:
	@"The password to use for decrypting protected archives."];
	[cmdline addAlias:@"p" forOption:@"password"];

	[cmdline addStringOption:@"encoding" description:
	@"The encoding to use for filenames in the archive, when it is not known. "
	@"Use \"help\" or \"list\" as the argument to give a listing of all supported encodings."];
	[cmdline addAlias:@"e" forOption:@"encoding"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to extract archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only unpack the .tar file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addSwitchOption:@"no-directory" description:
	@"Do not automatically create a directory for the contents of the unpacked archive."];
	[cmdline addAlias:@"nd" forOption:@"no-directory"];

	[cmdline addMultipleChoiceOption:@"forks"
	#ifdef __APPLE__
	allowedValues:[NSArray arrayWithObjects:@"fork",@"visible",@"invisible",@"skip",nil]
	defaultValue:@"fork"
	#else
	allowedValues:[NSArray arrayWithObjects:@"visible",@"invisible",@"skip",nil]
	defaultValue:@"visible"
	#endif
	description:@"How to handle Mac OS resource forks."];
 	[cmdline addAlias:@"f" forOption:@"forks"];

	[cmdline addHelpOption];

	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);



	password=[cmdline stringValueForOption:@"password"];
	encoding=[cmdline stringValueForOption:@"encoding"];
	recurse=![cmdline boolValueForOption:@"no-recursion"];

	if(encoding&&([encoding caseInsensitiveCompare:@"list"]==NSOrderedSame||[encoding caseInsensitiveCompare:@"help"]==NSOrderedSame))
	{
		[@"Available encodings are:\n" print];
		PrintEncodingList();
		return 0;
	}



//	NSArray *files=[cmdline stringArrayValueForOption:@"files"];
	NSArray *files=[cmdline remainingArguments];
	int numfiles=[files count];

	if(numfiles==0)
	{
		[cmdline printUsage];
		exit(1);
	}

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

//			NSString *password=[cmdline stringArrayValueForOption:@"password"];
//			if(pass) [parser setPassword:pass];

			[unarchiver parseAndUnarchive];
		}
		else
		{
			[@" Couldn't open archive.\n" print];
		}

		[pool release];
	}

	[pool release];

	return 0;
}
