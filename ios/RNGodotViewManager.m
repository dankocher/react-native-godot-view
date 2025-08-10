#import <React/RCTViewManager.h>
@interface RCT_EXTERN_MODULE(RNGodotViewManager, RCTViewManager)
RCT_EXPORT_VIEW_PROPERTY(pckName, NSString)
RCT_EXPORT_VIEW_PROPERTY(onGodotEvent, RCTDirectEventBlock)
@end
