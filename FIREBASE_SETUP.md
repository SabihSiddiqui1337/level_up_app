# Firebase Setup Guide for Level Up Sports App

This guide will help you set up Firebase for cross-device event synchronization.

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Enter project name: "Level Up Sports" (or any name you prefer)
4. Follow the setup wizard (Google Analytics is optional)
5. Click "Create project"

## Step 2: Add Android App to Firebase

1. In Firebase Console, click the Android icon (or "Add app" > Android)
2. **Package name**: `com.example.level_up_app`
   - (You can find this in `android/app/build.gradle.kts` under `applicationId`)
3. **App nickname** (optional): "Level Up Sports Android"
4. **Debug signing certificate SHA-1** (optional for now): You can skip this
5. Click "Register app"
6. Download `google-services.json`
7. **Place the file here**: `android/app/google-services.json`
   - Make sure it's directly in the `android/app/` folder, not in a subfolder

## Step 3: Add iOS App to Firebase

1. In Firebase Console, click the iOS icon (or "Add app" > iOS)
2. **Bundle ID**: `com.example.levelUpSport`
   - ✅ This is already configured in your project
3. **App nickname** (optional): "Level Up Sports iOS"
4. Click "Register app"
5. Download `GoogleService-Info.plist`
6. **Place the file here**: `ios/Runner/GoogleService-Info.plist`

## Step 4: Verify Configuration

### Android
- ✅ `android/app/google-services.json` exists
- ✅ `android/build.gradle.kts` has Google Services classpath
- ✅ `android/app/build.gradle.kts` has Google Services plugin

### iOS
- ✅ `ios/Runner/GoogleService-Info.plist` exists

## Step 5: Enable Firestore Database

1. In Firebase Console, go to "Build" > "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development)
   - ⚠️ **Important**: For production, you'll need to set up security rules
4. Choose a location (closest to your users)
5. Click "Enable"

## Step 6: Set Up Firestore Security Rules (Important!)

1. Go to Firestore Database > Rules
2. For testing, use these rules (⚠️ NOT for production):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

3. For production, you should implement proper security rules based on user roles.

## Step 7: Test the Setup

1. Run the app: `flutter run`
2. Check the console logs for:
   - ✅ "Firebase initialized successfully"
   - ✅ No "No Firebase App" errors
3. Create an event on one device
4. Pull to refresh on another device
5. The event should appear on both devices!

## Troubleshooting

### "No Firebase App '[DEFAULT]' has been created"
- Make sure `google-services.json` is in `android/app/`
- Make sure `GoogleService-Info.plist` is in `ios/Runner/`
- Run `flutter clean` and `flutter pub get`
- Restart the app

### Events not syncing
- Check Firebase Console > Firestore Database to see if events are being created
- Check console logs for Firebase errors
- Verify internet connection on both devices

### Build errors
- Make sure you've run `flutter pub get`
- Check that `google-services.json` is valid JSON
- For iOS: Make sure `GoogleService-Info.plist` is added to Xcode project

## Current Status

- ✅ Code is configured for Firebase
- ✅ Gradle files are set up
- ⏳ Waiting for: `google-services.json` and `GoogleService-Info.plist` files

Once you add the configuration files, Firebase will work automatically!

