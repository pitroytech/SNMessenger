#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const SNDiagnosticsDomain;
FOUNDATION_EXPORT NSString * const SNDiagnosticsReportKey;
FOUNDATION_EXPORT NSString * const SNDiagnosticsUpdatedKey;
FOUNDATION_EXPORT CFStringRef const SNDiagnosticsRunNotification;

void SNDiagnosticsStart(void);
void SNDiagnosticsFlush(NSString *reason);
void SNDiagnosticsRecordSymbol(NSString *framework, const char *symbol, BOOL found, const void *address);
void SNDiagnosticsRecordSettingsEntry(NSString *source, id _Nullable controller, NSInteger itemCount);
void SNDiagnosticsRecordViewController(UIViewController *controller);
void SNDiagnosticsRecordFeatureHit(NSString *feature, id _Nullable target, NSString * _Nullable detail);
void SNDiagnosticsRecordModelFields(NSString *label, id _Nullable model);

NS_ASSUME_NONNULL_END
