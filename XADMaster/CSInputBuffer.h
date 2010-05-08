#import <Foundation/Foundation.h>
#import "CSHandle.h"

typedef struct CSInputBuffer
{
	CSHandle *parent;
	off_t startoffs;
	BOOL eof;

	uint8_t *buffer;
	int bufsize,bufbytes,currbyte,currbit;
} CSInputBuffer;

CSInputBuffer *CSInputBufferAlloc(CSHandle *parent,int size);
CSInputBuffer *CSInputBufferAllocWithBuffer(uint8_t *buffer,int length,off_t startoffs);
CSInputBuffer *CSInputBufferAllocEmpty();
void CSInputBufferFree(CSInputBuffer *buf);

void CSInputSetMemoryBuffer(CSInputBuffer *buf,uint8_t *buffer,int length,off_t startoffs);

void CSInputRestart(CSInputBuffer *buf);
void CSInputFlush(CSInputBuffer *buf);
void CSInputSynchronizeFileOffset(CSInputBuffer *buf);
void CSInputSeekToFileOffset(CSInputBuffer *buf,off_t offset);
void CSInputSeekToBufferOffset(CSInputBuffer *buf,off_t offset);
void CSInputSetStartOffset(CSInputBuffer *buf,off_t offset);

off_t CSInputBufferOffset(CSInputBuffer *buf);
off_t CSInputFileOffset(CSInputBuffer *buf);

void _CSInputFillBuffer(CSInputBuffer *buf);

void CSInputSkipBits(CSInputBuffer *buf,int bits);
BOOL CSInputOnByteBoundary(CSInputBuffer *buf);
void CSInputSkipToByteBoundary(CSInputBuffer *buf);
void CSInputSkipTo16BitBoundary(CSInputBuffer *buf);

int CSInputNextBit(CSInputBuffer *buf);
int CSInputNextBitLE(CSInputBuffer *buf);
unsigned int CSInputNextBitString(CSInputBuffer *buf,int bits);
unsigned int CSInputNextBitStringLE(CSInputBuffer *buf,int bits);
unsigned int CSInputPeekBitString(CSInputBuffer *buf,int bits);
unsigned int CSInputPeekBitStringLE(CSInputBuffer *buf,int bits);

#define CSInputBufferLookAhead 4

static inline void _CSInputBufferRaiseEOF(CSInputBuffer *buf)
{
	[buf->parent _raiseEOF];
}

static inline int _CSInputBytesLeftInBuffer(CSInputBuffer *buf)
{
	return buf->bufbytes-buf->currbyte;
}

static inline void _CSInputCheckAndFillBuffer(CSInputBuffer *buf)
{
	if(!buf->eof&&_CSInputBytesLeftInBuffer(buf)<=CSInputBufferLookAhead) _CSInputFillBuffer(buf);
}

static inline void CSInputSkipBytes(CSInputBuffer *buf,int num) { buf->currbyte+=num; }

static inline int CSInputPeekByte(CSInputBuffer *buf,int offs)
{
	if(offs>=_CSInputBytesLeftInBuffer(buf)) _CSInputBufferRaiseEOF(buf);

	return buf->buffer[buf->currbyte+offs];
}

static inline int CSInputNextByte(CSInputBuffer *buf)
{
	_CSInputCheckAndFillBuffer(buf);
	int byte=CSInputPeekByte(buf,0);
	CSInputSkipBytes(buf,1);
	return byte;
}

static inline BOOL CSInputAtEOF(CSInputBuffer *buf)
{
	_CSInputCheckAndFillBuffer(buf);
	return buf->currbyte>=buf->bufbytes;
}

static inline int CSInputBitsLeftInBuffer(CSInputBuffer *buf)
{
	_CSInputCheckAndFillBuffer(buf);
	return _CSInputBytesLeftInBuffer(buf)*8-buf->currbit;
}

#define CSInputNextValueImpl(type,name,conv) \
static inline type name(CSInputBuffer *buf) \
{ \
	_CSInputCheckAndFillBuffer(buf); \
	type val=conv(buf->buffer+buf->currbyte); \
	CSInputSkipBytes(buf,sizeof(type)); \
	return val; \
}

CSInputNextValueImpl(int16_t,CSInputNextInt16LE,CSInt16LE)
CSInputNextValueImpl(int32_t,CSInputNextInt32LE,CSInt32LE)
CSInputNextValueImpl(uint16_t,CSInputNextUInt16LE,CSUInt16LE)
CSInputNextValueImpl(uint32_t,CSInputNextUInt32LE,CSUInt32LE)
CSInputNextValueImpl(int16_t,CSInputNextInt16BE,CSInt16BE)
CSInputNextValueImpl(int32_t,CSInputNextInt32BE,CSInt32BE)
CSInputNextValueImpl(uint16_t,CSInputNextUInt16BE,CSUInt16BE)
CSInputNextValueImpl(uint32_t,CSInputNextUInt32BE,CSUInt32BE)




