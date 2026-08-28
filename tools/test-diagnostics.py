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

        self.assertIn('#import "Diagnostics/SNDiagnostics.h"', tweak)
        self.assertIn("SNDiagnosticsStart();", tweak)
        self.assertIn("SNDiagnosticsRecordSettingsEntry", tweak)
        self.assertIn("%hook UIViewController", tweak)
        self.assertIn("SNDiagnosticsRecordViewController(self)", tweak)
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

    def test_c_symbol_resolution_is_reported(self):
        hook_header = read("SNMessenger.h")
        self.assertIn("SNDiagnosticsRecordSymbol", hook_header)
        self.assertIn("MSFindSymbol", hook_header)

    def test_preference_bundle_has_copy_share_refresh_and_vietnamese(self):
        root = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Root.plist").read_bytes())
        info = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Info.plist").read_bytes())
        loader = plistlib.loads((ROOT / "layout/Library/PreferenceLoader/Preferences/SNMessengerPrefs.plist").read_bytes())
        actions = {item.get("action") for item in root.get("items", [])}
        self.assertTrue({"applySettings", "refreshReport", "copyReport", "shareReport", "clearReport", "resetSettings"}.issubset(actions))
        preference_items = [item for item in root.get("items", []) if item.get("key")]
        preference_keys = {item["key"] for item in preference_items}
        expected_keys = {
            "noAds", "showTheEyeButton", "alwaysSendHdPhotos", "callConfirmation",
            "keyboardStateAfterEnterChat", "disableTypingIndicator", "hideTypingIndicator",
            "disableLongPressToChangeTheme", "disableReadReceipts", "hideNotifBadgesInChat",
            "canSaveFriendsStories", "disableStoriesPreview", "disableStorySeenReceipts",
            "extendStoryVideoUploadLength", "neverReplayStoryAfterReacting",
            "hideMetaAIFloatingButton", "hideNotesRow", "hideStoriesTab",
            "hideSearchBar", "hideSuggestionsInSearch",
        }
        self.assertTrue(expected_keys.issubset(preference_keys))
        self.assertTrue(all(item.get("defaults") == "com.nguyenasang.snmessenger" for item in preference_items))
        self.assertTrue(all(item.get("PostNotification") == "SNMessenger/prefChanged" for item in preference_items))
        value_getters = {item.get("get") for item in root.get("items", []) if item.get("get")}
        self.assertIn("statusValue:", value_getters)
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

    def test_workflow_publishes_direct_rootless_deb(self):
        workflow = read(".github/workflows/build.yml")
        self.assertIn("SNMessenger-latest-rootless.deb", workflow)
        self.assertIn("snmessenger-probe", workflow)
        self.assertIn("gh release upload", workflow)
        self.assertIn("dpkg-deb -I", workflow)
        self.assertIn("dpkg-deb -c", workflow)


if __name__ == "__main__":
    unittest.main()
