#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// The probe is a development tool, not a feature.
///
/// It earned its place — the hook matrix found six dead hooks, the symbol scan
/// named the read-receipt function after three rounds of guessing failed — but
/// everything it does costs the user something. It hooks -viewDidAppear: on
/// every UIViewController in Messenger, allocates a formatted string on hot
/// paths like the per-row typing check, walks the whole class list twice per
/// launch, and rewrites a multi-kilobyte report file whenever anything moves.
/// None of that belongs in a build someone uses all day.
///
/// So the call sites stay and the code stays; only the build changes. A release
/// build compiles every SNDiagnostics* call to nothing and leaves the
/// Diagnostics sources out of the link entirely.
///
///     make package FINALPACKAGE=1 ROOTLESS=1                  release, no probe
///     make package FINALPACKAGE=1 ROOTLESS=1 DIAGNOSTICS=1    probe build
///
/// When a regression needs evidence, flip the flag rather than rewriting the
/// instrumentation from memory.

#if SN_DIAGNOSTICS

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

#else

// Variadic macros so the arguments are discarded unevaluated: the formatted
// strings the call sites build are the expensive part, and a no-op function
// would still pay for them.
#define SNDiagnosticsStart(...)                 ((void)0)
#define SNDiagnosticsFlush(...)                 ((void)0)
#define SNDiagnosticsRecordSymbol(...)          ((void)0)
#define SNDiagnosticsRecordSettingsEntry(...)   ((void)0)
#define SNDiagnosticsRecordViewController(...)  ((void)0)
#define SNDiagnosticsRecordFeatureHit(...)      ((void)0)
#define SNDiagnosticsRecordModelFields(...)     ((void)0)

#endif
