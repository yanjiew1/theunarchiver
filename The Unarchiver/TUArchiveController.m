#import "TUArchiveController.h"
#import "TUController.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"
#import <XADMaster/XADRegex.h>
#import <XADMaster/XADPlatform.h>




static NSString *globalpassword=nil;
NSStringEncoding globalpasswordencoding=0;



@implementation TUArchiveController

+(void)clearGlobalPassword
{
	[globalpassword release];
	globalpassword=nil;
	globalpasswordencoding=0;
}

-(id)initWithFilename:(NSString *)filename
{
	if((self=[super init]))
	{
		view=nil;
		docktile=nil;
		unarchiver=nil;

		archivename=[filename retain];
		destination=nil;
		tmpdest=nil;

		selected_encoding=0;

		finishtarget=nil;
		finishselector=NULL;

		foldermodeoverride=copydateoverride=changefilesoverride=-1;
		deletearchiveoverride=openextractedoverride=-1;

		cancelled=NO;
		ignoreall=NO;
		haderrors=NO;
	}
	return self;
}

-(void)dealloc
{
	[view release];
	[docktile release];
	[unarchiver release];
	[archivename release];
	[destination release];
	[tmpdest release];

	[super dealloc];
}



-(TUArchiveTaskView *)taskView { return view; }

-(void)setTaskView:(TUArchiveTaskView *)taskview
{
	[view autorelease];
	view=[taskview retain];
}

-(TUDockTileView *)dockTileView { return docktile; }

-(void)setDockTileView:(TUDockTileView *)tileview
{
	[docktile autorelease];
	docktile=[tileview retain];
}

-(NSString *)destination { return destination; }

-(void)setDestination:(NSString *)newdestination
{
	[destination autorelease];
	destination=[newdestination retain];
}

-(int)folderCreationMode
{
	if(foldermodeoverride) return foldermodeoverride;
	else return [[NSUserDefaults standardUserDefaults] integerForKey:@"createFolder"];
}

-(void)setFolderCreationMode:(int)mode { foldermodeoverride=mode; }

-(BOOL)copyArchiveDateToExtractedFolder
{
	if(copydateoverride>=0) return copydateoverride!=0;
	else return [[NSUserDefaults standardUserDefaults] integerForKey:@"folderModifiedDate"]==2;
}

-(void)setCopyArchiveDateToExtractedFolder:(BOOL)copydate { copydateoverride=copydate; }

-(BOOL)changeDateOfExtractedSingleItems
{
	if(changefilesoverride>=0) return changefilesoverride!=0;
	else return [[NSUserDefaults standardUserDefaults] boolForKey:@"changeDateOfFiles"];
}

-(void)setChangeDateOfExtractedSingleItems:(BOOL)changefiles { changefilesoverride=changefiles; }

-(BOOL)deleteArchive
{
	if(deletearchiveoverride>=0) return deletearchiveoverride!=0;
	else return [[NSUserDefaults standardUserDefaults] boolForKey:@"deleteExtractedArchive"];
}

-(void)setDeleteArchive:(BOOL)delete { deletearchiveoverride=delete; }

-(BOOL)openExtractedItem
{
	if(openextractedoverride>=0) return openextractedoverride!=0;
	else return [[NSUserDefaults standardUserDefaults] boolForKey:@"openExtractedFolder"];
}

-(void)setOpenExctractedItem:(BOOL)open { openextractedoverride=open; }

-(BOOL)isCancelled { return cancelled; }

-(void)setIsCancelled:(BOOL)iscancelled { cancelled=iscancelled; }






-(NSString *)filename
{
	if(!unarchiver) return archivename;
	else return [[unarchiver outerArchiveParser] filename];
}

-(NSArray *)allFilenames
{
	if(!unarchiver) return nil;
	return [[unarchiver outerArchiveParser] allFilenames];
}

-(BOOL)volumeScanningFailed
{
	NSNumber *failed=[[[unarchiver archiveParser] properties] objectForKey:XADVolumeScanningFailedKey];
	return failed && [failed boolValue];
}

