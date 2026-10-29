"""Check public file names and common secret patterns without printing values.

When Git has indexed files, inspect the actual indexed blobs, not working copies.
Before Git initialization, inspect the exported source tree and skip local output.
This is a focused publication check, not a guarantee against every secret format.
"""
import io
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRIVATE_DIRS = {".git", ".idea", ".hvigor", "build", "oh_modules", "node_modules",
                "analysis", "reference", "artifacts", "captures", "backups", "__pycache__"}
PRIVATE_SUFFIXES = {".p12", ".pfx", ".p7b", ".cer", ".crt", ".pem", ".key", ".csr",
                    ".jks", ".keystore", ".mobileprovision", ".har", ".hap", ".hsp",
                    ".app", ".apk", ".zip", ".7z", ".log", ".bak", ".pyc"}
PATTERNS = {
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"),
    "GitHub credential": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b"),
    "cloud access key": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "local user path": re.compile(r"[A-Za-z]:[/\\]+Users[/\\]+[^\s'\"/\\]+|/(?:Users|home)/[A-Za-z0-9_.-]+/"),
    "phone-like literal": re.compile(r"(?<![\w])1[3-9][0-9]{9}(?![\w])"),
    "email address": re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
    "credential JSON literal": re.compile(r'''["'](?:password|client_secret|access_token|refresh_token|auth_token|api_key|storePassword|keyPassword)["']\s*:\s*["'][^"'\r\n]+["']''', re.I),
    "credential assignment": re.compile(r'''\b(?:const|let|private|public)\s+(?:readonly\s+)?(?:password|client_secret|access_token|refresh_token|auth_token|api_key)\s*(?::\s*string)?\s*=\s*["'][^"'\r\n]+["']''', re.I),
}
URL_TEST_USERINFO = {"ifdian.net" + "@" + "evil.test", "evil.test" + "@" + "ifdian.net"}


def indexed_files():
    result = subprocess.run(["git", "ls-files", "--stage", "-z"], cwd=ROOT, capture_output=True)
    if result.returncode or not result.stdout:
        return None
    records = []
    for row in result.stdout.split(b"\0"):
        if not row:
            continue
        metadata, name = row.split(b"\t", 1)
        mode, oid, stage = metadata.split()
        if stage != b"0" or mode not in {b"100644", b"100755"}:
            raise ValueError("Unsupported index entry: " + name.decode("utf-8"))
        records.append((name.decode("utf-8"), oid))
    output = subprocess.run(["git", "cat-file", "--batch"], cwd=ROOT,
                            input=b"\n".join(oid for _, oid in records) + b"\n",
                            capture_output=True, check=True)
    stream = io.BytesIO(output.stdout)
    files = []
    for name, oid in records:
        header = stream.readline().split()
        assert header[0] == oid and header[1] == b"blob", "Unexpected Git object"
        data = stream.read(int(header[2]))
        assert stream.read(1) == b"\n", "Unexpected object delimiter"
        files.append((name, data))
    return files


def exported_files():
    return [(path.relative_to(ROOT).as_posix(), path.read_bytes()) for path in ROOT.rglob("*")
            if path.is_file() and not any(part in PRIVATE_DIRS for part in path.relative_to(ROOT).parts)]


def main():
    files = indexed_files()
    indexed = files is not None
    if files is None:
        files = exported_files()
    problems = []
    for name, data in files:
        path = Path(name)
        if (any(part in PRIVATE_DIRS for part in path.parts)
                or path.suffix.lower() in PRIVATE_SUFFIXES or path.name.startswith(".env")
                or path.name == "local.properties" or ".local." in path.name):
            problems.append(name + ": private/generated file")
        if path.suffix.lower() == ".png" and "resources/base/media/" in name:
            # Only packaged application artwork is expected in this source tree.
            continue
        try:
            text = data.decode("utf-8-sig")
        except UnicodeDecodeError:
            problems.append(name + ": unexpected binary file")
            continue
        for label, pattern in PATTERNS.items():
            for match in pattern.finditer(text):
                if (name == "tests/url-policy.test.mjs" and label == "email address"
                        and match.group(0) in URL_TEST_USERINFO):
                    continue  # Deliberate hostile URL userinfo, not real account data.
                line = text.count("\n", 0, match.start()) + 1
                problems.append(name + ":" + str(line) + ": " + label)
        if name == "build-profile.json5":
            profile = json.loads(text)
            if profile["app"].get("signingConfigs") or any(
                    product.get("signingConfig") for product in profile["app"]["products"]):
                problems.append(name + ": personal signing configuration")
    print(json.dumps({"passed": not problems, "files_checked": len(files),
                      "source": "git index" if indexed else "exported source tree",
                      "problems": problems}, ensure_ascii=False, indent=2))
    raise SystemExit(1 if problems else 0)


if __name__ == "__main__":
    main()
