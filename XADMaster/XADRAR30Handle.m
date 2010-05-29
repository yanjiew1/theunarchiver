#import "XADRAR30Handle.h"
#import "XADException.h"

@implementation XADRAR30Handle

-(id)initWithRARParser:(XADRARParser *)parent version:(int)version parts:(NSArray *)partarray
{
	if(self=[super initWithRARParser:parent version:version parts:partarray windowSize:0x400000])
	{
		maincode=nil;
		offsetcode=nil;
		lowoffsetcode=nil;
		lengthcode=nil;
		alloc=NULL;
		filtercode=nil;
		stack=nil;
	}
	return self;
}

-(void)dealloc
{
	[maincode release];
	[offsetcode release];
	[lowoffsetcode release];
	[lengthcode release];
	FreeSubAllocatorVariantH(alloc);
	[filtercode release];
	[stack release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	[super resetLZSSHandle];

	memset(lengthtable,0,sizeof(lengthtable));

	lastoffset=0;
	lastlength=0;
	memset(oldoffset,0,sizeof(oldoffset));

	ppmescape=2;

	[filtercode removeAllObjects];
	[stack removeAllObjects];
	lastfilternum=0;

	[self allocAndParseCodes];
}

-(void)expandFromPosition:(off_t)pos
{
	static const int lengthbases[28]={0,1,2,3,4,5,6,7,8,10,12,14,16,20,24,28,32,
	40,48,56,64,80,96,112,128,160,192,224};
	static const int lengthbits[28]={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5};
	static const int offsetbases[60]={0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,512,
	768,1024,1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152,65536,98304,
	131072,196608,262144,327680,393216,458752,524288,589824,655360,720896,786432,
	851968,917504,983040,1048576,1310720,1572864,1835008,2097152,2359296,2621440,
	2883584,3145728,3407872,3670016,3932160};
	static unsigned char offsetbits[60]={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,
	11,11,12,12,13,13,14,14,15,15,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
	18,18,18,18,18,18,18,18,18,18,18,18};
	static unsigned int shortbases[8]={0,4,8,16,32,64,128,192};
	static unsigned int shortbits[8]={2,2,3,4,5,6,6,6};

	while(XADLZSSShouldKeepExpandingWithBarrier(self))
	{
		while(pos>=filterend)
		{
			XADRAR30Filter *firstfilter=[stack objectAtIndex:0];

			XADLZSSCopyBytesFromWindow(self,[vm memory],[firstfilter startPosition],[firstfilter length]);
			[firstfilter executeOnVirtualMachine:vm atPosition:
		}

		if(ppmblock)
		{
			int byte=NextPPMdVariantHByte(&ppmd);
			if(byte<0) [XADException raiseInputException]; // TODO: better error;

			if(byte!=ppmescape)
			{
				XADLZSSLiteral(self,byte,&pos);
			}
			else
			{
				int code=NextPPMdVariantHByte(&ppmd);

				switch(code)
				{
					case 0:
						[self allocAndParseCodes];
					break;

					case -1:
					case 2:
						[XADException raiseInputException]; // TODO: better error;
					break;

					case 3:
						[self readFilterFromPPMdAtPosition:pos];
					break;

					case 4:
					{
						// TODO: check for error
						int offs=NextPPMdVariantHByte(&ppmd)<<16;
						offs|=NextPPMdVariantHByte(&ppmd)<<8;
						offs|=NextPPMdVariantHByte(&ppmd);

						int len=NextPPMdVariantHByte(&ppmd);

						XADLZSSMatch(self,offs+2,len+32,&pos);
					}
					break;

					case 5:
					{
						int len=NextPPMdVariantHByte(&ppmd);
						XADLZSSMatch(self,1,len+4,&pos);
					}

					default:
						XADLZSSLiteral(self,byte,&pos);
					break;
				}
			}
		}
		else
		{
			int symbol=CSInputNextSymbolUsingCode(input,maincode);
			int offs,len;

			if(symbol<256)
			{
				XADLZSSLiteral(self,symbol,&pos);
				continue;
			}
			else if(symbol==256)
			{
				BOOL newfile=!CSInputNextBit(input);

				if(newfile)
				{
					BOOL newtable=CSInputNextBit(input);
					[self startNextPart];
					if(newtable) [self allocAndParseCodes];
				}
				else
				{
					[self allocAndParseCodes];
				}
				continue;
			}
			else if(symbol==257)
			{
				[self readFilterFromInputAtPosition:pos];
				continue;
			}
			else if(symbol==258)
			{
				if(lastlength==0) continue;

	  			offs=lastoffset;
				len=lastlength;
			}
			else if(symbol<=262)
			{
				int offsindex=symbol-259;
				offs=oldoffset[offsindex];

				int lensymbol=CSInputNextSymbolUsingCode(input,lengthcode);
				len=lengthbases[lensymbol]+2;
				if(lengthbits[lensymbol]>0) len+=CSInputNextBitString(input,lengthbits[lensymbol]);

				for(int i=offsindex;i>0;i--) oldoffset[i]=oldoffset[i-1];
				oldoffset[0]=offs;
			}
			else if(symbol<=270)
			{
				offs=shortbases[symbol-263]+1;
				if(shortbits[symbol-263]>0) offs+=CSInputNextBitString(input,shortbits[symbol-263]);

				len=2;

				for(int i=3;i>0;i--) oldoffset[i]=oldoffset[i-1];
				oldoffset[0]=offs;
			}
			else //if(code>=271)
			{
				len=lengthbases[symbol-271]+3;
				if(lengthbits[symbol-271]>0) len+=CSInputNextBitString(input,lengthbits[symbol-271]);

				int offssymbol=CSInputNextSymbolUsingCode(input,offsetcode);
				offs=offsetbases[offssymbol]+1;
				if(offsetbits[offssymbol]>0)
				{
					if(offssymbol>9)
					{
						if(offsetbits[offssymbol]>4)
						offs+=CSInputNextBitString(input,offsetbits[offssymbol]-4)<<4;

						if(numlowoffsetrepeats>0)
						{
							numlowoffsetrepeats--;
							offs+=lastlowoffset;
						}
						else
						{
							int lowoffsetsymbol=CSInputNextSymbolUsingCode(input,lowoffsetcode);
							if(lowoffsetsymbol==16)
							{
								numlowoffsetrepeats=15;
								offs+=lastlowoffset;
							}
							else
							{
								offs+=lowoffsetsymbol;
								lastlowoffset=lowoffsetsymbol;
							}
						}
					}
					else
					{
						offs+=CSInputNextBitString(input,offsetbits[offssymbol]);
					}
				}

				if(offs>=0x40000) len++;
				if(offs>=0x2000) len++;

				for(int i=3;i>0;i--) oldoffset[i]=oldoffset[i-1];
				oldoffset[0]=offs;
			}

			lastoffset=offs;
			lastlength=len;

			XADLZSSMatch(self,offs,len,&pos);
		}
	}
}

-(void)allocAndParseCodes
{
	[maincode release]; maincode=nil;
	[offsetcode release]; offsetcode=nil;
	[lowoffsetcode release]; lowoffsetcode=nil;
	[lengthcode release]; lengthcode=nil;

	CSInputSkipToByteBoundary(input);

	ppmblock=CSInputNextBit(input);

	if(ppmblock)
	{
		int flags=CSInputNextByte(input);

		int maxalloc;
		if(flags&0x20) maxalloc=CSInputNextByte(input);
		//else check if memory allocated at all else die

		if(flags&0x40) ppmescape=CSInputNextByte(input);

		if(flags&0x20)
		{
			int maxorder=(flags&0x1f)+1;
			if(maxorder>16) maxorder=16+(maxorder-16)*3;

			// Check for end of file marker. TODO: better error
			if(maxorder==1) [XADException raiseInputException];

			FreeSubAllocatorVariantH(alloc);
			alloc=CreateSubAllocatorVariantH((maxalloc+1)<<20);

			StartPPMdModelVariantH(&ppmd,input,alloc,maxorder,NO);
		}
		else RestartPPMdVariantHRangeCoder(&ppmd,input,NO);

		return;
	}

	lastlowoffset=0;
	numlowoffsetrepeats=0;

	if(CSInputNextBit(input)==0) memset(lengthtable,0,sizeof(lengthtable));

	XADPrefixCode *precode=nil;
	@try
	{
		int prelengths[20];
		for(int i=0;i<20;)
		{
			int length=CSInputNextBitString(input,4);
			if(length==15)
			{
				int count=CSInputNextBitString(input,4)+2;

				if(count==2) prelengths[i++]=15;
				else for(int j=0;j<count && i<20;j++) prelengths[i++]=0;
			}
			else prelengths[i++]=length;
		}

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:YES];

		for(int i=0;i<299+60+17+28;)
		{
			int val=CSInputNextSymbolUsingCode(input,precode);
			if(val<16)
			{
				lengthtable[i]=(lengthtable[i]+val)&0x0f;
				i++;
			}
			else if(val<18)
			{
				if(i==0) [XADException raiseDecrunchException];

				int n;
				if(val==16) n=CSInputNextBitString(input,3)+3;
				else n=CSInputNextBitString(input,7)+11;

				for(int j=0;j<n && i<299+60+17+28;j++)
				{
					lengthtable[i]=lengthtable[i-1];
					i++;
				}
			}
			else //if(val<20)
			{
				int n;
				if(val==18) n=CSInputNextBitString(input,3)+3;
				else n=CSInputNextBitString(input,7)+11;

				for(int j=0;j<n && i<299+60+17+28;j++) lengthtable[i++]=0;
			}
		}

		[precode release];
	}
	@catch(id e)
	{
		[precode release];
		@throw;
	}

	maincode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[0]
	numberOfSymbols:299 maximumLength:15 shortestCodeIsZeros:YES];

	offsetcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[299]
	numberOfSymbols:60 maximumLength:15 shortestCodeIsZeros:YES];

	lowoffsetcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[299+60]
	numberOfSymbols:17 maximumLength:15 shortestCodeIsZeros:YES];

	lengthcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[299+60+17]
	numberOfSymbols:28 maximumLength:15 shortestCodeIsZeros:YES];
}



