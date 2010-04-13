#import "XADMacArchiveParser.h"

@interface XADZipParser:XADMacArchiveParser
{
	NSMutableDictionary *prevdict;
	NSData *prevname;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parseWithSeparateMacForks;
-(BOOL)findEndOfCentralDirectory:(off_t *)offsptr zip64Locator:(off_t *)locatorptr;
//-(void)findNextZipMarkerStartingAt:(off_t)startpos;
//-(void)findNoSeekMarkerForDictionary:(NSMutableDictionary *)dict;
-(NSDictionary *)parseZipExtraWithLength:(int)length nameData:(NSData *)namedata;

-(void)addZipEntryWithSystem:(int)system
extractVersion:(int)extractversion
flags:(int)flags
compressionMethod:(int)compressionmethod
date:(uint32_t)date
crc:(uint32_t)crc
compressedSize:(off_t)compsize
uncompressedSize:(off_t)uncompsize
extendedFileAttributes:(uint32_t)extfileattrib
extraDictionary:(NSDictionary *)extradict
dataOffset:(off_t)dataoffset
nameData:(NSData *)namedata
commentData:(NSData *)commentdata
isLastEntry:(BOOL)islastentry;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)decompressionHandleWithHandle:(CSHandle *)parent method:(int)method flags:(int)flags size:(off_t)size;

-(NSString *)formatName;

@end
