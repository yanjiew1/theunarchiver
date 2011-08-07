#import "XADUnarchiver.h"

@interface XADPlatform:NSObject {}

+(XADError)extractResourceForkEntryWithDictionary:(NSDictionary *)dict
unarchiver:(XADUnarchiver *)unarchiver toPath:(NSString *)destpath;

+(XADError)updateFileAttributesAtPath:(NSString *)path
forEntryWithDictionary:(NSDictionary *)dict parser:(XADArchiveParser *)parser
preservePermissions:(BOOL)preservepermissions;

+(XADError)createLinkAtPath:(NSString *)path withDestinationPath:(NSString *)link;

+(id)readCloneableMetadataFromPath:(NSString *)path;
+(void)writeCloneableMetadata:(id)metadata toPath:(NSString *)path;

+(NSString *)uniqueDirectoryPathWithParentDirectory:(NSString *)parent;

+(double)currentTimeInSeconds;

@end
