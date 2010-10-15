#import "XADARCParser.h"
#import "XADARCHandles.h"
#import "XADRLE90Handle.h"
#import "XADCompressHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADARCParser

+(int)requiredHeaderSize { return 0x1d; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<0x1d) return NO;

	// Check ID.
	if(bytes[0x00]!=0x1a) return NO;

	// Check file name.
	if(bytes[0x02]==0) return NO;
	for(int i=0x02;i<0x0f && bytes[i]!=0;i++) if(bytes[i]<32) return NO;

	// Stop checking here if the file is an old-style uncompressed file.
	if(bytes[0x01]==0x01) return YES;

	// Check sizes.
	uint32_t compsize=CSUInt32LE(&bytes[0x0f]);
	uint32_t uncompsize=CSUInt32LE(&bytes[0x19]);
	if(compsize>0x1000000) return NO; // Assume files are less than 16 megabytes.
	if(compsize>uncompsize) return NO; // Assume files are always compressed or stored.

	// Check next file or end marker, if it fits in the buffer.
	uint32_t nextoffset=0x1d+compsize;
	if(bytes[0x01]&0x80) nextoffset+=12;

	if(length>=nextoffset+1)
	if(bytes[nextoffset]!=0x1a) return NO;

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	XADPath *parent=[self XADPath];

	while([self shouldKeepParsing] && ![fh atEndOfFile])
	{
		// Scan for next header.
		int n=0;
		for(;;)
		{
			int magic=[fh readUInt8];
			if(magic==0x1a) break;
			if(++n>=64) [XADException raiseIllegalDataException];
		}

		int method=[fh readUInt8];
		if(method==0x00) break;

		if(method==0x1f || method==0x80)
		{
			if([parent depth]==0) break;
			parent=[parent pathByDeletingLastPathComponent];
			continue;
		}

		uint8_t namebuf[13];
		[fh readBytes:13 toBuffer:namebuf];

		int namelength=0;
		while(namelength<12 && namebuf[namelength]!=0) namelength++;
		if(namelength>1 && namebuf[namelength-1]==' ') namelength--;
		if(namelength>1 && namebuf[namelength-1]=='.') namelength--;
		NSData *namedata=[NSData dataWithBytes:namebuf length:namelength];

		uint32_t compsize=[fh readUInt32LE];
		int date=[fh readUInt16LE];
		int time=[fh readUInt16LE];
		int crc16=[fh readUInt16LE];

		uint32_t uncompsize;
		if(method==1) uncompsize=compsize;
		else uncompsize=[fh readUInt32LE];

		uint32_t loadaddress,execaddress,fileattrs;
		if(method&0x80)
		{
			loadaddress=[fh readUInt32LE];
			execaddress=[fh readUInt32LE];
			fileattrs=[fh readUInt32LE];
		}

		off_t dataoffset=[fh offsetInFile];

		XADString *name=[self XADStringWithData:namedata];
		XADPath *path=[parent pathByAppendingPathComponent:name];

		if(method==0x1e || (method==0x82&&((loadaddress&0xffffff00)==0xfffddc00)))
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				path,XADFileNameKey,
				[NSNumber numberWithBool:YES],XADIsDirectoryKey,
				[NSDate XADDateWithMSDOSDate:date time:time],XADLastModificationDateKey,
				[NSNumber numberWithInt:method],@"ARCMethod",
			nil];

			[self addEntryWithDictionary:dict];

			parent=path;
		}
		else
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				path,XADFileNameKey,
				[NSNumber numberWithUnsignedLong:uncompsize],XADFileSizeKey,
				[NSNumber numberWithUnsignedLong:compsize],XADCompressedSizeKey,
				[NSNumber numberWithUnsignedLongLong:dataoffset],XADDataOffsetKey,
				[NSNumber numberWithUnsignedLong:compsize],XADDataLengthKey,
				[NSDate XADDateWithMSDOSDate:date time:time],XADLastModificationDateKey,
				[NSNumber numberWithInt:method],@"ARCMethod",
				[NSNumber numberWithInt:crc16],@"ARCCRC16",
			nil];

			NSString *methodname=nil;
			switch(method&0x7f)
			{
				case 0x01: methodname=@"None (old)"; break;
				case 0x02: methodname=@"None"; break;
				case 0x03: methodname=@"Packed"; break;
				case 0x04: methodname=@"Squeezed"; break;
				case 0x05: methodname=@"Crunched (no packing)"; break;
				case 0x06: methodname=@"Crunched"; break;
				case 0x07: methodname=@"Crunched (fast)"; break;
				case 0x08: methodname=@"Crunched (LZW)"; break;
				case 0x09: methodname=@"Squashed"; break;
				case 0x0a: methodname=@"Crushed"; break;
				case 0x0b: methodname=@"Distilled"; break;
				case 0x7f: methodname=@"Compressed"; break;
			}
			if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

			if(method&0x80)
			{
				[dict setObject:[NSNumber numberWithUnsignedInt:loadaddress] forKey:@"ARCArchimedesLoadAddress"];
				[dict setObject:[NSNumber numberWithUnsignedInt:execaddress] forKey:@"ARCArchimedesExecAddress"];
				[dict setObject:[NSNumber numberWithUnsignedInt:fileattrs] forKey:@"ARCArchimedesFileAttributes"];
			}

			[self addEntryWithDictionary:dict];

			[fh seekToFileOffset:dataoffset+compsize];
		}
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	if([dict objectForKey:XADIsDirectoryKey]) return nil;

	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	int method=[[dict objectForKey:@"ARCMethod"] intValue];
	int crc=[[dict objectForKey:@"ARCCRC16"] intValue];
	uint32_t length=[[dict objectForKey:XADFileSizeKey] unsignedIntValue];

	switch(method&0x7f)
	{
		case 0x01: // Stored (untested)
		case 0x02: // Stored
		break;

		case 0x03: // Packed
			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x04: // Squeezed+packed
			handle=[[[XADARCSqueezeHandle alloc] initWithHandle:handle] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x05: // Crunched
			handle=[[[XADARCCrunchHandle alloc] initWithHandle:handle
			length:length useFastHash:NO] autorelease];
		break;

		case 0x06: // Crunched+packed
			handle=[[[XADARCCrunchHandle alloc] initWithHandle:handle useFastHash:NO] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x07: // Crunched+packed (fast)
			handle=[[[XADARCCrunchHandle alloc] initWithHandle:handle useFastHash:YES] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x08: // Crunched+packed (LZW)
		{
			int byte=[handle readUInt8];
			if(byte!=0x0c) [XADException raiseIllegalDataException];

			handle=[[[XADCompressHandle alloc] initWithHandle:handle
			flags:0x8c] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		}
		break;

		case 0x09: // Squashed
			handle=[[[XADCompressHandle alloc] initWithHandle:handle
			length:length flags:0x8d] autorelease];
		break;

		case 0x0a: // Distilled
		break;

		case 0x7f: // Compressed (untested)
		{
			int byte=[handle readUInt8];

			handle=[[[XADCompressHandle alloc] initWithHandle:handle
			length:length flags:byte|0x80] autorelease];
		}
		break;

		default: return nil;
	}

	if(checksum) handle=[XADCRCHandle IBMCRC16HandleWithHandle:handle length:length correctCRC:crc conditioned:NO];

	return handle;
}

-(NSString *)formatName { return @"ARC"; }

@end




