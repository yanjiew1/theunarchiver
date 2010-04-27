#import "CSHandle.h"

typedef struct XADSparseRegion
{
	int nextRegion;
	off_t offset;
	off_t size;
	BOOL hasData;
	off_t dataOffset;
} XADSparseRegion;

@interface XADSparseHandle:CSHandle
{
	CSHandle *parent;
	XADSparseRegion *regions;
	int numRegions;
	int currentRegion;
	off_t currentOffset;
	off_t realFileSize;
}

-(id)initWithHandle:(CSHandle *)handle size:(off_t)size;
-(id)initAsCopyOf:(XADSparseHandle *)other;
-(void)dealloc;

-(void)addSparseRegionFrom:(off_t)start length:(off_t)length;
-(void)addFinalSparseRegionEndingAt:(off_t)regionEndsAt;
-(void)setSingleEmptySparseRegion;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end