#!/usr/bin/env python3
"""
Generate manifest.json for GuDesk auto-update from built release artifacts.

Usage:
  python3 gudesk/build/generate_manifest.py \\
    --version 1.5.0 \\
    --release-notes "Bug fixes and performance improvements." \\
    --base-url https://github.com/your-org/GuDesk/releases/download/v1.5.0 \\
    --windows-x86_64 target/GuDesk-Setup-1.5.0-x86_64.exe \\
    --macos-aarch64  target/GuDesk-1.5.0-aarch64.dmg \\
    --macos-x86_64   target/GuDesk-1.5.0-x86_64.dmg \\
    --output manifest.json
"""
import argparse
import datetime
import hashlib
import json
import os
import sys


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def platform_entry(path: str | None, base_url: str, key: str) -> dict | None:
    if not path:
        return None
    if not os.path.exists(path):
        print(f"WARNING: {key} artifact not found at {path}", file=sys.stderr)
        return None
    filename = os.path.basename(path)
    return {
        "url": f"{base_url.rstrip('/')}/{filename}",
        "sha256": sha256_file(path),
        "size": os.path.getsize(path),
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="Generate GuDesk update manifest.")
    ap.add_argument("--version", required=True, help="Release version, e.g. 1.5.0")
    ap.add_argument(
        "--release-notes",
        default="Bug fixes and improvements.",
        help="Plain-text release notes",
    )
    ap.add_argument(
        "--base-url",
        required=True,
        help="Base download URL (e.g. GitHub release asset URL prefix)",
    )
    ap.add_argument("--windows-x86_64", dest="win", metavar="FILE")
    ap.add_argument("--macos-aarch64", dest="mac_arm", metavar="FILE")
    ap.add_argument("--macos-x86_64", dest="mac_x64", metavar="FILE")
    ap.add_argument(
        "--output", default="manifest.json", help="Output path for manifest.json"
    )
    args = ap.parse_args()

    platforms: dict[str, dict] = {}
    for key, path in [
        ("windows-x86_64", args.win),
        ("macos-aarch64", args.mac_arm),
        ("macos-x86_64", args.mac_x64),
    ]:
        entry = platform_entry(path, args.base_url, key)
        if entry:
            print(f"  {key}: sha256={entry['sha256'][:16]}…  size={entry['size']:,} bytes")
            platforms[key] = entry

    if not platforms:
        print("ERROR: No valid platform artifacts provided.", file=sys.stderr)
        sys.exit(1)

    manifest = {
        "version": args.version,
        "release_notes": args.release_notes,
        "published_at": datetime.datetime.now(datetime.timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        ),
        "platforms": platforms,
    }

    with open(args.output, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    print(f"\nWrote {args.output}")


if __name__ == "__main__":
    main()