-(void)readFilterFromInputAtPosition:(off_t)pos
{
	int flags=CSInputNextBitString(input,8);

	int length=(flags&7)+1;
	if(length==7) length=CSInputNextBitString(input,8)+7;
	else if(length==8) length=CSInputNextBitString(input,16);

	uint8_t code[length];
	for(int i=0;i<length;i++) code[i]=CSInputNextBitString(input,8);

	[self parseFilter:code length:length flags:flags position:pos];
}

-(void)readFilterFromPPMdAtPosition:(off_t)pos
{
	[XADException raiseNotSupportedException];
}

-(void)parseFilter:(const uint8_t *)bytes length:(int)length flags:(int)flags position:(off_t)pos
{
	// TODO: deal with memory leaks from exceptions

	if(!filtercode) filtercode=[NSMutableArray new];
	if(!stack) stack=[NSMutableArray new];

	CSInputBuffer *filterinput=CSInputBufferAllocWithBuffer(bytes,length,0);
	int numcodes=[filtercode count];

	int num;
	BOOL isnew=NO;

	// Read filter number
	if(flags&0x80)
	{
		num=CSInputNextRARVMNumber(filterinput)-1;

		if(num==-1)
		{
			num=0;
			[filtercode removeAllObjects];
			[stack removeAllObjects];
		}

		if(num>numcodes||num<0||num>1024) [XADException raiseIllegalDataException];
		if(num==numcodes)
		{
			isnew=YES;
			oldfilterlength[num]=0;
			usagecount[num]=-1;
		}

		lastfilternum=num;
	}
	else num=lastfilternum;

	usagecount[num]++;

	// Read filter range
	uint32_t blockstart=CSInputNextRARVMNumber(filterinput);
	if(flags&0x40) blockstart+=258;

	uint32_t blocklength;
	if(flags&0x20) blocklength=oldfilterlength[num]=CSInputNextRARVMNumber(filterinput);
	else blocklength=oldfilterlength[num];

	// Convert filter range from window position to stream position
	off_t blockstartpos=(pos&~(off_t)windowmask)+blockstartpos;
	if(blockstartpos<pos) pos+=windowmask+1;

	// Enforce ordering of filters. Filters have to be defined in order of position,
	// and either exactly overlapping the previous, or not overlapping at all.
	// RAR code does not do this, but would break if it does not hold.
	if([stack count])
	{
		XADRAR30Filter *prev=[stack lastObject];
		off_t prevstartpos=[prev startPosition];
		int prevlength=[prev length];

		if(blockstartpos!=prevstartpos || blocklength!=prevlength) // Not exact overlap?
		if(blockstartpos<prevstartpos+prevlength) // Not strictly following?
		[XADException raiseIllegalDataException];
	}

	uint32_t registers[8]={
		[3]=XADRARProgramGlobalAddress,[4]=blocklength,
		[5]=usagecount[num],[7]=XADRARProgramMemorySize
	};

	// Read register override values
	if(flags&0x10)
	{
		int mask=CSInputNextBitString(filterinput,7);
		for(int i=0;i<7;i++) if(mask&(1<<i)) registers[i]=CSInputNextRARVMNumber(filterinput);
	}

	// Read bytecode or look up old version.
	XADRARProgramCode *code;
	if(isnew)
	{
		int length=CSInputNextRARVMNumber(filterinput);
		if(length==0||length>0x10000) [XADException raiseIllegalDataException];

		uint8_t bytecode[length];
		for(int i=0;i<length;i++) bytecode[i]=CSInputNextBitString(filterinput,8);

		code=[[[XADRARProgramCode alloc] initWithByteCode:bytecode length:length] autorelease];
		[filtercode addObject:code];
	}
	else
	{
		code=[filtercode objectAtIndex:num];
	}
  
	// Read data section.
	NSMutableData *data=nil;
	if(flags&8)
	{
		int length=CSInputNextRARVMNumber(filterinput);

		if(length>XADRARProgramUserGlobalSize) [XADException raiseIllegalDataException];

		data=[NSMutableData dataWithLength:length+XADRARProgramSystemGlobalSize];
		uint8_t *databytes=[data mutableBytes];

		for(int i=0;i<length;i++) databytes[i+XADRARProgramSystemGlobalSize]=CSInputNextBitString(filterinput,8);
	}

	// Create an invocation and set register and memory parameters.
	XADRARProgramInvocation *invocation=[[[XADRARProgramInvocation alloc]
	initWithProgramCode:code globalData:data registers:registers] autorelease];

	for(int i=0;i<7;i++) [invocation setGlobalValueAtOffset:i*4 toValue:registers[i]];
	[invocation setGlobalValueAtOffset:0x1c toValue:blocklength];
	[invocation setGlobalValueAtOffset:0x20 toValue:0];
	[invocation setGlobalValueAtOffset:0x2c toValue:usagecount[num]];

	// Create a filter object and add it to the stack.
	XADRAR30Filter *filter=[[[XADRAR30Filter alloc] initWithProgramInvocation:invocation
	startPosition:blockstart length:length] autorelease];
	[stack addObject:filter];

	// If this is the first filter added to an empty stack, (re-)enable the write barrier and set end marker.
	if([stack count]==1)
	{
		XADLZSSSetWriteBarrier(self,blockstart);
		filterend=blockstart+blocklength;
	}

	CSInputBufferFree(filterinput);
}