-(BOOL)caresAboutPasswordEncoding { return [[unarchiver archiveParser] caresAboutPasswordEncoding]; }




-(NSString *)currentArchiveName
{
	NSString *currfilename=[[unarchiver archiveParser] currentFilename];
	if(!currfilename) currfilename=[[unarchiver outerArchiveParser] currentFilename];
	return [currfilename lastPathComponent];
}

-(NSString *)localizedDescriptionOfError:(XADError)error
{
	NSString *errorstr=[XADException describeXADError:error];
	NSString *localizederror=[[NSBundle mainBundle] localizedStringForKey:errorstr value:errorstr table:nil];
	return localizederror;
}

-(NSString *)stringForXADPath:(XADPath *)path
{
	NSStringEncoding encoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	if(!encoding) encoding=selected_encoding;
	if(!encoding) encoding=[path encoding];
	return [path stringWithEncoding:encoding];
}




-(void)prepare
{
	[unarchiver release];
	unarchiver=[[XADSimpleUnarchiver simpleUnarchiverForPath:archivename error:NULL] retain];
}

-(void)runWithFinishAction:(SEL)selector target:(id)target
{
	finishtarget=target;
	finishselector=selector;
	[self retain];

	[view setCancelAction:@selector(archiveTaskViewCancelled:) target:self];

	//[view setupProgressViewInPreparingMode];

	static int tmpcounter=0;
	NSString *tmpdir=[NSString stringWithFormat:@".TheUnarchiverTemp%d",tmpcounter++];
	tmpdest=[[destination stringByAppendingPathComponent:tmpdir] retain];

	[NSThread detachNewThreadSelector:@selector(extractThreadEntry) toTarget:self withObject:nil];
}

-(void)extractThreadEntry
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	[self extract];
	[pool release];
}

