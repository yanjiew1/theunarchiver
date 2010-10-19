#import "XADARCHandles.h"
#import "XADException.h"

@implementation XADARCSqueezeHandle

// TODO: decode tree to a XADPrefixCode for speed.

-(void)resetByteStream
{
	int numnodes=CSInputNextUInt16LE(input)*2;

	if(numnodes>=257*2) [XADException raiseDecrunchException];

	nodes[0]=nodes[1]=-(256+1);

	for(int i=0;i<numnodes;i++) nodes[i]=CSInputNextInt16LE(input);
	//if(nodes[i]>) [XADException raiseDecrunchException];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int val=0;
	while(val>=0)
	{
		if(!CSInputBitsLeftInBuffer(input)) CSByteStreamEOF(self);
		val=nodes[2*val+CSInputNextBitLE(input)];
	}

	int output=-(val+1);

	if(output==256) CSByteStreamEOF(self);

	return output;
}

@end






@implementation XADARCCrunchHandle

-(id)initWithHandle:(CSHandle *)handle useFastHash:(BOOL)usefast
{
	return [self initWithHandle:handle length:CSHandleMaxLength useFastHash:usefast];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length useFastHash:(BOOL)usefast
{
	if(self=[super initWithHandle:handle length:length])
	{
		fast=usefast;
	}
	return self;
}


-(void)resetByteStream
{
    sp=0;
    numfreecodes=4096-256;

	for(int i=0;i<256;i++) [self updateTableWithParent:-1 byteValue:i];

	int code=CSInputNextBitString(input,12);
	int byte=table[code].byte;

	stack[sp++]=byte;

	lastcode=code;
	lastbyte=byte;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!sp)
	{
		if(CSInputAtEOF(input)) CSByteStreamEOF(self);

		int code=CSInputNextBitString(input,12);

		XADARCCrunchEntry *entry=&table[code];

		if(!entry->used)
		{
			entry=&table[lastcode];
			stack[sp++]=lastbyte;
		}

		while(entry->parent!=-1)
		{
			if(sp>=4095) [XADException raiseDecrunchException];

			stack[sp++]=entry->byte;
			entry=&table[entry->parent];
		}

		uint8_t byte=entry->byte;
		stack[sp++]=byte;

		if(numfreecodes!=0)
		{
			[self updateTableWithParent:lastcode byteValue:byte];
			numfreecodes--;
		}

		lastcode=code;
		lastbyte=byte;
	}

	return stack[--sp];
}

-(void)updateTableWithParent:(int)parent byteValue:(int)byte
{
	// Find hash table position.
	int index;
	if(fast) index=(((parent+byte)&0xffff)*15073)&0xfff;
	else
	{
		index=((parent+byte)|0x0800)&0xffff;
		index=(index*index>>6)&0xfff;
	}

	if(table[index].used) // Check for collision.
	{
		// Go through the list of already marked collisions.
		while(table[index].next) index=table[index].next;

		// Then skip ahead, and do a linear search for an unused index.
		int next=(index+101)&0xfff;
		while(table[next].used) next=(next+1)&0xfff;

		// Save the new index so we can skip the process next time.
		table[index].next=next;

		index=next;
	}

	table[index].used=YES;
	table[index].next=0;
	table[index].parent=parent;
	table[index].byte=byte;
}

@end




@implementation XADARCCrushHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
        if(self=[super initWithHandle:handle length:length])
        {
                lzw=AllocLZW(8192,1);
        }
        return self;
}

-(void)dealloc
{
        FreeLZW(lzw);
        [super dealloc];
}

-(void)resetByteStream
{
	ClearLZWTable(lzw);
	symbolsize=1;
	nextsizebump=2;
	useliteralbit=YES;

	numrecentstrings=0;
	ringindex=0;
	memset(stringring,0,sizeof(stringring));

	currbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		int symbol;

//NSLog(@"usebit: %d size: %d numcodes: %d nextbump: %d",useliteralbit,symbolsize,LZWSymbolCount(lzw),nextsizebump);

		if(useliteralbit)
		{
			if(CSInputNextBitLE(input)) symbol=CSInputNextBitStringLE(input,symbolsize)+256;
			else symbol=CSInputNextBitStringLE(input,8);
		}
		else
		{
			symbol=CSInputNextBitStringLE(input,symbolsize);
			if(symbol<0x100) symbol^=0xff;
		}
//NSLog(@"symbol: %02x",symbol);

		if(symbol==0x100) CSByteStreamEOF(self);

		if(stringring[ringindex]) numrecentstrings--;

		if(symbol<0x100)
		{
			stringring[ringindex]=NO;
		}
		else
		{
			stringring[ringindex]=YES;
			numrecentstrings++;
		}

		ringindex=(ringindex+1)%500;

		BOOL manyliterals=numrecentstrings<375;
		if(manyliterals!=useliteralbit)
		{
			useliteralbit=manyliterals;
			nextsizebump=1<<symbolsize;
			if(!useliteralbit) nextsizebump-=0x100;
		}

		if(NextLZWSymbol(lzw,symbol)==LZWInvalidCodeError) [XADException raiseDecrunchException];
		currbyte=LZWReverseOutputToBuffer(lzw,buffer);

		if(LZWSymbolCount(lzw)-257>=nextsizebump)
		{
			symbolsize++;
			nextsizebump=1<<symbolsize;
			if(!useliteralbit) nextsizebump-=0x100;
		}
	}

	return buffer[--currbyte];
}
@end


