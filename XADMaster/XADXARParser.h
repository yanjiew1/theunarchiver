#import "XADArchiveParser.h"

@interface XADXARParser:XADArchiveParser
{
	off_t heapoffset;
	int state;

	NSDictionary *filedefinitions,*datadefinitions,*resforkdefinitions,*finderdefinitions;

	NSMutableDictionary *currfile,*currext;
	NSMutableArray *files,*filestack;
	NSMutableString *currstring;

	CSHandle *lzmahandle;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(void)finishFile:(NSMutableDictionary *)file parentPath:(NSString *)parent;

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname
attributes:(NSDictionary *)attributes;
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname;
-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;

-(void)startSimpleElement:(NSString *)name attributes:(NSDictionary *)attributes
definitions:(NSDictionary *)definitions destinationDictionary:(NSMutableDictionary *)dest;
-(void)endSimpleElement:(NSString *)name definitions:(NSDictionary *)definitions
destinationDictionary:(NSMutableDictionary *)dest;
-(void)parseDefinition:(NSArray *)definition string:(NSString *)string
destinationDictionary:(NSMutableDictionary *)dest;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForEncodingStyle:(NSString *)encodingstyle offset:(off_t)offset
length:(off_t)length size:(off_t)size checksum:(NSData *)checksum checksumStyle:(NSString *)checksumstyle;
-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict;

-(NSString *)formatName;

@end
