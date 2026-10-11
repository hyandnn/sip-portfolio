#!/usr/bin/env python3
"""Check publication candidates without reading ignored personal data or credentials."""
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent


def candidates():
    raw = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT
    )
    return sorted({name.decode("utf-8") for name in raw.split(b"\0") if name})


FORBIDDEN_PARTS = {".git", ".local", ".local-data", ".build", "build", "xcuserdata", "__pycache__", "Images", "CocktailImages"}
FORBIDDEN_NAMES = {".DS_Store", "recommendations.json", "incomplete-recipes-archive.json"}
PATTERNS = {
    "possible API secret": re.compile(r"\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16})\b"),
    "private key": re.compile(r"-----BEGIN [A-Z ]{0,20}PRIVATE" + r" KEY-----"),
    "personal absolute path": re.compile(r"/(?:Users|home)/[A-Za-z0-9._-]+/"),
    "private conversation link": re.compile(r"https?://chatgpt\.com/share/"),
}
REQUIRED = {
    "README.md", "LICENSE", "CONTRIBUTING.md", "THIRD_PARTY_NOTICES.md", "Package.swift", "Makefile",
    ".gitignore", ".github/workflows/ci.yml", "docs/DEVELOPMENT.md", "docs/PRIVACY.md", "docs/VALIDATION.md",
    "Sources/Sipfolio/Resources/Fonts/OFL.txt", "Tests/SipfolioTestSupport/Fixtures/ATTRIBUTION.md",
    "packaging/artwork/sipfolio-pixel-maine-coon-v3.png", "packaging/AppIcon.icns",
}


def main():
    names = candidates()
    existing = {name for name in names if (ROOT / name).is_file() or (ROOT / name).is_symlink()}
    errors = []
    for missing in sorted(REQUIRED - existing):
        errors.append(f"Missing public project file: {missing}")
    for name in sorted(existing):
        file = ROOT / name
        parts = Path(name).parts
        local = (set(parts) & FORBIDDEN_PARTS or Path(name).name in FORBIDDEN_NAMES
                 or (Path(name).name.startswith(".env") and Path(name).name != ".env.example")
                 or any(part.endswith((".app", ".xcarchive")) for part in parts)
                 or name.endswith((".store", ".store-shm", ".store-wal", ".sqlite", ".sqlite-shm", ".sqlite-wal", ".db", ".log", ".dmg", ".xcuserstate", ".pyc")))
        if local:
            errors.append(f"Local artifact is a publication candidate: {name}")
            continue
        if file.is_symlink():
            errors.append(f"Review symbolic link before publication: {name}")
            continue
        data = file.read_bytes()
        if b"\0" in data:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        for label, pattern in PATTERNS.items():
            for match in pattern.finditer(text):
                line = text[:match.start()].count("\n") + 1
                # Report locations only; never echo a possible credential.
                errors.append(f"{name}:{line}: {label}")
        if file.suffix != ".md":
            continue
        links = re.findall(r"\]\(([^)]+)\)", text)
        links += re.findall(r'<(?:img|a)\b[^>]*(?:src|href)="([^"]+)"', text)
        for link in links:
            link = link.strip().split(' "', 1)[0].strip("<>")
            parsed = urlsplit(link)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            target = (file.parent / unquote(parsed.path)).resolve()
            try:
                relative = target.relative_to(ROOT).as_posix()
            except ValueError:
                errors.append(f"{name}: local link escapes repository")
                continue
            if relative not in existing:
                errors.append(f"{name}: missing or unpublished link target: {relative}")
    if errors:
        print("Repository check failed:")
        for error in errors:
            print(f"  {error}")
        return 1
    print(f"Repository check passed: {len(existing)} publication candidates; local links and common private-data patterns checked.")
    print("Ignored files and Git history were not scanned; review the diff before committing.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
