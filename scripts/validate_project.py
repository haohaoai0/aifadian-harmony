"""Portable offline project checks. Requires only the Python standard library."""
import base64
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    checks = []
    resource_root = ROOT / "entry/src/main/resources"
    resources = {}
    for kind, locales in [("string", ["base", "zh_CN", "en_US"]),
                          ("color", ["base", "dark"])]:
        groups = []
        for locale in locales:
            entries = []
            for path in sorted((resource_root / locale / "element").glob("*.json")):
                entries.extend(read(path).get(kind, []))
            names = [item["name"] for item in entries]
            assert len(names) == len(set(names)), "Duplicate resource: " + locale
            groups.append(set(names))
        assert all(group == groups[0] for group in groups), kind + " locale parity"
        resources[kind] = groups[0]
        checks.append(kind + " resource parity")
    for path in (resource_root / "base/element").glob("*.json"):
        for kind, entries in read(path).items():
            resources.setdefault(kind, set()).update(item["name"] for item in entries)
    resources["media"] = {path.stem for path in (resource_root / "base/media").iterdir()}
    resources["profile"] = {path.stem for path in (resource_root / "base/profile").iterdir()}

    sources = list((ROOT / "entry/src/main/ets").rglob("*.ets"))
    sources.extend((ROOT / "entry/src/main/ets").rglob("*.ts"))
    for path in sources:
        text = path.read_text(encoding="utf-8-sig")
        # Ignore comments and string literals when checking language keywords.
        syntax = re.sub(r"//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"", "", text)
        assert not re.search(r"\b(any|unknown)\b|\bas const\b|\bvar\s", syntax), path.relative_to(ROOT)
        for kind, name in re.findall(r"\$r\(['\"]app\.([a-z]+)\.([A-Za-z0-9_]+)['\"]\)", text):
            assert name in resources.get(kind, set()), "Missing resource: " + kind + "." + name
    checks.append("ArkTS basic constraints and resource references")

    cipher = (ROOT / "entry/src/main/ets/services/ApiCipher.ets").read_text(encoding="utf-8")
    public_key = re.search(r"const PUBLIC_KEY: string = '([^']+)'", cipher)
    assert public_key, "Missing protocol public key"
    der = base64.b64decode(public_key.group(1), validate=True)
    assert len(der) == 294 and der.startswith(bytes.fromhex("30820122")), "RSA public key encoding"
    checks.append("Public protocol key encoding (no private capture required)")

    profile = read(ROOT / "build-profile.json5")
    product = profile["app"]["products"][0]
    assert product["targetSdkVersion"] == "26.0.0", "Target SDK"
    assert product["compatibleSdkVersion"] == "6.0.2(22)", "Minimum SDK"
    assert profile["app"]["signingConfigs"] == [], "Personal signing config must not be published"
    assert all(not item.get("signingConfig") for item in profile["app"]["products"]), "Signing binding"
    app = read(ROOT / "AppScope/app.json5")["app"]
    assert app["bundleName"] == "com.haohaoai0.aifadian", "Application identity"
    module = read(ROOT / "entry/src/main/module.json5")["module"]
    assert {item["name"] for item in module["requestPermissions"]} == {
        "ohos.permission.INTERNET", "ohos.permission.GET_NETWORK_INFO"
    }, "Review permission changes explicitly"
    checks.append("SDK bounds, unsigned public profile and minimal permissions")
    print(json.dumps({"passed": True, "checks": checks, "source_files": len(sources),
                      "runtime_verified": False}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
