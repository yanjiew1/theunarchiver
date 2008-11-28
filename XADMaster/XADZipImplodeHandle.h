#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADZipImplodeHandle:XADLZSSHandle
{
	XADPrefixCode *literalcode,*lengthcode,*offsetcode;
	int offsetbits;
	BOOL literals;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict hasLiterals:(BOOL)hasliterals;
-(void)dealloc;

-(void)resetLZSSHandle;
-(XADPrefixTree *)allocAndParseTreeOfSize:(int)size;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length;

@end
