#!/usr/bin/env python3
"""Offline regression checks for this personal TestFlight fork."""
import pathlib
import plistlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
APP = ROOT / "SmartTubeApp"


class ReleaseConfigurationTests(unittest.TestCase):
    def test_personal_build_has_no_firebase_startup_or_upload(self):
        source = (APP / "Sources/AppEntry.swift").read_text()
        self.assertNotIn("FirebaseApp.configure()", source)
        self.assertIn("CrashlyticsLogger.isEnabled = false", source)
        project = plistlib.loads(subprocess.check_output([
            "plutil", "-convert", "xml1", "-o", "-",
            str(APP / "SmartTubeApp.xcodeproj/project.pbxproj"),
        ]))
        target = project["objects"]["5A4C56D3A7C36BE68C3C3CE0"]
        phases = [project["objects"][key] for key in target["buildPhases"]]
        for phase in phases:
            self.assertNotIn("Crashlytics/run", phase.get("shellScript", ""))
            for key in phase.get("files", []):
                build_file = project["objects"][key]
                ref = project["objects"].get(build_file.get("fileRef"), {})
                self.assertNotEqual(ref.get("path"), "GoogleService-Info.plist")

    def test_identity_and_shared_container(self):
        project = plistlib.loads(subprocess.check_output([
            "plutil", "-convert", "xml1", "-o", "-",
            str(APP / "SmartTubeApp.xcodeproj/project.pbxproj"),
        ]))
        expected = {
            "SmartTube": "com.dmarie.smarttube",
            "SmartTubeDownloadWidget": "com.dmarie.smarttube.downloadwidget",
            "SmartTubeShareExtension": "com.dmarie.smarttube.shareextension",
            "SafariExtension": "com.dmarie.smarttube.SafariExtension",
        }
        for target in project["objects"].values():
            if target.get("isa") != "PBXNativeTarget" or target["name"] not in expected:
                continue
            configs = project["objects"][target["buildConfigurationList"]]["buildConfigurations"]
            for key in configs:
                settings = project["objects"][key]["buildSettings"]
                self.assertEqual(settings["PRODUCT_BUNDLE_IDENTIFIER"], expected[target["name"]])
                self.assertEqual(settings["DEVELOPMENT_TEAM"], "HEGN9W2S9J")
                self.assertEqual(settings["TARGETED_DEVICE_FAMILY"], "1,2")
        for path in ["SmartTubeApp/SmartTubeApp.entitlements", "ShareExtension/SmartTubeShareExtension.entitlements", "DownloadWidget/SmartTubeDownloadWidget.entitlements"]:
            entitlements = plistlib.loads((APP / path).read_bytes())
            self.assertEqual(entitlements["com.apple.security.application-groups"], ["group.com.dmarie.smarttube"])
        store = ROOT / "SmartTubeIOS/Sources/SmartTubeIOSCore/HomeWidgetSnapshot.swift"
        self.assertIn('public static let appGroup = "group.com.dmarie.smarttube"', store.read_text())
        for path in ["Sources/AppEntry.swift", "ShareExtension/ShareViewController.swift"]:
            self.assertIn("private static let appGroup = HomeWidgetStore.appGroup", (APP / path).read_text())
        entitlements = plistlib.loads((APP / "SmartTubeApp/SmartTubeApp.entitlements").read_bytes())
        self.assertEqual(entitlements["com.apple.developer.ubiquity-kvstore-identifier"], "$(TeamIdentifierPrefix)com.dmarie.smarttube")


if __name__ == "__main__":
    unittest.main()
