@interface AboutWindowController : NSWindowController

@property (nonatomic, retain) IBOutlet NSTextField *TfDonate;
@property (nonatomic, retain) IBOutlet NSTextField *TfTitle;
@property (nonatomic, retain) IBOutlet NSTextField *TfVersion;
@property (nonatomic, retain) IBOutlet NSTextField *TfCopyright;

@property (nonatomic, retain) IBOutlet NSButton *BtnClose;
@property (nonatomic, retain) IBOutlet NSButton *BtnDonate;
@property (nonatomic, retain) IBOutlet NSButton *BtnSite;
@property (nonatomic, retain) IBOutlet NSButton *BtnForkMe;
@property (nonatomic, retain) IBOutlet NSButton *BtnLicense;

- (IBAction)actionOpenSite:(id)sender;
- (IBAction)actionOpenForkMe:(id)sender;
- (IBAction)actionOpenLicense:(id)sender;
- (IBAction)actionClose:(id)sender;
- (IBAction)actionOpenDonate:(id)sender;

@end
