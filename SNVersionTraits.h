#import <Foundation/Foundation.h>

// Everything that differs between Messenger versions is decided here, so
// porting to a new version means editing this one file instead of hunting for
// scattered version comparisons.
//
// Each trait says *what changed*, not *which version it is*. When Messenger
// moves again, add the boundary here and the call sites keep reading.
//
// Known boundaries so far:
//
//   v458.0.0 and older
//     - MSGModel field type enum is shifted down by one: the "Struct" entry
//       sits where "Strong Object" sits on newer builds.
//     - MSGModelDefineClass and friends are exported by LightSpeedCore.
//     - ADT models are created with -newADTModelWithInfo:adtValueSubtype:.
//     - Some MDS colour codes differ.
//
//   v459.0.0 and newer
//     - Field type enum gained an entry, shifting Strong/Weak Object up.
//     - The LightSpeed symbols moved to LightSpeedEngine.
//     - ADT models are created with -newADTModelWithInfo:adtInfo:.

typedef struct {
    // Amount to subtract from a raw MSGModel field type before comparing it
    // against the type table in SNMessenger.h.
    NSUInteger fieldTypeShift;

    // MSGModelDefineClass and the LightSpeed C functions moved framework.
    BOOL lightSpeedSymbolsInEngine;

    // -newADTModelWithInfo:adtInfo: versus the older adtValueSubtype: form.
    BOOL usesADTInfoInitialiser;

    // A handful of MDS colour codes need remapping on this build.
    BOOL remapsMdsColorCodes;
} SNVersionTraits;

static inline CGFloat SNMessengerVersion(void) {
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (version.length < 5) return 0.0f;
    return [[version substringToIndex:5] floatValue];
}

static inline SNVersionTraits SNTraits(void) {
    static SNVersionTraits traits;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGFloat version = SNMessengerVersion();

        // A version this code has never seen is treated as the newest shape,
        // which is the only guess that can be right for a future build.
        BOOL isLegacy = (version > 0.0f && version <= 458.0f);

        traits = (SNVersionTraits){
            .fieldTypeShift            = isLegacy ? 1 : 0,
            .lightSpeedSymbolsInEngine = !isLegacy,
            .usesADTInfoInitialiser    = !isLegacy,
            .remapsMdsColorCodes       = (version == 458.0f),
        };

        NSLog(@"[SNMessenger] Messenger v%.1f traits: fieldTypeShift=%lu engineSymbols=%d adtInfo=%d remapColors=%d",
              version,
              (unsigned long)traits.fieldTypeShift,
              traits.lightSpeedSymbolsInEngine,
              traits.usesADTInfoInitialiser,
              traits.remapsMdsColorCodes);
    });

    return traits;
}
