#import "Headers/MDSGeneratedImageView.h"
#import "SNVersionTraits.h"
#import "Headers/MSGModelClasses.h"
#import <CydiaSubstrate.h>
#import <UIKit/UIKit.h>
#if __has_include(<RemoteLog.h>)
    #import <RemoteLog.h> // For debugging
#else
    // RemoteLog is a private debugging header. Fall back to the system log so
    // the repo builds on a plain Theos install.
    #define RLog(...) NSLog(__VA_ARGS__)
#endif
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <rootless.h>
#import <version.h>

#define PREF_CHANGED_NOTIF "SNMessenger/prefChanged"

// A trick to use "case/switch" with string
#define SwitchCStr(s) for (const char *__s__ = (s) ; ; )
#define CaseCEqual(str) if (strcmp(str, __s__) == 0)
#define CaseCStart(str) if (strncmp(str, __s__, strlen(str)) == 0)

#define SwitchStr(s) for (NSString *__s__ = (s) ; ; )
#define CaseEqual(str) if ([str isEqualToString:__s__])

#define Default

// Shared variables & functions
extern BOOL isDarkMode;
extern NSBundle *tweakBundle;

extern MDSColorTypeMdsColor *(* MDSColorTypeMdsColorCreate)(NSUInteger);
extern MDSGeneratedImageIconStyleNormal *(* MDSGeneratedImageIconStyleNormalCreate)();
extern MDSGeneratedImageSpecIcon *(* MDSGeneratedImageSpecIconCreate)(NSUInteger, MDSColorTypeMdsColor *, id);
extern MDSGeneratedImageView *MDSGeneratedImageViewCreate(NSString *, NSUInteger, CGSize);

static inline void *getImageBase(const char *imageName) {
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        void *header = (void *)_dyld_get_image_header(i);
        if (header && strstr(_dyld_get_image_name(i), imageName)) {
            return header;
        }
    }

    return NULL;
}

static inline MSImageRef getImageRef(NSString *framework) {
    NSString *frameworkPath = [NSString stringWithFormat:@"%@/Frameworks/%@", [[NSBundle mainBundle] bundlePath], framework];
    NSBundle *bundle = [NSBundle bundleWithPath:frameworkPath];
    if (!bundle.loaded) [bundle load];
    return MSGetImageByName([frameworkPath UTF8String]);
}

static inline CGFloat MessengerVersion() {
    return SNMessengerVersion();
}

static inline NSString *localizedStringForKey(NSString *key) {
    return [tweakBundle localizedStringForKey:key value:nil table:nil];
}

static inline NSString *getSettingsPlistPath() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *plistPath = [documentsDirectory stringByAppendingPathComponent:@"SNMessenger.plist"];
    return plistPath;
}

static inline NSMutableDictionary *getCurrentSettings() {
    return [[NSMutableDictionary alloc] initWithContentsOfFile:getSettingsPlistPath()] ?: [@{} mutableCopy];
}

static inline NSMutableDictionary *compareDictionaries(NSDictionary *oldDict, NSDictionary *newDict) {
    NSMutableDictionary *result = [@{} mutableCopy];

    [newDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id newDictObj, BOOL *stop) {
        id oldDictObj = oldDict[key];

        if (!oldDictObj || ![newDictObj isEqual:oldDictObj]) {
            result[key] = newDictObj;
        }
    }];

    return result;
}

static inline UIImage *getImage(NSString *name) {
    NSString *path = [tweakBundle pathForResource:name ofType:@"png"];
    return [UIImage imageWithContentsOfFile:path];
}

static inline UIImage *scaleImageWithSize(UIImage *image, CGSize size) {
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

static inline CGFloat colorComponentFrom(NSString *string, NSUInteger start, NSUInteger length) {
    NSString *substring = [string substringWithRange:NSMakeRange(start, length)];
    NSString *fullHex = length == 2 ? substring : [NSString stringWithFormat: @"%@%@", substring, substring];
    unsigned int hexComponent;
    [[NSScanner scannerWithString:fullHex] scanHexInt:&hexComponent];

    return hexComponent / 255.0f;
}

static inline UIColor *colorWithHexString(NSString *hexString) {
    CGFloat Red   = colorComponentFrom(hexString, 1, 2);
    CGFloat Green = colorComponentFrom(hexString, 3, 2);
    CGFloat Blue  = colorComponentFrom(hexString, 5, 2);
    CGFloat Alpha = [hexString length] == 9 ? colorComponentFrom(hexString, 7, 2) : 1.0f;

    return [UIColor colorWithRed:Red green:Green blue:Blue alpha:Alpha];
}
