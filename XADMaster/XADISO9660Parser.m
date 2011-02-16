#import "XADISO9660Parser.h"

@implementation XADISO9660Parser

+(int)requiredHeaderSize { return 2448*16+2048; }

static BOOL IsISO9660PrimaryVolumeDescriptor(const uint8_t *bytes,int length,int offset)
{
	if(offset+2048>length) return NO;

	const uint8_t *block=bytes+offset;
	if(block[0]!=1) return NO;
	if(block[1]!='C') return NO;
	if(block[2]!='D') return NO;
	if(block[3]!='0') return NO;
	if(block[4]!='0') return NO;
	if(block[5]!='1') return NO;
	if(block[6]!=1) return NO;
	if(block[7]!=0) return NO;

	return YES;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(IsISO9660PrimaryVolumeDescriptor(bytes,length,16*2048))
	{
		[props setObject:[NSNumber numberWithInt:2048] forKey:@"ISO9660ImageBlockSize"];
		[props setObject:[NSNumber numberWithInt:0] forKey:@"ISO9660ImageBlockOffset"];
		return YES;
	}

	if(IsISO9660PrimaryVolumeDescriptor(bytes,length,16*2336)) // Untested
	{
		[props setObject:[NSNumber numberWithInt:2336] forKey:@"ISO9660ImageBlockSize"];
		[props setObject:[NSNumber numberWithInt:0] forKey:@"ISO9660ImageBlockOffset"];
		return YES;
	}

	if(IsISO9660PrimaryVolumeDescriptor(bytes,length,16*2352+16))
	{
		[props setObject:[NSNumber numberWithInt:2352] forKey:@"ISO9660ImageBlockSize"];
		[props setObject:[NSNumber numberWithInt:16] forKey:@"ISO9660ImageBlockOffset"];
		return YES;
	}

	if(IsISO9660PrimaryVolumeDescriptor(bytes,length,16*2368+16)) // Untested
	{
		[props setObject:[NSNumber numberWithInt:2368] forKey:@"ISO9660ImageBlockSize"];
		[props setObject:[NSNumber numberWithInt:16] forKey:@"ISO9660ImageBlockOffset"];
		return YES;
	}

	if(IsISO9660PrimaryVolumeDescriptor(bytes,length,16*2448+16)) // Untested
	{
		[props setObject:[NSNumber numberWithInt:2448] forKey:@"ISO9660ImageBlockSize"];
		[props setObject:[NSNumber numberWithInt:16] forKey:@"ISO9660ImageBlockOffset"];
		return YES;
	}

	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	blocksize=[[[self properties] objectForKey:@"ISO9660ImageBlockSize"] intValue];
	blockoffset=[[[self properties] objectForKey:@"ISO9660ImageBlockOffset"] intValue];

	for(int block=17;;block++)
	{
		[fh seekToFileOffset:blocksize*block+blockoffset];

		int type=[fh readUInt8];

		uint8_t identifier[5];
		[fh readBytes:5 toBuffer:identifier];
		if(memcmp(identifier,"CD001",5)!=0) break;

		if(type==2)
		{
			int version=[fh readUInt8];
			if(version!=1) continue;

			int flags=[fh readUInt8];
			if(flags!=0) continue;

			[fh skipBytes:80];

			int esc1=[fh readUInt8];
			int esc2=[fh readUInt8];
			int esc3=[fh readUInt8];
			if(esc1!=0x25) continue;
			if(esc2!=0x2f) continue;
			if(esc3!=0x40 && esc3!=0x43 && esc3!=0x45) continue;

			[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:@"ISO9660IsJoliet"];
			[self parseVolumeDescriptorAtBlock:block isJoliet:YES];
			return;
		}
		else if(type==255)
		{
			break;
		}
	}

	[self parseVolumeDescriptorAtBlock:16 isJoliet:NO];
}

