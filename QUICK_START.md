# 🚀 Quick Firebase Setup - 5 Minutes

## What You Need to Do:

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Create a project** (or use existing)
3. **Add Android app**:
   - Package: `com.example.level_up_app`
   - Download `google-services.json` → Place in `android/app/`
4. **Add iOS app**:
   - Bundle ID: `com.example.levelUpSport`
   - Download `GoogleService-Info.plist` → Place in `ios/Runner/`
5. **Enable Firestore**:
   - Go to Firestore Database
   - Click "Create database"
   - Start in test mode
6. **Done!** Run the app and events will sync across devices

## ⚠️ Important:

The placeholder files I created (`google-services.json` and `GoogleService-Info.plist`) MUST be replaced with the actual files from Firebase Console. The app will NOT work with placeholder files.

## Verify Setup:

After adding the files, run:
```bash
flutter clean
flutter pub get
flutter run
```

Check console for: ✅ "Firebase initialized successfully"

## Need Help?

See `FIREBASE_SETUP.md` for detailed instructions.

