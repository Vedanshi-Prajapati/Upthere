# Upthere — Project Guide & Agent Instructions

This document provides project-specific context and conventions to ensure commands, tests, and code changes are executed correctly.

---

## 1. Project Identifiers & Entitlements

Always use these exact identifiers (do not guess or abbreviate without `app` suffix):

- **Main App Bundle Identifier**: `com.vedanshi.upthereapp`
- **App Group Identifier**: `group.com.vedanshi.upthereapp`
  - Defined in: `Shared/AppGroup.swift`
  - Entitlements: `UpthereWidgets/UpthereWidgets.entitlements`
- **Widget Target Bundle Identifier**: `com.vedanshi.upthereapp.UpthereWidgets`

---

## 2. Simulator & CLI Conventions

### Reading App Group Preferences
To inspect or read shared `UserDefaults` on a booted simulator, always target the exact group identifier:
```bash
xcrun simctl spawn booted defaults read group.com.vedanshi.upthereapp 2>/dev/null || echo "Defaults domain empty or not initialized yet"
```

### Launching App for UI Screenshots / Manual Testing
When launching the app via `simctl`, use the debug flags to bypass splash/permissions and load mock data:
```bash
xcrun simctl launch booted com.vedanshi.upthereapp -useMockRepository -disableSplash -disablePermission -initialTab <home|forecast|insights|locations|settings>
```

#### Forcing Sky Scene for Testing / Screenshots
Use the `-skyScene` debug flag to override the background sky scene:
```bash
xcrun simctl launch booted com.vedanshi.upthereapp -useMockRepository -disableSplash -disablePermission -skyScene <clearDay|clearNight|partlyCloudyDay|partlyCloudyNight|cloudy|fog|haze|rain|thunderstorm|snow>
```


### Automated Hierarchy Screenshots
Use the helper script instead of running manual sequential commands:
```bash
python3 scripts/capture_hierarchy.py [before|after]
```

---

## 3. Design System & Typography Tokens

- Centralized theme tokens are located in: `Upthere/App/AppTheme.swift`
- **Typography Scale**: Use the 5-role scale via `.appType(...)` or `AppFont.role(...)`:
  - `.hero` (temperature display)
  - `.title` (screen & section headers)
  - `.headline` (card titles & key values)
  - `.body` (reading text)
  - `.caption` (secondary metadata, timestamps, units)
- **Spacing Tokens**:
  - `AppTheme.sectionGap` (28pt)
  - `AppTheme.cardInnerGap` (12pt)
  - `AppTheme.screenHorizontalMargin` (20pt)
