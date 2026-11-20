#!/usr/bin/env python3
"""Measure continuous and on-demand MetalKit callbacks in an iOS simulator."""

import argparse
from pathlib import Path
import plistlib
import subprocess


def main():
    """Build an isolated native test app without changing another app's data."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="booted", help="Simulator UDID")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = root / "tmp" / "ios-frames"
    bundle = output / "FrameChecks.app"
    bundle.mkdir(parents=True, exist_ok=True)
    identifier = "local.treeform.windy.frames"
    (bundle / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": identifier,
        "CFBundleExecutable": "FrameChecks",
        "CFBundleName": "FrameChecks",
        "CFBundlePackageType": "APPL",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "1.0",
        "MinimumOSVersion": "16.0",
        "UIDeviceFamily": [1, 2],
        "UILaunchScreen": {},
        "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
    }))
    flags = ["xcrun", "--sdk", "iphonesimulator", "clang",
             "-target", "arm64-apple-ios16.0-simulator", "-fobjc-arc"]
    subprocess.run([
        *flags, str(root / "tests" / "ios_frame_callbacks.m"),
        "-framework", "Foundation", "-framework", "UIKit",
        "-framework", "Metal", "-framework", "MetalKit",
        "-o", str(bundle / "FrameChecks"),
    ], check=True)
    subprocess.run([
        "xcrun", "simctl", "install", args.device, str(bundle),
    ], check=True)
    result = subprocess.run([
        "xcrun", "simctl", "launch", "--terminate-running-process",
        "--console", args.device, identifier,
    ], check=True, timeout=30, capture_output=True, text=True)
    print(result.stdout, end="")
    print(result.stderr, end="")
    if "Actual MetalKit on-demand callback checks passed." not in result.stdout:
        raise RuntimeError("The native app did not report successful frame checks.")
    executable = output / "frames"
    subprocess.run([
        *flags, str(root / "tests" / "ios_frames.m"),
        "-framework", "Foundation", "-o", str(executable),
    ], check=True)
    subprocess.run([
        "xcrun", "simctl", "spawn", args.device, str(executable),
    ], check=True, timeout=30)


if __name__ == "__main__":
    main()
