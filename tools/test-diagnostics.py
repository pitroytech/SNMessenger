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
        self.assertNotIn("%hook NSObject", tweak)
        self.assertNotRegex(tweak + implementation, r"MSHookFunction\s*\([^\n]*objc_msgSend")

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

    def test_c_symbol_resolution_is_reported(self):
        hook_header = read("SNMessenger.h")
        self.assertIn("SNDiagnosticsRecordSymbol", hook_header)
        self.assertIn("MSFindSymbol", hook_header)

    def test_preference_bundle_has_copy_share_refresh_and_vietnamese(self):
        root = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Root.plist").read_bytes())
        info = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Info.plist").read_bytes())
        loader = plistlib.loads((ROOT / "layout/Library/PreferenceLoader/Preferences/SNMessengerPrefs.plist").read_bytes())
        actions = {item.get("action") for item in root.get("items", [])}
        self.assertTrue({"refreshReport", "copyReport", "shareReport", "clearReport"}.issubset(actions))
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

        english = read("SNMessengerPrefs/Resources/en.lproj/Root.strings")
        vietnamese = read("SNMessengerPrefs/Resources/vi.lproj/Root.strings")
        self.assertIn('"Share Report File"', english)
        self.assertIn('"Chia sẻ tệp báo cáo"', vietnamese)

    def test_release_version_and_legacy_identity_are_consistent(self):
        control = read("control")
        makefile = read("Makefile")
        info = plistlib.loads((ROOT / "SNMessengerPrefs/Resources/Info.plist").read_bytes())
        version = re.search(r"^Version:\s*(\S+)", control, re.MULTILINE).group(1)
        package_version = re.search(r"^PACKAGE_VERSION\s*=\s*(\S+)", makefile, re.MULTILINE).group(1)
        self.assertEqual("2.1.0", version)
        self.assertEqual(version, package_version)
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
