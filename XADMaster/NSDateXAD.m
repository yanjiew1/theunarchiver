#import "NSDateXAD.h"

@implementation NSDate (XAD)

+(NSDate *)XADDateWithTimeIntervalSince1904:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-2082844800
	-[[NSTimeZone defaultTimeZone] secondsFromGMT]];
}

+(NSDate *)XADDateWithTimeIntervalSince1601:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-11644473600];
}

+(NSDate *)XADDateWithMSDOSDate:(uint16_t)date time:(uint16_t)time
{
	return [self XADDateWithMSDOSDateTime:((uint32_t)date<<16)|(uint32_t)time];
}

+(NSDate *)XADDateWithMSDOSDateTime:(uint32_t)msdos
{
	int second=(msdos&31)*2;
	int minute=(msdos>>5)&63;
	int hour=(msdos>>11)&31;
	int day=(msdos>>16)&31;
	int month=(msdos>>21)&15;
	int year=1980+(msdos>>25);
	return [NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:nil];
}

+(NSDate *)XADDateWithWindowsFileTime:(uint64_t)filetime
{
	return [NSDate XADDateWithTimeIntervalSince1601:(double)filetime/10000000];
}

+(NSDate *)XADDateWithWindowsFileTimeLow:(uint32_t)low high:(uint32_t)high
{
	return [NSDate XADDateWithWindowsFileTime:((uint64_t)high<<32)|(uint64_t)low];
}

@end

