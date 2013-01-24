#import <Cocoa/Cocoa.h>

@protocol CSURLCacheProvider;

@interface CSURLCache:NSObject
{
	NSMutableArray *providers;
	NSMutableDictionary *cachedurls;
	NSMutableDictionary *cachedbookmarks;
}

+(CSURLCache *)defaultCache;

-(void)addURLProvider:(NSObject <CSURLCacheProvider> *)provider;
-(void)cacheSecurityScopedURL:(NSURL *)url;

-(NSURL *)securityScopedURLAllowingAccessToURL:(NSURL *)url;
-(NSURL *)securityScopedURLAllowingAccessToPath:(NSString *)path;

@end

@protocol CSURLCacheProvider

-(NSArray *)availablePaths;
-(NSURL *)securityScopedURLForPath:(NSString *)path;

@end
