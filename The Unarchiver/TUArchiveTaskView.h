#import <XADMaster/XADArchive.h>

#import "TUTaskListView.h"
#import "TUEncodingPopup.h"

@interface TUArchiveTaskView:TUMultiTaskView
{
	NSString *archivename;

	id canceltarget;
	SEL cancelselector;

	id responsetarget;
	SEL responseselector;
	NSConditionLock *pauselock;
	int uiresponse;

	NSData *namedata;

	IBOutlet NSView *waitview;
	IBOutlet NSTextField *waitfield;
	IBOutlet NSImageView *waiticon;

	IBOutlet NSView *progressview;
	IBOutlet NSTextField *actionfield;
	IBOutlet NSTextField *namefield;
	IBOutlet NSProgressIndicator *progressindicator;
	IBOutlet NSImageView *progressicon;

	IBOutlet NSView *notwritableview;

	IBOutlet NSView *errorview;
	IBOutlet NSTextField *errorfield;
	IBOutlet NSImageView *erroricon;
	IBOutlet NSButton *errorapplyallcheck;

	IBOutlet NSView *openerrorview;
	IBOutlet NSTextField *openerrorfield;
	IBOutlet NSImageView *openerroricon;

	IBOutlet NSView *passwordview;
	IBOutlet NSTextField *passwordfield;
	IBOutlet NSImageView *passwordicon;
	IBOutlet NSButton *passwordapplyallcheck;

	IBOutlet NSView *encodingview;
	IBOutlet TUEncodingPopUp *encodingpopup;
	IBOutlet NSTextField *encodingfield;
	IBOutlet NSImageView *encodingicon;
}

-(id)initWithFilename:(NSString *)filename;
-(void)dealloc;

-(void)setCancelAction:(SEL)selector target:(id)target;

-(void)setName:(NSString *)name;
-(void)setProgress:(double)progress;
-(void)setProgress:(double)fraction;
-(void)_setProgress:(NSNumber *)fraction;


-(void)displayNotWritableErrorWithResponseAction:(SEL)selector target:(id)target;
-(XADAction)displayError:(NSString *)error ignoreAll:(BOOL *)ignoreall;
-(void)displayOpenError:(NSString *)error;
-(NSStringEncoding)displayEncodingSelectorForData:(NSData *)data encoding:(NSStringEncoding)encoding;
-(NSString *)displayPasswordInputWithApplyToAllPointer:(BOOL *)applyall;

-(void)setupWaitView;
-(void)setupProgressViewInPreparingMode;
-(void)setupNotWritableView;
-(void)setupErrorView:(NSString *)error;
-(void)setupOpenErrorView:(NSString *)error;
-(void)setupPasswordView;
-(void)setupEncodingViewWithEncoding:(NSNumber *)encodingnum;

-(void)getUserAttention;

-(IBAction)cancelExtraction:(id)sender;
-(IBAction)cancelWait:(id)sender;
-(IBAction)stopAfterNotWritable:(id)sender;
-(IBAction)extractToDesktopAfterNotWritable:(id)sender;
-(IBAction)extractElsewhereAfterNotWritable:(id)sender;
-(IBAction)stopAfterError:(id)sender;
-(IBAction)continueAfterError:(id)sender;
-(IBAction)okAfterOpenError:(id)sender;
-(IBAction)stopAfterPassword:(id)sender;
-(IBAction)continueAfterPassword:(id)sender;
-(IBAction)stopAfterEncoding:(id)sender;
-(IBAction)continueAfterEncoding:(id)sender;
-(IBAction)selectEncoding:(id)sender;


-(int)waitForResponseFromUI;
-(void)setUIResponseAction:(SEL)selector target:(id)target;
-(void)provideResponseFromUI:(int)response;

@end
