# iOS Firebase Setup - Current Status

## ✅ What's Already Done

1. **Firebase Packages**: Installed in `pubspec.yaml`
   - `firebase_core: ^3.6.0`
   - `firebase_auth: ^5.3.1`
   - `cloud_firestore: ^5.4.5`

2. **Firebase Configuration File**: 
   - ✅ `GoogleService-Info.plist` exists at `ios/Runner/GoogleService-Info.plist`
   - ✅ Contains correct configuration for project `levelupsports-1014f`
   - ✅ Bundle ID matches: `com.example.levelUpSport`

3. **Firebase Options**: 
   - ✅ `lib/firebase_options.dart` has iOS configuration
   - ✅ iOS bundle ID: `com.example.levelUpSport`

4. **Firebase Initialization**:
   - ✅ Firebase is initialized in `main.dart` using `DefaultFirebaseOptions.currentPlatform`

5. **Bundle ID Verification**:
   - ✅ Xcode project has bundle ID: `com.example.levelUpSport`
   - ✅ Matches Firebase config

## ⚠️ What Needs to Be Done (Requires macOS/Xcode)

### 1. Install CocoaPods Dependencies

On macOS, run:
```bash
cd ios
pod install
```

This will install Firebase iOS SDK pods:
- FirebaseCore
- FirebaseAuth
- FirebaseFirestore
- And their dependencies

### 2. Add GoogleService-Info.plist to Xcode Project

**Critical Step**: The file exists in the filesystem but needs to be added to the Xcode project.

**Steps**:
1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
   ⚠️ **Important**: Always use `.xcworkspace`, never `.xcodeproj`

2. In Xcode Project Navigator:
   - Right-click on `Runner` folder
   - Select "Add Files to Runner..."
   - Navigate to `ios/Runner/GoogleService-Info.plist`
   - **Uncheck** "Copy items if needed" (file already exists)
   - **Check** "Add to targets: Runner"
   - Click "Add"

3. Verify:
   - File appears in Project Navigator
   - File is listed in "Build Phases" > "Copy Bundle Resources"

## 📋 Quick Setup Checklist

- [x] Firebase packages in pubspec.yaml
- [x] GoogleService-Info.plist file exists
- [x] Firebase options configured
- [x] Firebase initialized in main.dart
- [x] Bundle ID matches
- [ ] CocoaPods dependencies installed (`pod install`)
- [ ] GoogleService-Info.plist added to Xcode project
- [ ] App builds and runs successfully
- [ ] Firebase initializes without errors

## 🔍 Verification

After completing the setup, verify:

1. **Build the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter build ios --no-codesign
   ```

2. **Check console logs** for:
   ```
   ✅ Firebase initialized successfully
   ```

3. **Test Firebase Auth**:
   - Try password reset functionality
   - Verify it works with Firebase

## 🐛 Troubleshooting

### "No Firebase App '[DEFAULT]' has been created"
- **Solution**: Make sure `GoogleService-Info.plist` is added to Xcode project and included in "Copy Bundle Resources"

### CocoaPods installation fails
- **Solution**: 
  ```bash
  cd ios
  pod deintegrate
  pod install
  ```

### Build fails
- **Solution**: Make sure you opened `.xcworkspace`, not `.xcodeproj`

### GoogleService-Info.plist not found at runtime
- **Solution**: The file must be added to Xcode project, not just exist in the filesystem

## 📝 Files Reference

### Configuration Files:
- `ios/Runner/GoogleService-Info.plist` - Firebase iOS config
- `lib/firebase_options.dart` - FlutterFire options
- `ios/Podfile` - CocoaPods configuration
- `ios/Runner.xcodeproj/project.pbxproj` - Xcode project file

### Key Values:
- **Bundle ID**: `com.example.levelUpSport`
- **Project ID**: `levelupsports-1014f`
- **App ID**: `1:779252114785:ios:a0f793440a748ea59c1120`

## 🚀 Next Steps

1. **On macOS**, run the setup script or follow manual steps:
   ```bash
   cd ios
   ./add_firebase_config.sh
   ```

2. **Or manually**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Add `GoogleService-Info.plist` to project
   - Run `pod install` in Terminal
   - Build and test

## 📚 Additional Resources

- See `IOS_FIREBASE_SETUP.md` for detailed instructions
- See `FIREBASE_SETUP.md` for general Firebase setup
- Firebase iOS Documentation: https://firebase.google.com/docs/ios/setup

