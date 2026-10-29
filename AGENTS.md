# Aifadian HarmonyOS engineering rules

- ArkTS / ArkUI V1, imports first, named data types; no any, unknown, destructuring, dynamic object fields or advanced TS types.
- Use devecocli for docs, build, devices, install and logs.
- Target API 26, minimum API 22. Gate newer material APIs at the call site in utils/Platform.ets.
- HdsNavigation owns navigation and system bars. Use HdsNavDestination and the provided NavPathStack.
- Keep models, services, components, pages and platform utilities separate.
- Strings in base, zh_CN and en_US; colors in base and dark. Prefer native controls and semantic system symbols.
- Use window vp measurements and 600/840 thresholds for list layout; unregister listeners and invalidate stale async work.
- API paths must come from observed contracts. Never fabricate results, unlock paid content, log credentials or fall back to plaintext credential requests.
- Send credentials only to the explicitly configured HTTPS API origins. Write WebView cookies only to the explicit origins in AppStore. No generic JavaScript bridge.
- Keep signing material, local paths, real accounts, captures, screenshots, logs and personal data out of Git.
- Run the offline checks documented in README before publishing. Keep copyright notices and attribution.
- Preserve unrelated user changes. Do not reset, publish or push without the user's request.
- Report compilation, signing, installation and runtime acceptance separately. An unsigned HAP is not installable device proof.
