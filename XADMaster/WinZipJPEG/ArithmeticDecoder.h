#ifndef __WINZIP_JPEG_ARITHMETIC_DECODER_H__
#define __WINZIP_JPEG_ARITHMETIC_DECODER_H__

#include "InputStream.h"

typedef struct WinZipJPEGArithmeticDecoder
{
	WinZipJPEGReadFunction *readfunc;
	void *inputcontext;

	uint32_t i,bl,p;

	uint8_t b,b0;

	uint8_t mps; // most probable symbol value - 0 or 1
	uint8_t yn; // symbol to be coded
	uint8_t k; // least probable symbol count
	uint8_t kmin2; // LPS count for reduction of Q by 4
	uint8_t kmin1; // LPS count for reduction of Q by 2
	uint8_t kmin; // largest LSP[sic] count for smaller Q
	//uint8_t kavg; // expected average LPS count
	uint8_t kmax; // smallest LPS count for larger Q
	uint32_t x; // finite pricesion window on code stream
	int16_t lp; // minus log p
	int16_t lr; // minus log of the range
	int32_t dlrm; // difference between lrm and lr
	int16_t lrm; // maximum lr before change index
	int16_t lrt; // decoder - minimum of lrm and lx
	int16_t lx; // decoder - log x
	uint32_t mr; // mantissa of range for calculating antilog
	uint32_t dx; // antilog of lr
	uint32_t ct; // decoder - number of bits to shift for logx
	uint32_t cx; // decoder - characteristic of x
	uint32_t xf; // fractional part of x

	uint16_t incrsv; // save extra increments at MPS exchange

	// statistics based on s (old state initially)
	uint32_t s; // pointer to statistics for this state (???)
	uint32_t ist[256]; // index into probtbl (base s) (???)
	uint16_t dlrst[256]; // lrm-lr+lp (base s)
	uint8_t mpsst[256]; // most probably symbol (base s)
	uint8_t kst[256]; // lps count (base s)

	uint32_t ns; //  (???)

} WinZipJPEGArithmeticDecoder;

void InitializeWinZipJPEGArithmeticDecoder(WinZipJPEGArithmeticDecoder *self,WinZipJPEGReadFunction *readfunc, void *inputcontext);
int NextBitFromWinZipJPEGArithmeticDecoder(WinZipJPEGArithmeticDecoder *self,int state);

#endif

