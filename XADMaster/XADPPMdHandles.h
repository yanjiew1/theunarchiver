#import "CSByteStreamHandle.h"
#import "PPMdVariantG.h"
#import "PPMdVariantH.h"
#import "PPMdVariantI.h"
#import "PPMdSubAllocatorVariantG.h"
#import "PPMdSubAllocatorVariantH.h"
#import "PPMdSubAllocatorVariantI.h"
#import "PPMdSubAllocatorBrimstone.h"

@interface XADPPMdVariantGHandle:CSByteStreamHandle
{
	PPMdModelVariantG model;
	PPMdSubAllocatorVariantG *alloc;
	int max;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XADPPMdVariantHHandle:CSByteStreamHandle
{
	PPMdModelVariantH model;
	PPMdSubAllocatorVariantH *alloc;
	int max;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XADPPMdVariantIHandle:CSByteStreamHandle
{
	PPMdModelVariantI model;
	PPMdSubAllocatorVariantI *alloc;
	int max,method;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XADStuffItXBrimstoneHandle:CSByteStreamHandle
{
	PPMdModelVariantG model;
	PPMdSubAllocatorBrimstone *alloc;
	int max;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XAD7ZipPPMdHandle:XADPPMdVariantHHandle
{
}

-(void)resetByteStream;

@end
