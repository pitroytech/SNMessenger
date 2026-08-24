#import <UIKit/UIKit.h>
#import <objc/message.h>

// Declarations the stock SDK does not give us. Upstream compiled against
// header packages installed on the author's machine, so the repo did not build
// anywhere else. Keeping the declarations here means a plain Theos install is
// enough.

// UITableViewCell has a private separator colour setter.
@interface UITableViewCell (SNPrivateAPI)
- (void)setSeparatorColor:(UIColor *)separatorColor;
@end

// -childViewControllerForUserInterfaceStyle is in the SDK but marked
// unavailable on iOS, so it cannot be called directly however it is declared.
// Messenger's navigation controller answers it at runtime, and going through
// the runtime also means a nil result instead of a crash if it ever stops
// answering.
static inline id SNChildViewControllerForUserInterfaceStyle(id controller) {
    SEL selector = NSSelectorFromString(@"childViewControllerForUserInterfaceStyle");
    if (![controller respondsToSelector:selector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(controller, selector);
}
