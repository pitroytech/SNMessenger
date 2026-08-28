#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Names of symbols defined by a loaded image whose name contains a keyword.
///
/// Read receipts stopped working because the C function the tweak hooks is no
/// longer exported under the name it used to have, and guessing a replacement
/// is how several rounds were already lost. This reads the image's own symbol
/// table, so the answer comes from Messenger rather than from a hunch.
NSArray<NSString *> *SNSymbolsMatching(NSString *imageNameFragment,
                                       NSArray<NSString *> *keywords,
                                       NSUInteger limit);

NS_ASSUME_NONNULL_END