@end



@implementation XADRAR30Filter

-(id)initWithProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)blockstart length:(int)blocklength
{
	if(self=[super init])
	{
		invocation=[program retain];
		startpos=blockstart;
		length=blocklength;
	}
	return self;
}

-(void)dealloc
{
	[invocation release];
	[super dealloc];
}

-(off_t)startPosition { return startpos; }

-(int)length { return length; }

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	[invocation restoreGlobalDataIfAvailable]; // This is silly, but RAR does it.

	[invocation setRegister:6 toValue:(uint32_t)pos];
	[invocation setGlobalValueAtOffset:0x24 toValue:(uint32_t)pos];
	[invocation setGlobalValueAtOffset:0x28 toValue:(uint32_t)(pos>>32)];

	[invocation executeOnVitualMachine:vm];

/*	filteredblockaddress=XADRARVirtualMachineRead32(XADRARProgramGlobalAddress+0x20)&XADRARProgramMemoryMask;
	filteredblocklength=XADRARVirtualMachineRead32(XADRARProgramGlobalAddress+0x1c)&XADRARProgramMemoryMask;

	if(filteredblockaddress+filteredblocklength>=XADRARProgramMemorySize) filteredblockaddress=filteredblocklength=0;
*/
	[invocation backupGlobalData]; // Also silly.
}

@end