-(void)parseVolumeDescriptorAtBlock:(uint32_t)block isJoliet:(BOOL)isjoliet
{
	CSHandle *fh=[self handle];

	[fh seekToFileOffset:blocksize*block+blockoffset+8];

	XADString *system=[self readStringOfLength:32 isJoliet:isjoliet]; 
	XADString *volume=[self readStringOfLength:32 isJoliet:isjoliet]; 
	[fh skipBytes:8];
	/*uint32_t volumespacesize=*/[fh readUInt32LE];
	[fh skipBytes:36];
	uint32_t volumesetsize=[fh readUInt16LE];
	[fh skipBytes:2];
	uint32_t volumesequencenumber=[fh readUInt16LE];
	[fh skipBytes:2];
	uint32_t logicalblocksize=[fh readUInt16LE];
	[fh skipBytes:2];
	/*uint32_t pathtablesize=*/[fh readUInt32LE];
	[fh skipBytes:4];
	/*uint32_t pathtablelocation=*/[fh readUInt32LE];
	/*uint32_t optionalpathtablelocation=*/[fh readUInt32LE];
	[fh skipBytes:8];

	// Root directory record
	[fh skipBytes:2];
	uint32_t rootblock=[fh readUInt32LE];
	[fh skipBytes:4];
	uint32_t rootlength=[fh readUInt32LE];
	[fh skipBytes:20];

	XADString *volumeset=[self readStringOfLength:128 isJoliet:isjoliet]; 
	XADString *publisher=[self readStringOfLength:128 isJoliet:isjoliet]; 
	XADString *datapreparer=[self readStringOfLength:128 isJoliet:isjoliet];
	XADString *application=[self readStringOfLength:128 isJoliet:isjoliet];
	XADString *copyrightfile=[self readStringOfLength:37 isJoliet:isjoliet];
	XADString *abstractfile=[self readStringOfLength:37 isJoliet:isjoliet];
	XADString *bibliographicfile=[self readStringOfLength:37 isJoliet:isjoliet];

	NSDate *creation=[self readLongDateAndTime];
	NSDate *modification=[self readLongDateAndTime];
	NSDate *expiration=[self readLongDateAndTime];
	NSDate *effective=[self readLongDateAndTime];

	//int version=[fh readUInt8];

	if(logicalblocksize!=2048) [XADException raiseIllegalDataException];

	if(volume) [self setObject:volume forPropertyKey:XADDiskLabelKey];
	if(creation) [self setObject:creation forPropertyKey:XADCreationDateKey];
	if(modification) [self setObject:modification forPropertyKey:XADLastModificationDateKey];

	if(system) [self setObject:system forPropertyKey:@"ISO9660SystemIndentifier"];
	if(volume) [self setObject:volume forPropertyKey:@"ISO9660VolumeIndentifier"];
	if(volumeset) [self setObject:volumeset forPropertyKey:@"ISO9660VolumeSetIndentifier"];
	if(publisher) [self setObject:publisher forPropertyKey:@"ISO9660PublisherIndentifier"];
	if(datapreparer) [self setObject:datapreparer forPropertyKey:@"ISO9660DataPreparerIndentifier"];
	if(application) [self setObject:application forPropertyKey:@"ISO9660ApplicationIndentifier"];
	if(copyrightfile) [self setObject:copyrightfile forPropertyKey:@"ISO9660CopyrightFileIndentifier"];
	if(abstractfile) [self setObject:abstractfile forPropertyKey:@"ISO9660AbstractFileIndentifier"];
	if(bibliographicfile) [self setObject:bibliographicfile forPropertyKey:@"ISO9660BibliographicFileIndentifier"];

	if(creation) [self setObject:creation forPropertyKey:@"ISO9660CreationDateAndTime"];
	if(modification) [self setObject:modification forPropertyKey:@"ISO9660ModificationDateAndTime"];
	if(expiration) [self setObject:expiration forPropertyKey:@"ISO9660ExpirationDateAndTime"];
	if(effective) [self setObject:effective forPropertyKey:@"ISO9660EffectiveDateAndTime"];

	[self setObject:[NSNumber numberWithInt:volumesetsize] forPropertyKey:@"ISO9660VolumeSetSize"];
	[self setObject:[NSNumber numberWithInt:volumesequencenumber] forPropertyKey:@"ISO9660VolumeSequenceNumber"];

	[self parseDirectoryWithPath:[self XADPath] atBlock:rootblock
	length:rootlength isJoliet:isjoliet];
}

