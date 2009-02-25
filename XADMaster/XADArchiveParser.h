#import <Foundation/Foundation.h>
#import "XADException.h"
#import "XADString.h"
#import "XADRegex.h"
#import "CSHandle.h"
#import "XADSkipHandle.h"
#import "Checksums.h"

extern NSString *XADFileNameKey;
extern NSString *XADFileSizeKey;
extern NSString *XADCompressedSizeKey;
extern NSString *XADLastModificationDateKey;
extern NSString *XADLastAccessDateKey;
extern NSString *XADCreationDateKey;
extern NSString *XADFileTypeKey;
extern NSString *XADFileCreatorKey;
extern NSString *XADFinderFlagsKey;
extern NSString *XADFinderInfoKey;
extern NSString *XADPosixPermissionsKey;
extern NSString *XADPosixUserKey;
extern NSString *XADPosixGroupKey;
extern NSString *XADPosixUserNameKey;
extern NSString *XADPosixGroupNameKey;
extern NSString *XADDOSFileAttributesKey;
extern NSString *XADWindowsFileAttributesKey;

extern NSString *XADIsEncryptedKey;
extern NSString *XADIsCorruptedKey;
extern NSString *XADIsDirectoryKey;
extern NSString *XADIsResourceForkKey;
extern NSString *XADIsArchiveKey;
extern NSString *XADIsLinkKey;
extern NSString *XADIsHardLinkKey;
extern NSString *XADLinkDestinationKey;
extern NSString *XADIsCharacterDeviceKey;
extern NSString *XADIsBlockDeviceKey;
extern NSString *XADDeviceMajorKey;
extern NSString *XADDeviceMinorKey;
extern NSString *XADIsFIFOKey;

extern NSString *XADCommentKey;
extern NSString *XADDataOffsetKey;
extern NSString *XADDataLengthKey;
extern NSString *XADCompressionNameKey;

extern NSString *XADIsSolidKey;
extern NSString *XADFirstSolidEntryKey;
extern NSString *XADNextSolidEntryKey;
extern NSString *XADSolidObjectKey;
extern NSString *XADSolidOffsetKey;
extern NSString *XADSolidLengthKey;

// Archive properties only
extern NSString *XADArchiveNameKey;


/*// Internal use
extern NSString *XADResourceDataKey;
extern NSString *XADDittoPropertiesKey;

// Deprecated
extern NSString *XADResourceForkData;
extern NSString *XADFinderFlags;
*/

@interface XADArchiveParser:NSObject
{
	CSHandle *sourcehandle;
	XADSkipHandle *skiphandle;

	id delegate;
	NSString *password;

	NSMutableDictionary *properties;
	XADStringSource *stringsource;

	id parsersolidobj;
	NSMutableDictionary *firstsoliddict,*prevsoliddict;
	id currsolidobj;
	CSHandle *currsolidhandle;
}

+(void)initialize;
+(Class)archiveParserClassForHandle:(CSHandle *)handle name:(NSString *)name;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name;
+(XADArchiveParser *)archiveParserForPath:(NSString *)filename;
+(NSArray *)volumesForFilename:(NSString *)name;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(NSDictionary *)properties;
-(NSString *)name;
-(BOOL)isEncrypted;

-(id)delegate;
-(void)setDelegate:(id)newdelegate;

-(NSString *)password;
-(void)setPassword:(NSString *)newpassword;

-(XADString *)linkDestinationForDictionary:(NSDictionary *)dict;



// Internal functions

-(NSString *)name;
-(CSHandle *)handle;
-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict;
-(XADSkipHandle *)skipHandle;

-(NSArray *)volumes;
-(off_t)offsetForVolume:(int)disk offset:(off_t)offset;

-(void)setObject:(id)object forPropertyKey:(NSString *)key;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict;
-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos;

-(XADString *)XADStringWithString:(NSString *)string;
-(XADString *)XADStringWithData:(NSData *)data;
-(XADString *)XADStringWithData:(NSData *)data encoding:(NSStringEncoding)encoding;
-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length;
-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length encoding:(NSStringEncoding)encoding;
-(XADString *)XADStringWithCString:(const char *)string;
-(XADString *)XADStringWithCString:(const char *)string encoding:(NSStringEncoding)encoding;

-(NSData *)encodedPassword;
-(char *)encodedCStringPassword;


// Subclasses implement these:

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(XADRegex *)volumeRegexForFilename:(NSString *)filename;
+(BOOL)isFirstVolume:(NSString *)filename;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

// Solid archive helpers:

-(CSHandle *)subHandleFromSolidStreamForEntryWithDictionary:(NSDictionary *)dict;
-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;

@end

@interface NSObject (XADArchiveParserDelegate)

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict;
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser;

@end

NSMutableArray *XADSortVolumes(NSMutableArray *volumes,NSString *firstfileextension);
