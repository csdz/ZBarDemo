#import "EZCodeScannerViewController.h"
#import "ZBarImageScanner.h"
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioServices.h>

@implementation EZCodeScannerViewController

#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

//Grab the Unity3D ViewController (UnityGetGLViewController())
#ifdef UNITY_4_0
    //Unity4
    #import "iPhone_View.h"
#else
    //Unity3.5
    extern UIViewController* UnityGetGLViewController();
#endif


// autoreleasing factory method
+ (id) createWithUI:(BOOL)_showUI withText:(char*)_text withSymbol:(int)_symbols withLandscape:(BOOL)isLandscape {
  return [[EZCodeScannerViewController alloc] initWithUI:_showUI withText:_text withSymbol:_symbols withLandscape:isLandscape];
}

- (id) initWithUI:(BOOL)_showUI withText:(char*)_text withSymbol:(int)_symbols withLandscape:(BOOL)isLandscape
{
    self = [super init];
    if( !self ) return self;
    
    mCodeFound = NO;
    mShowUI = _showUI;
    mDefaultText = _text;
    mSymbols = _symbols;
    mForceLandscape = isLandscape;
    
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    float h = self.view.bounds.size.height;
    float w = self.view.bounds.size.width;

    if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
        screen_height = w;
        screen_width = h;
    } else {
        screen_height = h;
        screen_width = w;
    }
    
    [self showModal];
    
    return self;
}

# pragma mark - NavController

- (void) initializeNavController {
  navController = [[UINavigationController alloc] initWithRootViewController:self];
  navController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
  
  UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(userCancelled)];
  self.navigationItem.leftBarButtonItem = cancelButton;
}

# pragma mark - Reader

- (void) initializeReader
{
    // Create a scanner
    ZBarImageScanner* scanner = [[ZBarImageScanner alloc] init];
    if (mSymbols>=0){
        [scanner setSymbology:ZBAR_NONE config:ZBAR_CFG_ENABLE to:0];
        [scanner setSymbology:(zbar_symbol_type_t)mSymbols config:ZBAR_CFG_ENABLE to:1];
    }

    // Create the reader
    mReader = [[ZBarReaderView alloc] initWithImageScanner:scanner];
    mReader.readerDelegate = self;
    
    // Config the reader view
    CGRect reader_rect = self.view.bounds;
    mReader.frame = reader_rect;
    mReader.backgroundColor = [UIColor blackColor];
    
    // Rotate
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    [mReader willRotateToInterfaceOrientation:interfaceOrientation duration:0.1];
  
    // Start and add to view hierarchy
    [mReader start];
    [self.view addSubview: mReader];
}

- (void) removeReader {
  if (mReader != nil)
    {
        [mReader stop];
        [mReader removeFromSuperview];
        mReader = nil;
    }
}

# pragma mark - User interaction

- (void) userCancelled {
    [self closeModal];
}

# pragma mark - Controls

- (void) showModal {
  [self initializeNavController];
  [self initializeReader];
  [self initializeScreen];
  [UnityGetGLViewController() presentViewController:navController animated:NO completion:^(void){
    UnitySendMessage("CodeScannerBridge", "onScannerEvent", "EVENT_OPENED");
  }];
}

- (void) closeModal
{
    [UnityGetGLViewController() dismissViewControllerAnimated:NO completion:^(void){
        UnitySendMessage("CodeScannerBridge", "onScannerEvent", "EVENT_CLOSED");
    }];
  
    //clean up
    [self removeReader];
    if (mLabel!=nil) 
    {
        mLabel = nil;
    }
    [self.view removeFromSuperview];
    navController = nil;
}

# pragma mark - ZBar delegation

- (void) readerView:(ZBarReaderView *)readerView didReadSymbols: (ZBarSymbolSet *)symbols fromImage:(UIImage *)image
{
    if (mCodeFound) { return; }

    //Images
    /*
    NSData *pixelData = [[NSData alloc] initWithData:UIImagePNGRepresentation(image)];
    instance->mPixelData = (unsigned char *)[pixelData bytes];
    instance->mPixelSize = [pixelData length];
    */

    
    for (ZBarSymbol * s in symbols)
    {
        mCodeFound = true;
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
        UnitySendMessage("CodeScannerBridge", "onScannerMessage", [s.data cStringUsingEncoding:NSUTF8StringEncoding]);
        break;
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(closeModal) object:nil];
    [self performSelector:@selector(closeModal) withObject:nil afterDelay:0.5];
}

# pragma mark - CUSTOM UI

-(void) initializeScreen 
{

    for (id v in [self.view subviews]) {
        if (![v isKindOfClass:[ZBarReaderView class]]) {
            [v removeFromSuperview];
        }
    }
        
    if (mShowUI)
        [self init_ui];
    
    if(mDefaultText)
        [self init_label:mDefaultText];
}

