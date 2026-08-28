#import "SNDiagnostics.h"

#import <UIKit/UIKit.h>

/// Hooks that exist only to feed the probe.
///
/// They live in their own file because Logos runs before the C preprocessor:
/// wrapping a %hook in `#if SN_DIAGNOSTICS` still registers the hook and still
/// emits the call into %init, while the method body disappears — which is a
/// link error, not a disabled feature. Leaving the file out of the build is the
/// only way to actually not install a hook.
///
/// The Makefile compiles this file only under DIAGNOSTICS=1.

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SNDiagnosticsRecordViewController(self);
}

%end
