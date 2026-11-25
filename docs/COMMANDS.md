# SmartGym Commands Cheat Sheet

## Environments

| Environment | Firebase Project | Git Branch | Android App ID |
| --- | --- | --- | --- |
| **Staging (Test)** | `smartgym-os-staging` | `staging` | `com.smartgym.partner.staging` |
| **Prod (Live)** | `smartgym-os` | `main` | `com.smartgym.partner` |

## 1. One-Time Staging Setup

| Step | What to Do / Command |
| --- | --- |
| Enable Phone OTP | Firebase Console (`smartgym-os-staging`) → **Authentication → Sign-in method → Phone → Enable** |
| Get Debug SHA-1 | `cd android && ./gradlew signingReport && cd ..` *(add SHA-1 under Android app in Staging Console)* |
| Sync Branches | `git push -u origin main staging && git checkout staging` |

## 2. Run Apps

| Target | `./gym` Command | `make` Shortcut |
| --- | --- | --- |
| Staging — Owner (Android) | `./gym run --staging` | `make staging` |
| Staging — Customer (Android) | `./gym run --staging --customer` | `make staging-customer` |
| Staging — Owner (iPhone/iOS) | `./gym run --staging --ios` | `make staging-ios` |
| Staging — Customer (iPhone/iOS) | `./gym run --staging --customer --ios` | `make staging-customer-ios` |
| Prod — Owner (Android) | `./gym run --prod` | `make prod` |
| Prod — Customer (Android) | `./gym run --prod --customer` | `make prod-customer` |
| Prod — Owner (iPhone/iOS) | `./gym run --prod --ios` | `make prod-ios` |
| Prod — Customer (iPhone/iOS) | `./gym run --prod --customer --ios` | `make prod-customer-ios` |

## 3. Create Builds (Test & Release)

| Build Type | Command | Notes |
| --- | --- | --- |
| Staging Owner Test APK | `./gym build apk --staging` | Output: `build/app/outputs/flutter-apk/` |
| Staging Customer Test APK | `./gym build apk --staging --customer` | Same as `make build-staging-customer` |
| Staging iOS Build | `./gym build ios --staging` | Add `--customer` for Customer iOS |
| Prod Owner APK | `./gym build apk --prod` | Runs analyze + tests first (`make build-prod`) |
| Prod Owner Play Store `.aab` | `./gym build aab --prod` | Needs release keystore in `build.gradle.kts` (`make build-prod-aab`) |
| Prod Customer APK / `.aab` | `./gym build apk --prod --customer` | Replace `apk` with `aab` for Play Store |
| Prod iOS Archive (`.ipa`) | `./gym build ipa --prod` | Add `--customer` for Customer IPA |

## 4. Push, Rules & Deploy (`Staging → Prod`)

| Action | `./gym` Command | `make` Shortcut |
| --- | --- | --- |
| Commit & push current branch | `./gym push` *(or `./gym push -m "msg"`)* | `make push` |
| Deploy Firestore rules → Staging | `./gym rules --staging` | `make rules-staging` |
| Deploy Firestore rules → Prod | `./gym rules --prod` | `make rules-prod` |
| **Promote Staging → Prod + Deploy + Build** | `./gym ship` *(or `./gym ship aab`)* | `make ship-prod` |
| Promote Customer Prod APK / `.aab` | `./gym ship --customer` *(or `aab --customer`)* | — |