- (void) init_ui
{
    //mask
    UIView* mask1 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screen_width, screen_height/5)];
    mask1.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    [self.view addSubview:mask1];
    UIView* mask2 = [[UIView alloc] initWithFrame:CGRectMake(0, screen_height/5, screen_width/10, screen_height-screen_height*2/5)];
    mask2.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    [self.view addSubview:mask2];
    UIView* mask3 = [[UIView alloc] initWithFrame:CGRectMake(screen_width-screen_width/10, screen_height/5, screen_width/10, screen_height-screen_height*2/5)];
    mask3.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    [self.view addSubview:mask3];
    UIView* mask4 = [[UIView alloc] initWithFrame:CGRectMake(0, screen_height-screen_height/5, screen_width, screen_height/5)];
    mask4.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.6];
    [self.view addSubview:mask4];
    
    //border
    UIView* border = [[UIView alloc] initWithFrame:CGRectMake(screen_width/10, screen_height/5, screen_width-screen_width/5, screen_height-screen_height*2/5)];
    border.layer.borderColor = [UIColor blackColor].CGColor;
    border.layer.borderWidth = 2.0f;
    [self.view addSubview:border];
    
    //laser
    UIView* laser = [[UIView alloc] initWithFrame:CGRectMake(screen_width/10, screen_height/2, screen_width-screen_width/5, 2)];
    laser.backgroundColor = [UIColor colorWithRed:255 green:0 blue:0 alpha:0.7];
    [self.view addSubview:laser];
}

- (void) init_label:(char*)_text
{
    if (!mLabel)
    {
        mLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, screen_height-screen_height/10, screen_width, screen_height/10)];
        mLabel.backgroundColor = [UIColor clearColor];
        mLabel.text = [[NSString alloc] initWithUTF8String:_text];
        mLabel.textAlignment = NSTextAlignmentCenter;
        mLabel.textColor = [UIColor whiteColor];
        mLabel.numberOfLines = 2;
        mLabel.minimumScaleFactor = 1;
        mLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    }
    
    mLabel.frame = CGRectMake(0, screen_height-screen_height/10, screen_width, screen_height/10);
    [self.view addSubview:mLabel];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    mReader.torchMode = 1;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    mReader.torchMode = 0;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ( SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"5.0") ) {
        double delayInSeconds = 0.1f;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [UIViewController attemptRotationToDeviceOrientation];
        });
    }
}

-(void)willRotateToInterfaceOrientation: (UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration {

    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    //NSLog(@"willRotateToInterfaceOrientation current=%d interfaceOrientation=%d", interfaceOrientation, orientation);

    //only id 90°
    if ((UIInterfaceOrientationIsPortrait(interfaceOrientation) && UIInterfaceOrientationIsLandscape(orientation)) || (UIInterfaceOrientationIsPortrait(orientation) && UIInterfaceOrientationIsLandscape(interfaceOrientation)))
    {
        //NSLog(@"willRotateToInterfaceOrientation rotate 90");
        float f = screen_height;
        screen_height = screen_width;
        screen_width = f;
        //NSLog(@"willRotateToInterfaceOrientation h=%f w=%f", screen_height, screen_width);
        [self initializeScreen];
    }
    
    [mReader willRotateToInterfaceOrientation:orientation duration:duration];
}

- (void)dealloc
 {
    navController = nil;
    [self removeReader];
}

# pragma mark - C API

EZCodeScannerViewController* instance;

struct ConfigStruct {
    bool showUI;
    char* defaultText;
    int symbols;
    bool forceLandscape;
};

void launchScannerImpl(struct ConfigStruct *confStruct) {
    instance = [EZCodeScannerViewController createWithUI:confStruct->showUI 
                                            withText:confStruct->defaultText 
                                            withSymbol:confStruct->symbols 
                                            withLandscape:confStruct->forceLandscape];
}

//Deprecated
bool getScannedImageImpl(unsigned char** imageData, int* imageDataLength) {

    /*
    if (instance && instance->mPixelData != nil) {
        *imageData = instance->mPixelData;
        *imageDataLength = instance->mPixelSize;
        return true;
    }
    */

   return false;
}

//Deprecated
void decodeImageImpl(int symbols, const char* pixelBytes, int64_t length) {

    if (pixelBytes != nil && length > 0) {
        
        NSData* pixelData = [NSData dataWithBytes:pixelBytes length:length];
        UIImage *uiimage=[UIImage imageWithData:pixelData];
        
        ZBarImage* image = [[ZBarImage alloc] initWithCGImage:uiimage.CGImage];
        
        ZBarImageScanner * scanner = [[ZBarImageScanner alloc] init];
        if (symbols>=0){
            [scanner setSymbology:ZBAR_NONE config:ZBAR_CFG_ENABLE to:0]; 
            [scanner setSymbology:(zbar_symbol_type_t)symbols config:ZBAR_CFG_ENABLE to:1];
        }
        
        NSInteger result = [scanner scanImage:image];
        
        NSString* data = nil;
        if (result > 0) {
            ZBarSymbolSet * set = scanner.results;
            ZBarSymbol* s = nil;
            for (s in set)
            {
                data = s.data;
            }
        }
        
        UnitySendMessage("CodeScannerBridge", "onDecoderMessage", [data cStringUsingEncoding:NSUTF8StringEncoding]);
    }

} 

@end
