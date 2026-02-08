# Smart Food Expiry Tracker

Flutter + Firebase MVP for pantry expiry tracking with Gemini-powered scan extraction and recipe generation.

## Implemented

- Anonymous authentication
- Pantry CRUD (add via scan, edit, remove/archive)
- Sorting (expiry/name/recent)
- Camera/gallery scan + Gemini JSON autofill verification form
- Recipe generation from pantry via Gemini
- FCM token sync + scheduled expiry reminder function
- Firestore rules and index scaffold

## Flutter setup

1. `flutter pub get`
2. Configure Firebase for Android (`google-services.json`, Firebase project setup)
3. Run app: `flutter run`

## Android release signing (local APK)

1. Create a release keystore (example):
   - `keytool -genkey -v -keystore android/release-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`
2. Copy `android/keystore.properties.example` to `android/keystore.properties`.
3. Fill real values in `android/keystore.properties`.
4. Build signed release APK:
   - `flutter build apk --release`

If `android/keystore.properties` is missing, Gradle falls back to debug signing for release builds.

## Quick icon swap (tomorrow-ready)

1. Put assets in `assets/icons/`:
   - `app_icon.png`
   - `app_icon_foreground.png`
2. Generate launcher icons:
   - `dart run flutter_launcher_icons`
3. Rebuild:
   - `flutter build apk --release`

## Cloud Functions setup

1. `cd functions`
2. `npm install`
3. Create `.env` from `.env.example` and set:
   - `GEMINI_API_KEY`
   - `GEMINI_MODEL` (default: `gemini-3-flash-preview`)
4. Deploy:
   - `firebase deploy --only functions,firestore:rules,firestore:indexes`

## Notes

- Gemini API key is backend-only; do not add it to Flutter code.
- Scan results are always user-verifiable before pantry save.

## Public Repo Hygiene

- Do not commit local secret files:
  - `functions/.env`
  - `.vscode/.env`
  - `android/keystore.properties`
  - `android/release-keystore.jks`
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- Commit `functions/.env.example` only.
- Each contributor should create their own local secret/config files.

