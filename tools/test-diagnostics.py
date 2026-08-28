#!/usr/bin/env python3
import plistlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class DiagnosticsReleaseTests(unittest.TestCase):
    def test_runtime_probe_is_wired_without_broad_message_hooking(self):
        tweak = read("SNMessenger.xm")
        header = read("Diagnostics/SNDiagnostics.h")
        implementation = read("Diagnostics/SNDiagnostics.mm")
        probe_hooks = read("Diagnostics/SNDiagnosticsHooks.xm")

        self.assertIn('#import "Diagnostics/SNDiagnostics.h"', tweak)
        self.assertIn("SNDiagnosticsStart();", tweak)
        self.assertIn("SNDiagnosticsRecordSettingsEntry", tweak)
        # The view-controller hook moved out of the tweak so a release build can
        # leave it out by file; it is still part of a probe build.
        self.assertIn("%hook UIViewController", probe_hooks)
        self.assertIn("SNDiagnosticsRecordViewController(self)", probe_hooks)
        self.assertIn("void SNDiagnosticsStart(void)", header)
        self.assertIn("SNMessengerDiagnostics.txt", implementation)
        self.assertIn("HBPreferences", implementation)
        self.assertIn("sharedSettingsKeys", implementation)
        self.assertNotIn("%hook NSObject", tweak)
        self.assertNotRegex(tweak + implementation, r"MSHookFunction\s*\([^\n]*objc_msgSend")

    def test_messenger_575_uses_ios_settings_instead_of_custom_navigation(self):
        tweak = read("SNMessenger.xm")
        utilities = read("Utilities.h")
        table_cell = read("Settings/SNTableViewCell.mm")

        self.assertNotIn("SNInstallSettingsButtonIfNeeded", tweak)
        self.assertNotIn("snmessenger_openTweakSettings:", tweak)
        self.assertIn("SN_PREFERENCES_IDENTIFIER", utilities)
        self.assertIn("HBPreferences", utilities)
        self.assertIn("dictionaryRepresentation", utilities)
        self.assertIn("legacySettings", utilities)
        self.assertIn("[result addEntriesFromDictionary:sharedSettings]", utilities)
        self.assertNotIn("didMigrateLegacyPreferences", utilities)
        self.assertIn("setCurrentPreferenceValue", table_cell)
        self.assertNotIn("writeToFile:_plistPath", table_cell)

    def test_settings_transport_mirrors_into_messenger_container_and_apply_closes_app(self):
        controller = read("SNMessengerPrefs/SNRootListController.m")
        root = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Root.plist").read_bytes())

        self.assertIn("messengerSettingsPath", controller)
        self.assertIn("synchronizeSettingsTransport", controller)
        self.assertIn("writeLegacySettingsValue", controller)
        self.assertIn("posix_spawn", controller)
        self.assertIn('"Messenger"', controller)
        self.assertIn("applySettings", controller)
        actions = {item.get("action") for item in root.get("items", [])}
        self.assertIn("applySettings", actions)

    def test_diagnostics_reports_effective_values_and_runtime_feature_hits(self):
        header = read("Diagnostics/SNDiagnostics.h")
        implementation = read("Diagnostics/SNDiagnostics.mm")
        tweak = read("SNMessenger.xm")

        self.assertIn("SNDiagnosticsRecordFeatureHit", header)
        self.assertIn("=== effective settings ===", implementation)
        self.assertIn("=== feature hook hits ===", implementation)
        self.assertIn("SNDefaultSettings", implementation)
        self.assertIn("SNDiagnosticsRecordFeatureHit", tweak)
        self.assertIn('hideMetaAIFloatingButton', tweak)
        self.assertIn("appliedHidden=", tweak)

    def test_hook_matrix_and_candidate_scan_are_bounded(self):
        implementation = read("Diagnostics/SNDiagnostics.mm")
        for token in (
            "MSGCommunityListViewController",
            "_headerSectionCellConfigs",
            "MDSNavigationController",
            "MSGSettingsViewController",
            "MSGThreadViewController",
            "LightSpeedCore",
            "LightSpeedEngine",
        ):
            self.assertIn(token, implementation)
        self.assertRegex(implementation, r"kSNMaximumCandidateClasses\s*=\s*\d+")
        self.assertRegex(implementation, r"kSNMaximumCandidateMethods\s*=\s*\d+")
        self.assertIn("class_getClassMethod", implementation)
        self.assertIn('MSGModel|setValueForField:', implementation)
        self.assertNotIn('MSGModel|setValueForField:value:', implementation)
        self.assertIn('MSGCQLResultSetList|+newWithIdentifier:', implementation)

    def test_call_confirmation_cannot_crash_on_a_moved_model_layout(self):
        tweak = read("SNMessenger.xm")
        body = tweak.split("id LSRTCValidateCallIntentForKey(", 1)[1].split("\n}", 1)[0]
        # The enabled check has to come before anything is read out of params:
        # it is an MSGModel, whose fields are addressed by offset, and reaching
        # through a moved layout is what took the app down on the call button.
        self.assertLess(body.index("callConfirmation"), body.index("callIntent"))
        self.assertIn("respondsToSelector:@selector(callIntent)", body)
        self.assertIn("respondsToSelector:@selector(navigationCoordinator)", body)
        self.assertIn("canPresent", body)
        self.assertIn("NSSelectorFromString(", body)

    def test_model_fields_are_dumped_for_the_swapped_thread_list_config(self):
        implementation = read("Diagnostics/SNDiagnostics.mm")
        header = read("Diagnostics/SNDiagnostics.h")
        tweak = read("SNMessenger.xm")
        self.assertIn("SNDiagnosticsRecordModelFields", header)
        self.assertIn("=== model fields ===", implementation)
        self.assertIn("debugMSGModel", implementation)
        # Both sides of the write, so a write that never landed is told apart
        # from a field whose meaning changed under the same name.
        self.assertIn('SNDiagnosticsRecordModelFields(@"MSGThreadListConfig before", config)', tweak)
        self.assertIn('SNDiagnosticsRecordModelFields(@"MSGThreadListConfig after", config)', tweak)
        before = tweak.index('MSGThreadListConfig before')
        after = tweak.index('MSGThreadListConfig after')
        self.assertLess(before, tweak.index('setValueForField:@"shouldShowSearch"'))
        self.assertLess(tweak.index('setValueForField:@"shouldShowInboxUnit"'), after)

    def test_list_rows_have_a_detail_controller(self):
        root = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Root.plist").read_bytes())
        # A PSLinkListCell without a detail controller pushes an empty screen.
        for item in root.get("items", []):
            if item.get("cell") == "PSLinkListCell":
                self.assertEqual("PSListItemsController", item.get("detail"), item.get("key"))

    def test_apply_button_reports_what_actually_happened(self):
        controller = read("SNMessengerPrefs/SNRootListController.m")
        # Apply reported success from the spawn alone, which says nothing about
        # whether Messenger was actually closed.
        self.assertIn("WEXITSTATUS", controller)
        self.assertIn("WIFEXITED", controller)

    def test_read_receipts_bind_to_the_symbols_the_scan_found(self):
        tweak = read("SNMessenger.xm")
        # The old transport symbol is gone from 575, so nothing may bind to it;
        # naming it in a comment is fine and worth keeping as history.
        self.assertNotIn('{"MCQSHIMTransportHybridThreadMarkThreadRead"', tweak)
        self.assertIn('{"MCQTamTransportThreadMarkRead"', tweak)
        self.assertIn("LSSendMessageReadReceipt", tweak)
        # The local optimistic mark must NOT be blocked: the thread still has to
        # stop showing as unread on this device.
        self.assertNotIn('{"MCDMessagingOptimisticMarkThreadRead"', tweak)

    def test_story_saving_is_gone_rather_than_left_crashing(self):
        tweak = read("SNMessenger.xm")
        root = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Root.plist").read_bytes())
        self.assertNotIn("canSaveFriendsStories", tweak)
        self.assertNotIn("LSStoryOverlayProfileView", tweak)
        self.assertNotIn("canSaveFriendsStories",
                         {i.get("key") for i in root.get("items", [])})

    def test_long_press_on_the_inbox_bar_opens_settings(self):
        tweak = read("SNMessenger.xm")
        self.assertIn("settingsPressRecognizer", tweak)
        self.assertIn("handleSettingsLongPress:", tweak)
        self.assertIn("UIGestureRecognizerStateBegan", tweak)
        # It is added to the navigation bar of the inbox, on the hook that the
        # report shows firing on every launch.
        self.assertIn("[self.navigationBar addGestureRecognizer:press]", tweak)

    def test_call_alert_is_presented_on_the_main_thread(self):
        tweak = read("SNMessenger.xm")
        body = tweak.split("- (void)presentAlertWithCompletion:", 1)[1].split("%end", 1)[0]
        # LightSpeed calls the validator from its own queue, and UIKit
        # presentation is main-thread only — that race is the crash on the
        # first call after a fresh launch.
        self.assertIn("dispatch_get_main_queue()", body)
        self.assertIn("SNKeyWindowRootViewController", body)
        # A call must never be left hanging because no alert could be shown.
        self.assertIn("if (!presented) completion(YES);", body)

    def test_inbox_class_is_resolved_by_its_swift_name(self):
        tweak = read("SNMessenger.xm")
        # Messenger moved the inbox controller into a Swift module, so the bare
        # name resolves to nil and every isKindOfClass: against it is false —
        # which is why the eye button and the long press never installed.
        self.assertIn("LightSpeedInbox.MSGInboxViewController", tweak)
        self.assertIn("SNInboxViewControllerClass", tweak)
        self.assertNotIn("%c(MSGInboxViewController)", tweak)

    def test_package_and_settings_are_named_lite(self):
        control = read("control")
        root = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Root.plist").read_bytes())
        loader = plistlib.loads((ROOT / "layout/Library/PreferenceLoader/Preferences/SNMessengerPrefs.plist").read_bytes())
        self.assertIn("Name: SNMessenger Lite", control)
        self.assertEqual("SNMessenger Lite", root.get("title"))
        self.assertEqual("SNMessenger Lite", loader["entry"]["label"])
        # The identifier stays so an existing install upgrades in place.
        self.assertIn("Package: com.nguyenasang.snmessenger", control)

    def test_symbol_scan_looks_for_the_read_receipt_replacement(self):
        header = read("Diagnostics/SNSymbolScan.h")
        implementation = read("Diagnostics/SNSymbolScan.mm")
        diagnostics = read("Diagnostics/SNDiagnostics.mm")
        makefile = read("Makefile")
        self.assertIn("SNSymbolsMatching", header)
        self.assertIn("LC_SYMTAB", implementation)
        self.assertIn("SEG_LINKEDIT", implementation)
        self.assertIn("=== symbol scan ===", diagnostics)
        self.assertIn("MarkThreadRead", diagnostics)
        self.assertIn("Diagnostics/SNSymbolScan.mm", makefile)

    def test_c_symbol_resolution_is_reported(self):
        hook_header = read("SNMessenger.h")
        self.assertIn("SNDiagnosticsRecordSymbol", hook_header)
        self.assertIn("MSFindSymbol", hook_header)

    def test_preference_bundle_is_a_release_page_without_diagnostics(self):
        root = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Root.plist").read_bytes())
        info = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Info.plist").read_bytes())
        loader = plistlib.loads((ROOT / "layout/Library/PreferenceLoader/Preferences/SNMessengerPrefs.plist").read_bytes())
        actions = {item.get("action") for item in root.get("items", [])}
        self.assertTrue({"applySettings", "resetSettings"}.issubset(actions))
        # The report rows are built in code under SN_DIAGNOSTICS instead, so a
        # release page cannot reach code that reads a report nothing writes.
        for probe_action in ("refreshReport", "copyReport", "shareReport", "clearReport"):
            self.assertNotIn(probe_action, actions, probe_action)
        self.assertNotIn("statusValue:", {item.get("get") for item in root.get("items", [])})
        preference_items = [item for item in root.get("items", []) if item.get("key")]
        preference_keys = {item["key"] for item in preference_items}
        # The eight the owner asked to keep, all with a hook that is alive on 575.
        expected_keys = {
            "noAds", "disableReadReceipts", "hideMetaAIFloatingButton",
            "callConfirmation", "disableTypingIndicator",
            "disableLongPressToChangeTheme", "disableStorySeenReceipts",
            "extendStoryVideoUploadLength",
        }
        self.assertTrue(expected_keys.issubset(preference_keys))
        # Removed because the device proved they cannot work on this build:
        # the thread row class is gone, there is no stories tab, the search
        # field is ignored, and the eye button only shortcuts read receipts.
        for dead in ("hideTypingIndicator", "hideStoriesTab", "hideSearchBar",
                     "showTheEyeButton"):
            self.assertNotIn(dead, preference_keys, dead)
        self.assertTrue(all(item.get("defaults") == "com.nguyenasang.snmessenger" for item in preference_items))
        self.assertTrue(all(item.get("PostNotification") == "SNMessenger/prefChanged" for item in preference_items))
        self.assertEqual("PSLinkCell", loader["entry"]["cell"])
        self.assertEqual("SNRootListController", loader["entry"]["detail"])
        self.assertTrue(loader["entry"]["isController"])
        self.assertEqual(["en", "vi"], info["CFBundleLocalizations"])
        self.assertEqual("15.0", info["MinimumOSVersion"])

        controller = read("SNMessengerPrefs/SNRootListController.m")
        self.assertIn("LSApplicationProxy", controller)
        self.assertIn("dataContainerURL", controller)
        self.assertIn("UIActivityViewController", controller)
        self.assertIn("UIPasteboard", controller)
        self.assertIn("statusValue:(PSSpecifier *)specifier", controller)
        self.assertIn("setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier", controller)
        self.assertIn("resetSettings", controller)

        english = read("SNMessengerPrefs/Resources/en.lproj/Root.strings")
        vietnamese = read("SNMessengerPrefs/Resources/vi.lproj/Root.strings")
        self.assertIn('"Share Report File"', english)
        self.assertIn('"Chia sẻ tệp báo cáo"', vietnamese)

    def test_release_version_and_legacy_identity_are_consistent(self):
        control = read("control")
        makefile = read("Makefile")
        info = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Info.plist").read_bytes())
        version = re.search(r"^Version:\s*(\S+)", control, re.MULTILINE).group(1)
        # The version is not pinned here. Pinning it means every release bump
        # fails the check meant to guard the release; what matters is that the
        # Makefile and the preference bundle both take their number from
        # control, and that the probe compiles the same one into its report.
        self.assertIn("PACKAGE_VERSION = $(shell sed -n 's/^Version: //p' control)", makefile)
        self.assertIn("SN_PROBE_VERSION", makefile)
        self.assertIn("SN_PROBE_VERSION", read("Diagnostics/SNDiagnostics.mm"))
        self.assertNotIn('probeVersion: 2.2', read("Diagnostics/SNDiagnostics.mm"))
        self.assertEqual(version, info["CFBundleShortVersionString"])
        self.assertIn("Package: com.nguyenasang.snmessenger", control)
        self.assertIn("preferenceloader", control.lower())
        self.assertIn("ws.hbang.common", control.lower())

    def test_makefiles_package_rootless_probe_and_preferences(self):
        makefile = read("Makefile")
        prefs_makefile = read("SNMessengerPrefs/Makefile")
        self.assertIn("Diagnostics/SNDiagnostics.mm", makefile)
        self.assertIn("SUBPROJECTS += SNMessengerPrefs", makefile)
        self.assertIn("Cephei", makefile)
        self.assertIn("THEOS_PACKAGE_SCHEME = rootless", prefs_makefile)
        self.assertIn("ARCHS = arm64 arm64e", prefs_makefile)
        self.assertIn("Cephei", prefs_makefile)

    def test_the_probe_costs_nothing_in_a_release_build(self):
        """The probe is opt-in at build time, and opting out has to be total.

        Leaving it compiled in is not a small cost. It swizzles
        -viewDidAppear: on every view controller in Messenger, formats a
        string on per-row paths like the typing check, walks the class list
        twice per launch and rewrites a multi-kilobyte report whenever
        anything moves.
        """
        makefile = read("Makefile")
        prefs_makefile = read("SNMessengerPrefs/Makefile")
        header = read("Diagnostics/SNDiagnostics.h")
        tweak = read("SNMessenger.xm")

        # Sources are linked only under the flag, so a release build does not
        # carry the probe's code at all.
        self.assertIn("ifeq ($(DIAGNOSTICS), 1)", makefile)
        self.assertIn("-DSN_DIAGNOSTICS=1", makefile)
        self.assertIn("ifeq ($(DIAGNOSTICS), 1)", prefs_makefile)
        diagnostics_line = next(
            line for line in makefile.splitlines()
            if "Diagnostics/SNDiagnostics.mm" in line
        )
        self.assertIn("+=", diagnostics_line, "sources must be conditional, not base")

        # Variadic macros, so the argument expressions the call sites build are
        # discarded unevaluated rather than passed to an empty function.
        self.assertIn("#if SN_DIAGNOSTICS", header)
        for function in ("SNDiagnosticsRecordFeatureHit", "SNDiagnosticsRecordSettingsEntry",
                         "SNDiagnosticsRecordViewController", "SNDiagnosticsRecordModelFields",
                         "SNDiagnosticsRecordSymbol", "SNDiagnosticsStart", "SNDiagnosticsFlush"):
            self.assertIn(f"#define {function}(...)", header, function)

        # The one hook that exists only for the probe has to be excluded by
        # file, not by #if. Logos runs before the C preprocessor, so a guarded
        # %hook is still registered and still called from %init while its body
        # is preprocessed away — which is a link error, not a disabled hook.
        # That mistake cost a build; this is the test that would have caught it.
        self.assertNotIn("%hook UIViewController", tweak)
        probe_hooks = read("Diagnostics/SNDiagnosticsHooks.xm")
        self.assertIn("%hook UIViewController", probe_hooks)
        self.assertIn("Diagnostics/SNDiagnosticsHooks.xm", diagnostics_line)

    def test_ad_removal_does_no_work_when_it_is_switched_off(self):
        """Both ad paths run on every inbox and story refresh, so the disabled
        case has to cost nothing — and the story path used to strip ads even
        for someone who had asked to keep them."""
        tweak = read("SNMessenger.xm")
        inbox = tweak[tweak.index("- (NSArray *)inboxRows"):]
        inbox = inbox[:inbox.index("%end")]
        self.assertIn("if (!noAds) {\n        return originalRows;", inbox)
        self.assertLess(inbox.index("if (!noAds)"), inbox.index("mutableCopy"))

        stories = tweak[tweak.index("_updateStoriesWithBucketStoryModels"):]
        stories = stories[:stories.index("%end")]
        self.assertIn("if (!noAds) {", stories)
        self.assertLess(stories.index("if (!noAds)"), stories.index("reverseObjectEnumerator"))

    def test_workflow_publishes_direct_rootless_deb(self):
        workflow = read(".github/workflows/build.yml")
        self.assertIn("SNMessenger-latest-rootless.deb", workflow)
        self.assertIn("snmessenger-probe", workflow)
        self.assertIn("gh release upload", workflow)
        self.assertIn("dpkg-deb -I", workflow)
        self.assertIn("dpkg-deb -c", workflow)


if __name__ == "__main__":
    unittest.main()