-(void)parseDirectoryWithPath:(XADPath *)path atBlock:(uint32_t)block
length:(uint32_t)length isJoliet:(BOOL)isjoliet
{
	CSHandle *fh=[self handle];

	off_t extentstart=block*blocksize+blockoffset;
	off_t extentend=extentstart+length+(length/blocksize)*(blocksize-2048);

	[fh seekToFileOffset:extentstart];

	int selflength=[fh readUInt8];
	[fh skipBytes:selflength-1];

	int parentlength=[fh readUInt8];
	[fh skipBytes:parentlength-1];

	while([fh offsetInFile]<extentend)
	{
		off_t startpos=[fh offsetInFile];

		// If the physical block size is not 2048, we might end exactly on the
		// end of a block, and will have to skip over the gap to the next block.
		if(blocksize!=2048)
		{
			int blockpos=(startpos-blockoffset)%blocksize;
			if(blockpos==2048)
			{
				int block=(startpos-blockoffset)/blocksize;
				[fh seekToFileOffset:(block+1)*blocksize+blockoffset];
				continue;
			}
		}

		int recordlength=[fh readUInt8];

		// If the record length is 0, we need to skip to the next block.
		if(recordlength==0)
		{
			int block=(startpos-blockoffset)/blocksize;
			[fh seekToFileOffset:(block+1)*blocksize+blockoffset];
			continue;
		}

		/*int extlength=*/[fh readUInt8];

		uint32_t location=[fh readUInt32LE];
		[fh skipBytes:4];
		uint32_t length=[fh readUInt32LE];
		[fh skipBytes:4];

		NSDate *date=[self readShortDateAndTime];

		int flags=[fh readUInt8];
		int unitsize=[fh readUInt8];
		int gapsize=[fh readUInt8];
		int volumesequencenumber=[fh readUInt16LE];
		[fh skipBytes:2];

		int namelength=[fh readUInt8];
		uint8_t name[namelength];
		[fh readBytes:namelength toBuffer:name];
		if((namelength&1)==1) [fh skipBytes:1];

		XADString *filename;
		if(isjoliet)
		{
			NSMutableString *str=[NSMutableString stringWithCapacity:namelength/2];
			for(int i=0;i+2<=namelength;i+=2) [str appendFormat:@"%C",CSUInt16BE(&name[i])];
			filename=[self XADStringWithString:str];
		}
		else
		{
			filename=[self XADStringWithBytes:name length:namelength];
		}

		if(flags&0x80) [XADException raiseNotSupportedException];

		XADPath *currpath=[path pathByAppendingPathComponent:filename];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			currpath,XADFileNameKey,
			date,XADLastModificationDateKey,
			[NSNumber numberWithUnsignedInt:length],XADFileSizeKey,
			[NSNumber numberWithUnsignedInt:((length+2047)/2048)*blocksize],XADCompressedSizeKey,
			[NSNumber numberWithUnsignedInt:location],@"ISO9660LocationOfExtent",
			[NSNumber numberWithUnsignedInt:flags],@"ISO9660FileFlags",
			[NSNumber numberWithUnsignedInt:unitsize],@"ISO9660FileUnitSize",
			[NSNumber numberWithUnsignedInt:gapsize],@"ISO9660InterleaveGapSize",
			[NSNumber numberWithUnsignedInt:volumesequencenumber],@"ISO9660VolumeSequenceNumber",
		nil];

		if(flags&0x01) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsHiddenKey];
		if(flags&0x02) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
		if(flags&0x04) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

		[self addEntryWithDictionary:dict];

		if(flags&0x02)
		[self parseDirectoryWithPath:currpath atBlock:location length:length isJoliet:isjoliet];

		[fh seekToFileOffset:startpos+recordlength];
	}
}




-(XADString *)readStringOfLength:(int)length isJoliet:(BOOL)isjoliet
{
	uint8_t buffer[length];
	[[self handle] readBytes:length toBuffer:buffer];

	if(isjoliet)
	{
		if(length&1) length--;

		while(length>0 && (CSUInt16BE(&buffer[length-2])==0x0020 ||
		CSUInt16BE(&buffer[length-2])==0x0000)) length-=2;

		if(!length) return nil;

		NSMutableString *str=[NSMutableString stringWithCapacity:length/2];
		for(int i=0;i+2<=length;i+=2) [str appendFormat:@"%C",CSUInt16BE(&buffer[i])];
		return [self XADStringWithString:str];
	}
	else
	{
		while(length>0 && (buffer[length-1]==0x20 || buffer[length-1]==0x00))
		length--;

		if(!length) return nil;

		return [self XADStringWithBytes:buffer length:length];
	}
}

-(NSDate *)readLongDateAndTime
{
	uint8_t buffer[17];
	[[self handle] readBytes:17 toBuffer:buffer];

	if(memcmp(buffer,"0000000000000000",16)==0 && buffer[16]==0) return nil;
	for(int i=0;i<16;i++) if(buffer[i]<'0'||buffer[i]>'9') return nil;

	int year=(buffer[0]-'0')*1000+(buffer[1]-'0')*100+(buffer[2]-'0')*10+(buffer[3]-'0');
	int month=(buffer[4]-'0')*10+(buffer[5]-'0');
	int day=(buffer[6]-'0')*10+(buffer[7]-'0');
	int hour=(buffer[8]-'0')*10+(buffer[9]-'0');
	int minute=(buffer[10]-'0')*10+(buffer[11]-'0');
	int second=(buffer[12]-'0')*10+(buffer[13]-'0');
	//int hundreths=(buffer[14]-'0')*10+(buffer[15]-'0');
	int offset=(int8_t)buffer[16];

	NSTimeZone *tz=[NSTimeZone timeZoneForSecondsFromGMT:offset*15*60];
	return [NSCalendarDate dateWithYear:year month:month day:day
	hour:hour minute:minute second:second timeZone:tz];
}

-(NSDate *)readShortDateAndTime
{
	uint8_t buffer[7];
	[[self handle] readBytes:7 toBuffer:buffer];

	int year=buffer[0]+1900;
	int month=buffer[1];
	int day=buffer[2];
	int hour=buffer[3];
	int minute=buffer[4];
	int second=buffer[5];
	int offset=(int8_t)buffer[16];

	NSTimeZone *tz=[NSTimeZone timeZoneForSecondsFromGMT:offset*15*60];
	return [NSCalendarDate dateWithYear:year month:month day:day
	hour:hour minute:minute second:second timeZone:tz];
}




-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(NSString *)formatName { return @"ISO 9660"; }

@end