-(void)extract
{
	if(!unarchiver)
	{
		[view displayOpenError:[NSString stringWithFormat:
		NSLocalizedString(@"The contents of the file \"%@\" can not be extracted with this program.",@"Error message for files not extractable by The Unarchiver"),
		[archivename lastPathComponent]]];

		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		return;
	}

	int foldermode=[self folderCreationMode];
	BOOL copydatepref=[self copyArchiveDateToExtractedFolder];
	BOOL changefilespref=[self changeDateOfExtractedSingleItems];

	[unarchiver setDelegate:self];
	[unarchiver setPropagatesRelevantMetadata:YES];
	[unarchiver setAlwaysRenamesFiles:YES];
	[unarchiver setCopiesArchiveModificationTimeToEnclosingDirectory:copydatepref];
	[unarchiver setCopiesArchiveModificationTimeToSoloItems:copydatepref && changefilespref];
	[unarchiver setResetsDateForSoloItems:!copydatepref && changefilespref];

	XADError error=[unarchiver parse];
	if(error==XADBreakError)
	{
		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		return;
	}
	else if(error)
	{
		if(![view displayError:[NSString stringWithFormat:
			NSLocalizedString(@"There was a problem while reading the contents of the file \"%@\": %@",@"Error message when encountering an error while parsing an archive"),
			[self currentArchiveName],
			[self localizedDescriptionOfError:error]]
		ignoreAll:&ignoreall])
		{
			[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
			return;
		}
		else
		{
			haderrors=YES;
		}
	}

	switch(foldermode)
	{
		case 1: // Enclose multiple items.
		default:
			[unarchiver setDestination:tmpdest];
			[unarchiver setRemovesEnclosingDirectoryForSoloItems:YES];
			[self rememberTempDirectory:tmpdest];
		break;

		case 2: // Always enclose.
			[unarchiver setDestination:tmpdest];
			[unarchiver setRemovesEnclosingDirectoryForSoloItems:NO];
			[self rememberTempDirectory:tmpdest];
		break;

		case 3: // Never enclose.
			[unarchiver setDestination:destination];
			[unarchiver setEnclosingDirectoryName:nil];
		break;
	}

	error=[unarchiver unarchive];
	if(error)
	{
		if(error!=XADBreakError)
		[view displayOpenError:[NSString stringWithFormat:
			NSLocalizedString(@"There was a problem while extracting the contents of the file \"%@\": %@",@"Error message when encountering an error while extracting entries"),
			[self currentArchiveName],
			[self localizedDescriptionOfError:error]]];

		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		return;
	}

	[self performSelectorOnMainThread:@selector(extractFinished) withObject:nil waitUntilDone:NO];
}

-(void)extractFinished
{
	BOOL deletearchivepref=[self deleteArchive];
	BOOL openfolderpref=[self openExtractedItem];

	BOOL soloitem=[unarchiver wasSoloItem];

	// Move files out of temporary directory, if we used one.
	NSString *newpath=nil;
	if([unarchiver enclosingDirectoryName])
	{
		NSString *path=[unarchiver createdItem];
		NSString *filename=[path lastPathComponent];

		newpath=[destination stringByAppendingPathComponent:filename];

		// Check if we accidentally created a package.
		if(!soloitem)
		if([[NSWorkspace sharedWorkspace] isFilePackageAtPath:path])
		{
			newpath=[newpath stringByDeletingPathExtension];
		}

		// Avoid collisions.
		newpath=[XADSimpleUnarchiver _findUniquePathForOriginalPath:newpath];

		// Move files into place
		[XADPlatform moveItemAtPath:path toPath:newpath];
		[XADPlatform removeItemAtPath:tmpdest];
	}

	// Remove temporary directory from crash recovery list.
	[self forgetTempDirectory:tmpdest];

	// Delete archive if requested, but only if no errors were encountered.
	if(deletearchivepref && !haderrors)
	{
		NSString *directory=[archivename stringByDeletingLastPathComponent];
		NSArray *allpaths=[[unarchiver outerArchiveParser] allFilenames];
		NSMutableArray *allfiles=[NSMutableArray arrayWithCapacity:[allpaths count]];
		NSEnumerator *enumerator=[allpaths objectEnumerator];
		NSString *path;
		while((path=[enumerator nextObject]))
		{
			if([[path stringByDeletingLastPathComponent] isEqual:directory])
			[allfiles addObject:[path lastPathComponent]];
		}

		[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
		source:directory destination:nil files:allfiles tag:nil];
		//[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/drag to trash.aif"];
	}

	// Open folder if requested.
	if(openfolderpref)
	{
		if(newpath)
		{
			BOOL isdir;
			[[NSFileManager defaultManager] fileExistsAtPath:newpath isDirectory:&isdir];
			if(isdir&&![[NSWorkspace sharedWorkspace] isFilePackageAtPath:newpath])
			{
				[[NSWorkspace sharedWorkspace] openFile:newpath];
			}
			else
			{
				[[NSWorkspace sharedWorkspace] selectFile:newpath inFileViewerRootedAtPath:@""];
			}
		}
		else
		{
			[[NSWorkspace sharedWorkspace] openFile:destination];
		}
	}

	[docktile hideProgress];
	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)extractFailed
{
	[XADPlatform removeItemAtPath:tmpdest];

	[self forgetTempDirectory:tmpdest];

	[docktile hideProgress];
	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)rememberTempDirectory:(NSString *)tmpdir
{
	NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
	NSArray *tmpdirs=[defs arrayForKey:@"orphanedTempDirectories"];
	if(!tmpdirs) tmpdirs=[NSArray array];
	[defs setObject:[tmpdirs arrayByAddingObject:tmpdir] forKey:@"orphanedTempDirectories"];
	[defs synchronize];
}

-(void)forgetTempDirectory:(NSString *)tmpdir
{
	NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
	NSMutableArray *tmpdirs=[NSMutableArray arrayWithArray:[defs arrayForKey:@"orphanedTempDirectories"]];
	[tmpdirs removeObject:tmpdir];
	[defs setObject:tmpdirs forKey:@"orphanedTempDirectories"];
	[defs synchronize];
}




-(void)archiveTaskViewCancelled:(TUArchiveTaskView *)taskview
{
	cancelled=YES;
}




-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
{
	return cancelled;
}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender encodingNameForXADString:(id <XADString>)string
{
	// TODO: Stop using NSStringEncoding.

	// If the user has set an encoding in the preferences, always use this.
	NSStringEncoding setencoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	if(setencoding) return [XADString encodingNameForEncoding:setencoding];

	// If the user has already been asked for an encoding, try to use it.
	// Otherwise, if the confidence in the guessed encoding is high enough, try that.
	int threshold=[[NSUserDefaults standardUserDefaults] integerForKey:@"autoDetectionThreshold"];

	NSStringEncoding encoding=0;
	if(selected_encoding) encoding=selected_encoding;
	else if([string confidence]*100>=threshold) encoding=[string encoding];

	// If we have an encoding we trust, and it can decode the string, use it.
	if(encoding && [string canDecodeWithEncoding:encoding])
	return [XADString encodingNameForEncoding:encoding];

	// Otherwise, ask the user for an encoding.
	selected_encoding=[view displayEncodingSelectorForXADString:string];
	if(!selected_encoding)
	{
		cancelled=YES;
		return nil;
	}
	return [XADString encodingNameForEncoding:selected_encoding];
}

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)sender
{
	if(globalpassword)
	{
		[sender setPassword:globalpassword];
		if(globalpasswordencoding)
		{
			[[sender archiveParser] setPasswordEncodingName:
			[XADString encodingNameForEncoding:globalpasswordencoding]];
		}
	}
	else
	{
		BOOL applytoall;
		NSStringEncoding encoding;
		NSString *password=[view displayPasswordInputWithApplyToAllPointer:&applytoall
		encodingPointer:&encoding];

		if(password)
		{
			[sender setPassword:password];
			if(encoding)
			{
				[[sender archiveParser] setPasswordEncodingName:
				[XADString encodingNameForEncoding:encoding]];
			}

			if(applytoall)
			{
				globalpassword=[password retain];
				globalpasswordencoding=encoding;
			}
		}
		else
		{
			cancelled=YES;
		}
	}
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	XADPath *name=[dict objectForKey:XADFileNameKey];

	// TODO: Do something prettier here.
	NSStringEncoding encoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	if(!encoding) encoding=selected_encoding;
	if(!encoding) encoding=[name encoding];

	NSString *namestring=[name stringWithEncoding:encoding];

	if(name) [view setName:namestring];
	else [view setName:@""];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize
{
	double progress=(double)totalprogress/(double)totalsize;
	[view setProgress:progress];
	[docktile setProgress:progress];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress
{
	[view setProgress:totalprogress];
	[docktile setProgress:totalprogress];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;
{
	if(ignoreall||cancelled) return;

	if(error)
	{
		XADPath *filename=[dict objectForKey:XADFileNameKey];

		NSNumber *isresfork=[dict objectForKey:XADIsResourceForkKey];
		if(isresfork&&[isresfork boolValue])
		{
			cancelled=![view displayError:[NSString stringWithFormat:
				NSLocalizedString(@"Could not extract the resource fork for the file \"%@\" from the archive \"%@\":\n%@",@"Error message string. The first %@ is the file name, the second the archive name, the third is error message"),
				[self stringForXADPath:filename],
				[self currentArchiveName],
				[self localizedDescriptionOfError:error]]
			ignoreAll:&ignoreall];
		}
		else
		{
			cancelled=![view displayError:[NSString stringWithFormat:
				NSLocalizedString(@"Could not extract the file \"%@\" from the archive \"%@\": %@",@"Error message string. The first %@ is the file name, the second the archive name, the third is error message"),
				[self stringForXADPath:filename],
				[self currentArchiveName],
				[self localizedDescriptionOfError:error]]
			ignoreAll:&ignoreall];
		}

		haderrors=YES;
	}
}

/*-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique;
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender deferredReplacementPathForOriginalPath:(NSString *)path
suggestedPath:(NSString *)unique;*/

@end

