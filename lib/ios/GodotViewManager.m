#import <React/RCTViewManager.h>

@interface RNGodotViewManager : RCTViewManager
@end

@implementation RNGodotViewManager

RCT_EXPORT_MODULE(RNGodotView)

- (UIView *)view {
  return [NSClassFromString(@"RNGodotView") new];
}

RCT_EXPORT_VIEW_PROPERTY(pckName, NSString)
RCT_EXPORT_VIEW_PROPERTY(onGodotEvent, RCTDirectEventBlock)

@end
