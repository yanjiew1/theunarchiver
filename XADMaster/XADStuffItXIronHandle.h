#import "CSBlockStreamHandle.h"

@interface XADStuffItXIronHandle:CSBlockStreamHandle
{
	uint8_t *block,*sorted;
	uint32_t *table;

	int st4transform,fancymtf;

	int maxfreq1,maxfreq2,maxfreq3;
	int byteshift1,byteshift2,byteshift3;
	int countshift1,countshift2,countshift3;
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(void)decodeBlockWithLength:(int)blocksize;

@end
