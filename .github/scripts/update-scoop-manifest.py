#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: update-scoop-manifest.py <manifest-path> <old-manifest-path>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    old_path = Path(sys.argv[2])

    if path.exists():
        data = json.loads(path.read_text())
    elif old_path.exists():
        data = json.loads(old_path.read_text())
    else:
        print(f"neither manifest exists: {path} or {old_path}", file=sys.stderr)
        return 1

    version = os.environ["PACKAGE_VERSION"]
    zip_url = os.environ["ZIP_URL"]
    zip_hash = os.environ["ZIP_HASH"]

    data["version"] = version
    data["architecture"]["64bit"]["url"] = zip_url
    data["architecture"]["64bit"]["hash"] = zip_hash
    data["checkver"] = {
        "script": [
            "$ErrorActionPreference='Stop'",
            "$headers=@{ 'User-Agent'='Scoop-Checkver'; 'Accept'='application/vnd.github+json'; 'X-GitHub-Api-Version'='2022-11-28' }",
            "$releases=Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/marcmy/FFmpeg-Builds/releases?per_page=50'",
            "$release=$releases | Where-Object { $_.tag_name -match '^ffmpeg-[0-9]{8}\\.[0-9]{6}-win64-marc-shared$' } | Select-Object -First 1",
            "if ($null -eq $release) { 'ffmpeg-00000000.000000-win64-marc-shared' } else { $release.tag_name }",
        ],
        "regex": r"^ffmpeg-([0-9]{8}\.[0-9]{6})-win64-marc-shared$",
        "replace": "$1",
    }
    data["autoupdate"] = {
        "architecture": {
            "64bit": {
                "url": "https://github.com/marcmy/FFmpeg-Builds/releases/download/ffmpeg-$version-win64-marc-shared/ffmpeg-$version-win64-marc-shared.zip"
            }
        }
    }

    path.write_text(json.dumps(data, indent=4) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
