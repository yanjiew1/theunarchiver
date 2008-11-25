#import "XADStuffIt13Handle.h"
#import "XADException.h"

static const int *FirstTreeLengths[5];
static const int *SecondTreeLengths[5];
static const int *OffsetTreeLengths[5];
static const int OffsetTreeSize[5];
static const int MetaCodes[37];
static const int MetaCodeLengths[37];

@implementation XADStuffIt13Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:65536])
	{
		firsttree=secondtree=offsettree=nil;
	}
	return self;
}

-(void)dealloc
{
	[firsttree release];
	[secondtree release];
	[offsettree release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	[firsttree release];
	[secondtree release];
	[offsettree release];
	firsttree=secondtree=offsettree=nil;

	int val=CSInputNextByte(input);

	int tree=val>>4;

	if(tree==0)
	{
		XADPrefixTree *metatree=[XADPrefixTree prefixTree];
		for(int i=0;i<37;i++) [metatree addValue:i forCodeWithLowBitFirst:MetaCodes[i] length:MetaCodeLengths[i]];

		firsttree=[[self parseTreeOfSize:321 metaTree:metatree] retain];
		if(val&0x08) secondtree=[firsttree retain];
		else secondtree=[[self parseTreeOfSize:321 metaTree:metatree] retain];
		offsettree=[[self parseTreeOfSize:(val&0x07)+10 metaTree:metatree] retain];
	}
	else if(tree<6)
	{
		firsttree=[[self createTreeWithLengths:FirstTreeLengths[tree-1] numberOfCodes:321] retain];
		secondtree=[[self createTreeWithLengths:SecondTreeLengths[tree-1] numberOfCodes:321] retain];
		offsettree=[[self createTreeWithLengths:OffsetTreeLengths[tree-1] numberOfCodes:OffsetTreeSize[tree-1]] retain];
	}
	else [XADException raiseIllegalDataException];

	currtree=firsttree;
}

-(XADPrefixTree *)parseTreeOfSize:(int)numcodes metaTree:(XADPrefixTree *)metatree
{
	int length=0;
	int lengths[numcodes];

	for(int i=0;i<numcodes;i++)
	{
		int val=CSInputNextSymbolFromTreeLE(input,metatree);

		switch(val)
		{
			case 31: length=-1; break;
			case 32: length++; break;
			case 33: length--; break;
			case 34:
				if(CSInputNextBitLE(input)) lengths[i++]=length;
			break;
			case 35:
				val=CSInputNextBitStringLE(input,3)+2;
				while(val--) lengths[i++]=length;
			break;
			case 36:
				val=CSInputNextBitStringLE(input,6)+10;
				while(val--) lengths[i++]=length;
			break;
			default: length=val+1; break;
		}
		lengths[i]=length;
	}

	return [self createTreeWithLengths:lengths numberOfCodes:numcodes];
}

-(XADPrefixTree *)createTreeWithLengths:(const int *)lengths numberOfCodes:(int)numcodes
{
	XADPrefixTree *tree=[XADPrefixTree prefixTree];
	int code=0,codesleft=numcodes;

	for(int length=1;length<32;length++)
	for(int i=0;i<numcodes;i++)
	{
		if(lengths[i]!=length) continue;
		// Instead of reversing to get a low-bit-first code, we shift and use high-bit-first.
		[tree addValue:i forCodeWithHighBitFirst:code>>32-length length:length];
		code+=1<<32-length;
		if(--codesleft==0) return tree; // early exit if all codes have been handled
	}

	return tree;
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length
{
	int val=CSInputNextSymbolFromTreeLE(input,currtree);

	if(val<0x100)
	{
		currtree=firsttree;
		return val;
    }
	else
	{
		currtree=secondtree;

		if(val<0x13e) *length=val-0x100+3;
		else if(val==0x13e) *length=CSInputNextBitStringLE(input,10)+65;
		else if(val==0x13f) *length=CSInputNextBitStringLE(input,15)+65;
		else return XADLZSSEnd;

		int bitlength=CSInputNextSymbolFromTreeLE(input,offsettree);
		if(bitlength==0) *offset=1;
		else if(bitlength==1) *offset=2;
		else *offset=(1<<bitlength-1)+CSInputNextBitStringLE(input,bitlength-1)+1;

		return XADLZSSMatch;
	}
}

@end



static const int FirstTreeLengths_1[321]=
{
	 4, 5, 7, 8, 8, 9, 9, 9, 9, 7, 9, 9, 9, 8, 9, 9,
	 9, 9, 9, 9, 9, 9, 9,10, 9, 9,10,10, 9,10, 9, 9,
	 5, 9, 9, 9, 9,10, 9, 9, 9, 9, 9, 9, 9, 9, 7, 9,
	 9, 8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	 9, 8, 9, 9, 8, 8, 9, 9, 9, 9, 9, 9, 9, 7, 8, 9,
	 7, 9, 9, 7, 7, 9, 9, 9, 9,10, 9,10,10,10, 9, 9,
	 9, 5, 9, 8, 7, 5, 9, 8, 8, 7, 9, 9, 8, 8, 5, 5,
	 7,10, 5, 8, 5, 8, 9, 9, 9, 9, 9,10, 9, 9,10, 9,
	 9,10,10,10,10,10,10,10, 9,10,10,10,10,10,10,10,
	 9,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
	 9,10,10,10,10,10,10,10, 9, 9,10,10,10,10,10,10,
	10,10,10,10,10,10,10,10,10,10, 9,10,10,10,10,10,
	 9,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
	10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
	 9,10,10,10,10,10,10,10,10,10,10,10, 9, 9,10,10,
	 9,10,10,10,10,10,10,10, 9,10,10,10, 9,10, 9, 5,
	 6, 5, 5, 8, 9, 9, 9, 9, 9, 9,10,10,10, 9,10,10,
	10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
	10,10,10, 9,10, 9, 9, 9,10, 9,10, 9,10, 9,10, 9,
	10,10,10, 9,10, 9,10,10, 9, 9, 9, 6, 9, 9,10, 9,
	 5,
};

static const int SecondTreeLengths_1[321]=
{
	 4, 5, 6, 6, 7, 7, 6, 7, 7, 7, 6, 8, 7, 8, 8, 8,
	 8, 9, 6, 9, 8, 9, 8, 9, 9, 9, 8,10, 5, 9, 7, 9,
	 6, 9, 8,10, 9,10, 8, 8, 9, 9, 7, 9, 8, 9, 8, 9,
	 8, 8, 6, 9, 9, 8, 8, 9, 9,10, 8, 9, 9,10, 8,10,
	 8, 8, 8, 8, 8, 9, 7,10, 6, 9, 9,11, 7, 8, 8, 9,
	 8,10, 7, 8, 6, 9,10, 9, 9,10, 8,11, 9,11, 9,10,
	 9, 8, 9, 8, 8, 8, 8,10, 9, 9,10,10, 8, 9, 8, 8,
	 8,11, 9, 8, 8, 9, 9,10, 8,11,10,10, 8,10, 9,10,
	 8, 9, 9,11, 9,11, 9,10,10,11,10,12, 9,12,10,11,
	10,11, 9,10,10,11,10,11,10,11,10,11,10,10,10, 9,
	 9, 9, 8, 7, 6, 8,11,11, 9,12,10,12, 9,11,11,11,
	10,12,11,11,10,12,10,11,10,10,10,11,10,11,11,11,
	 9,12,10,12,11,12,10,11,10,12,11,12,11,12,11,12,
	10,12,11,12,11,11,10,12,10,11,10,12,10,12,10,12,
	10,11,11,11,10,11,11,11,10,12,11,12,10,10,11,11,
	 9,12,11,12,10,11,10,12,10,11,10,12,10,11,10, 7,
	 5, 4, 6, 6, 7, 7, 7, 8, 8, 7, 7, 6, 8, 6, 7, 7,
	 9, 8, 9, 9,10,11,11,11,12,11,10,11,12,11,12,11,
	12,12,12,12,11,12,12,11,12,11,12,11,13,11,12,10,
	13,10,14,14,13,14,15,14,16,15,15,18,18,18, 9,18,
	 8,
};

static const int OffsetTreeLengths_1[11]=
{
	 5, 6, 3, 3, 3, 3, 3, 3, 3, 4, 6,
};

static const int FirstTreeLengths_2[321]=
{
	 4, 7, 7, 8, 7, 8, 8, 8, 8, 7, 8, 7, 8, 7, 9, 8,
	 8, 8, 9, 9, 9, 9,10,10, 9,10,10,10,10,10, 9, 9,
	 5, 9, 8, 9, 9,11,10, 9, 8, 9, 9, 9, 8, 9, 7, 8,
	 8, 8, 9, 9, 9, 9, 9,10, 9, 9, 9,10, 9, 9,10, 9,
	 8, 8, 7, 7, 7, 8, 8, 9, 8, 8, 9, 9, 8, 8, 7, 8,
	 7,10, 8, 7, 7, 9, 9, 9, 9,10,10,11,11,11,10, 9,
	 8, 6, 8, 7, 7, 5, 7, 7, 7, 6, 9, 8, 6, 7, 6, 6,
	 7, 9, 6, 6, 6, 7, 8, 8, 8, 8, 9,10, 9,10, 9, 9,
	 8, 9,10,10, 9,10,10, 9, 9,10,10,10,10,10,10,10,
	 9,10,10,11,10,10,10,10,10,10,10,11,10,11,10,10,
	 9,11,10,10,10,10,10,10, 9, 9,10,11,10,11,10,11,
	10,12,10,11,10,12,11,12,10,12,10,11,10,11,11,11,
	 9,10,11,11,11,12,12,10,10,10,11,11,10,11,10,10,
	 9,11,10,11,10,11,11,11,10,11,11,12,11,11,10,10,
	10,11,10,10,11,11,12,10,10,11,11,12,11,11,10,11,
	 9,12,10,11,11,11,10,11,10,11,10,11, 9,10, 9, 7,
	 3, 5, 6, 6, 7, 7, 8, 8, 8, 9, 9, 9,11,10,10,10,
	12,13,11,12,12,11,13,12,12,11,12,12,13,12,14,13,
	14,13,15,13,14,15,15,14,13,15,15,14,15,14,15,15,
	14,15,13,13,14,15,15,14,14,16,16,15,15,15,12,15,
	10,
};

static const int SecondTreeLengths_2[321]=
{
	 5, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7, 8, 7, 8, 7, 7,
	 7, 8, 8, 8, 8, 9, 8, 9, 8, 9, 9, 9, 7, 9, 8, 8,
	 6, 9, 8, 9, 8, 9, 8, 9, 8, 9, 8, 9, 8, 9, 8, 8,
	 8, 8, 8, 9, 8, 9, 8, 9, 9,10, 8,10, 8, 9, 9, 8,
	 8, 8, 7, 8, 8, 9, 8, 9, 7, 9, 8,10, 8, 9, 8, 9,
	 8, 9, 8, 8, 8, 9, 9, 9, 9,10, 9,11, 9,10, 9,10,
	 8, 8, 8, 9, 8, 8, 8, 9, 9, 8, 9,10, 8, 9, 8, 8,
	 8,11, 8, 7, 8, 9, 9, 9, 9,10, 9,10, 9,10, 9, 8,
	 8, 9, 9,10, 9,10, 9,10, 8,10, 9,10, 9,11,10,11,
	 9,11,10,10,10,11, 9,11, 9,10, 9,11, 9,11,10,10,
	 9,10, 9, 9, 8,10, 9,11, 9, 9, 9,11,10,11, 9,11,
	 9,11, 9,11,10,11,10,11,10,11, 9,10,10,11,10,10,
	 8,10, 9,10,10,11, 9,11, 9,10,10,11, 9,10,10, 9,
	 9,10, 9,10, 9,10, 9,10, 9,11, 9,11,10,10, 9,10,
	 9,11, 9,11, 9,11, 9,10, 9,11, 9,11, 9,11, 9,10,
	 8,11, 9,10, 9,10, 9,10, 8,10, 8, 9, 8, 9, 8, 7,
	 4, 4, 5, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 7, 8, 8,
	 9, 9,10,10,10,10,10,10,11,11,10,10,12,11,11,12,
	12,11,12,12,11,12,12,12,12,12,12,11,12,11,13,12,
	13,12,13,14,14,14,15,13,14,13,14,18,18,17, 7,16,
	 9,
};

static const int OffsetTreeLengths_2[13]=
{
	 5, 6, 4, 4, 3, 3, 3, 3, 3, 4, 4, 4, 6,
};

static const int FirstTreeLengths_3[321]=
{
	 6, 6, 6, 6, 6, 9, 8, 8, 4, 9, 8, 9, 8, 9, 9, 9,
	 8, 9, 9,10, 8,10,10,10, 9,10,10,10, 9,10,10, 9,
	 9, 9, 8,10, 9,10, 9,10, 9,10, 9,10, 9, 9, 8, 9,
	 8, 9, 9, 9,10,10,10,10, 9, 9, 9,10, 9,10, 9, 9,
	 7, 8, 8, 9, 8, 9, 9, 9, 8, 9, 9,10, 9, 9, 8, 9,
	 8, 9, 8, 8, 8, 9, 9, 9, 9, 9,10,10,10,10,10, 9,
	 8, 8, 9, 8, 9, 7, 8, 8, 9, 8,10,10, 8, 9, 8, 8,
	 8,10, 8, 8, 8, 8, 9, 9, 9, 9,10,10,10,10,10, 9,
	 7, 9, 9,10,10,10,10,10, 9,10,10,10,10,10,10, 9,
	 9,10,10,10,10,10,10,10,10, 9,10,10,10,10,10,10,
	 9,10,10,10,10,10,10,10, 9, 9, 9,10,10,10,10,10,
	10,10,10,10,10,10,10,10,10,10, 9,10,10,10,10, 9,
	 8, 9,10,10,10,10,10,10,10,10,10,10, 9,10,10,10,
	 9,10,10,10,10,10,10,10,10,10,10,10,10,10,10, 9,
	 9,10,10,10,10,10,10, 9,10,10,10,10,10,10, 9, 9,
	 9,10,10,10,10,10,10, 9, 9,10, 9, 9, 8, 9, 8, 9,
	 4, 6, 6, 6, 7, 8, 8, 9, 9,10,10,10, 9,10,10,10,
	10,10,10,10,10,10,10,10,10,10,10,10,10,10, 7,10,
	10,10, 7,10,10, 7, 7, 7, 7, 7, 6, 7,10, 7, 7,10,
	 7, 7, 7, 6, 7, 6, 6, 7, 7, 6, 6, 9, 6, 9,10, 6,
	10,
};

static const int SecondTreeLengths_3[321]=
{
	 5, 6, 6, 6, 6, 7, 7, 7, 6, 8, 7, 8, 7, 9, 8, 8,
	 7, 7, 8, 9, 9, 9, 9,10, 8, 9, 9,10, 8,10, 9, 8,
	 6,10, 8,10, 8,10, 9, 9, 9, 9, 9,10, 9, 9, 8, 9,
	 8, 9, 8, 9, 9,10, 9,10, 9, 9, 8,10, 9,11,10, 8,
	 8, 8, 8, 9, 7, 9, 9,10, 8, 9, 8,11, 9,10, 9,10,
	 8, 9, 9, 9, 9, 8, 9, 9,10,10,10,12,10,11,10,10,
	 8, 9, 9, 9, 8, 9, 8, 8,10, 9,10,11, 8,10, 9, 9,
	 8,12, 8, 9, 9, 9, 9, 8, 9,10, 9,12,10,10,10, 8,
	 7,11,10, 9,10,11, 9,11, 7,11,10,12,10,12,10,11,
	 9,11, 9,12,10,12,10,12,10, 9,11,12,10,12,10,11,
	 9,10, 9,10, 9,11,11,12, 9,10, 8,12,11,12, 9,12,
	10,12,10,13,10,12,10,12,10,12,10, 9,10,12,10, 9,
	 8,11,10,12,10,12,10,12,10,11,10,12, 8,12,10,11,
	10,10,10,12, 9,11,10,12,10,12,11,12,10, 9,10,12,
	 9,10,10,12,10,11,10,11,10,12, 8,12, 9,12, 8,12,
	 8,11,10,11,10,11, 9,10, 8,10, 9, 9, 8, 9, 8, 7,
	 4, 3, 5, 5, 6, 5, 6, 6, 7, 7, 8, 8, 8, 7, 7, 7,
	 9, 8, 9, 9,11, 9,11, 9, 8, 9, 9,11,12,11,12,12,
	13,13,12,13,14,13,14,13,14,13,13,13,12,13,13,12,
	13,13,14,14,13,13,14,14,14,14,15,18,17,18, 8,16,
	10,
};

static const int OffsetTreeLengths_3[14]=
{
	 6, 7, 4, 4, 3, 3, 3, 3, 3, 4, 4, 4, 5, 7,
};

static const int FirstTreeLengths_4[321]=
{
	 2, 6, 6, 7, 7, 8, 7, 8, 7, 8, 8, 9, 8, 9, 9, 9,
	 8, 8, 9, 9, 9,10,10, 9, 8,10, 9,10, 9,10, 9, 9,
	 6, 9, 8, 9, 9,10, 9, 9, 9,10, 9, 9, 9, 9, 8, 8,
	 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,10,10, 9,
	 7, 7, 8, 8, 8, 8, 9, 9, 7, 8, 9,10, 8, 8, 7, 8,
	 8,10, 8, 8, 8, 9, 8, 9, 9,10, 9,11,10,11, 9, 9,
	 8, 7, 9, 8, 8, 6, 8, 8, 8, 7,10, 9, 7, 8, 7, 7,
	 8,10, 7, 7, 7, 8, 9, 9, 9, 9,10,11, 9,11,10, 9,
	 7, 9,10,10,10,11,11,10,10,11,10,10,10,11,11,10,
	 9,10,10,11,10,11,10,11,10,10,10,11,10,11,10,10,
	 9,10,10,11,10,10,10,10, 9,10,10,10,10,11,10,11,
	10,11,10,11,11,11,10,12,10,11,10,11,10,11,11,10,
	 8,10,10,11,10,11,11,11,10,11,10,11,10,11,11,11,
	 9,10,11,11,10,11,11,11,10,11,11,11,10,10,10,10,
	10,11,10,10,11,11,10,10, 9,11,10,10,11,11,10,10,
	10,11,10,10,10,10,10,10, 9,11,10,10, 8,10, 8, 6,
	 5, 6, 6, 7, 7, 8, 8, 8, 9,10,11,10,10,11,11,12,
	12,10,11,12,12,12,12,13,13,13,13,13,12,13,13,15,
	14,12,14,15,16,12,12,13,15,14,16,15,17,18,15,17,
	16,15,15,15,15,13,13,10,14,12,13,17,17,18,10,17,
	 4,
};

static const int SecondTreeLengths_4[321]=
{
	 4, 5, 6, 6, 6, 6, 7, 7, 6, 7, 7, 9, 6, 8, 8, 7,
	 7, 8, 8, 8, 6, 9, 8, 8, 7, 9, 8, 9, 8, 9, 8, 9,
	 6, 9, 8, 9, 8,10, 9, 9, 8,10, 8,10, 8, 9, 8, 9,
	 8, 8, 7, 9, 9, 9, 9, 9, 8,10, 9,10, 9,10, 9, 8,
	 7, 8, 9, 9, 8, 9, 9, 9, 7,10, 9,10, 9, 9, 8, 9,
	 8, 9, 8, 8, 8, 9, 9,10, 9, 9, 8,11, 9,11,10,10,
	 8, 8,10, 8, 8, 9, 9, 9,10, 9,10,11, 9, 9, 9, 9,
	 8, 9, 8, 8, 8,10,10, 9, 9, 8,10,11,10,11,11, 9,
	 8, 9,10,11, 9,10,11,11, 9,12,10,10,10,12,11,11,
	 9,11,11,12, 9,11, 9,10,10,10,10,12, 9,11,10,11,
	 9,11,11,11,10,11,11,12, 9,10,10,12,11,11,10,11,
	 9,11,10,11,10,11, 9,11,11, 9, 8,11,10,11,11,10,
	 7,12,11,11,11,11,11,12,10,12,11,13,11,10,12,11,
	10,11,10,11,10,11,11,11,10,12,11,11,10,11,10,10,
	10,11,10,12,11,12,10,11, 9,11,10,11,10,11,10,12,
	 9,11,11,11, 9,11,10,10, 9,11,10,10, 9,10, 9, 7,
	 4, 5, 5, 5, 6, 6, 7, 6, 8, 7, 8, 9, 9, 7, 8, 8,
	10, 9,10,10,12,10,11,11,11,11,10,11,12,11,11,11,
	11,11,13,12,11,12,13,12,12,12,13,11, 9,12,13, 7,
	13,11,13,11,10,11,13,15,15,12,14,15,15,15, 6,15,
	 5,
};

static const int OffsetTreeLengths_4[11]=
{
	 3, 6, 5, 4, 2, 3, 3, 3, 4, 4, 6,
};

static const int FirstTreeLengths_5[321]=
{
	 7, 9, 9, 9, 9, 9, 9, 9, 9, 8, 9, 9, 9, 7, 9, 9,
	 9, 9, 9, 9, 9, 9, 9,10, 9,10, 9,10, 9,10, 9, 9,
	 5, 9, 7, 9, 9, 9, 9, 9, 7, 7, 7, 9, 7, 7, 8, 7,
	 8, 8, 7, 7, 9, 9, 9, 9, 7, 7, 7, 9, 9, 9, 9, 9,
	 9, 7, 9, 7, 7, 7, 7, 9, 9, 7, 9, 9, 7, 7, 7, 7,
	 7, 9, 7, 8, 7, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	 9, 7, 8, 7, 7, 7, 8, 8, 6, 7, 9, 7, 7, 8, 7, 5,
	 6, 9, 5, 7, 5, 6, 7, 7, 9, 8, 9, 9, 9, 9, 9, 9,
	 9, 9,10, 9,10,10,10, 9, 9,10,10,10,10,10,10,10,
	 9,10,10,10,10,10,10,10,10,10,10,10, 9,10,10,10,
	 9,10,10,10, 9, 9,10, 9, 9, 9, 9,10,10,10,10,10,
	10,10,10,10,10,10, 9,10,10,10,10,10,10,10,10,10,
	 9,10,10,10, 9,10,10,10, 9, 9, 9,10,10,10,10,10,
	 9,10, 9,10,10, 9,10,10, 9,10,10,10,10,10,10,10,
	 9,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
	 9,10,10,10,10,10,10,10, 9,10, 9,10, 9,10,10, 9,
	 5, 6, 8, 8, 7, 7, 7, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	 9,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
	10,10,10,10,10,10,10,10, 9,10,10, 5,10, 8, 9, 8,
	 9,
};

static const int SecondTreeLengths_5[321]=
{
	 8,10,11,11,11,12,11,11,12, 6,11,12,10, 5,12,12,
	12,12,12,12,12,13,13,14,13,13,12,13,12,13,12,15,
	 4,10, 7, 9,11,11,10, 9, 6, 7, 8, 9, 6, 7, 6, 7,
	 8, 7, 7, 8, 8, 8, 8, 8, 8, 9, 8, 7,10, 9,10,10,
	11, 7, 8, 6, 7, 8, 8, 9, 8, 7,10,10, 8, 7, 8, 8,
	 7,10, 7, 6, 7, 9, 9, 8,11,11,11,10,11,11,11, 8,
	11, 6, 7, 6, 6, 6, 6, 8, 7, 6,10, 9, 6, 7, 6, 6,
	 7,10, 6, 5, 6, 7, 7, 7,10, 8,11, 9,13, 7,14,16,
	12,14,14,15,15,16,16,14,15,15,15,15,15,15,15,15,
	14,15,13,14,14,16,15,17,14,17,15,17,12,14,13,16,
	12,17,13,17,14,13,13,14,14,12,13,15,15,14,15,17,
	14,17,15,14,15,16,12,16,15,14,15,16,15,16,17,17,
	15,15,17,17,13,14,15,15,13,12,16,16,17,14,15,16,
	15,15,13,13,15,13,16,17,15,17,17,17,16,17,14,17,
	14,16,15,17,15,15,14,17,15,17,15,16,15,15,16,16,
	14,17,17,15,15,16,15,17,15,14,16,16,16,16,16,12,
	 4, 4, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8, 8, 9, 9,
	 9, 9, 9,10,10,10,11,10,11,11,11,11,11,12,12,12,
	13,13,12,13,12,14,14,12,13,13,13,13,14,12,13,13,
	14,14,14,13,14,14,15,15,13,15,13,17,17,17, 9,17,
	 7,
};

static const int OffsetTreeLengths_5[11]=
{
	 6, 7, 7, 6, 4, 3, 2, 2, 3, 3, 6,
};

static const int *FirstTreeLengths[5]=
{
	FirstTreeLengths_1,FirstTreeLengths_2,FirstTreeLengths_3,FirstTreeLengths_4,FirstTreeLengths_5
};

static const int *SecondTreeLengths[5]=
{
	SecondTreeLengths_1,SecondTreeLengths_2,SecondTreeLengths_3,SecondTreeLengths_4,SecondTreeLengths_5
};

static const int *OffsetTreeLengths[5]=
{
	OffsetTreeLengths_1,OffsetTreeLengths_2,OffsetTreeLengths_3,OffsetTreeLengths_4,OffsetTreeLengths_5
};

static const int OffsetTreeSize[5]={11,13,14,11,11};

static const int MetaCodes[37]=
{
	0x5d8,0x058,0x040,0x0c0,0x000,0x078,0x02b,0x014,
	0x00c,0x01c,0x01b,0x00b,0x010,0x020,0x038,0x018,
	0x0d8,0xbd8,0x180,0x680,0x380,0xf80,0x780,0x480,
	0x080,0x280,0x3d8,0xfd8,0x7d8,0x9d8,0x1d8,0x004,
	0x001,0x002,0x007,0x003,0x008
};

static const int MetaCodeLengths[37]=
{
	11,8,8,8,8,7,6,5,5,5,5,6,5,6,7,7,9,12,10,11,11,12,
	12,11,11,11,12,12,12,12,12,5,2,2,3,4,5
};
