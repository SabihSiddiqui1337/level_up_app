# iOS Firebase Setup Guide

## Current Status
✅ Firebase packages installed (`firebase_core`, `firebase_auth`, `cloud_firestore`)
✅ `GoogleService-Info.plist` file exists at `ios/Runner/GoogleService-Info.plist`
✅ Firebase initialized in `main.dart`
✅ Bundle ID matches: `com.example.levelUpSport`
⚠️ **Need to install CocoaPods dependencies** (requires macOS/Xcode)
⚠️ **Need to add GoogleService-Info.plist to Xcode project**

## Step-by-Step Setup Instructions

### Prerequisites
- macOS computer with Xcode installed
- CocoaPods installed (`sudo gem install cocoapods`)

### Step 1: Install CocoaPods Dependencies

On macOS, open Terminal and navigate to your project:

```bash
cd /path/to/level_up_app/ios
pod install
```

This will install all Firebase iOS dependencies (FirebaseCore, FirebaseAuth, FirebaseFirestore, etc.)

**Expected output:**
```
Analyzing dependencies
Downloading dependencies
Installing FirebaseAuth (X.X.X)
Installing FirebaseCore (X.X.X)
Installing FirebaseFirestore (X.X.X)
...
Generating Pods project
```

### Step 2: Add GoogleService-Info.plist to Xcode Project

1. Open Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
   ⚠️ **Important**: Always open `.xcworkspace`, not `.xcodeproj`

2. In Xcode:
   - Right-click on the `Runner` folder in the Project Navigator (left sidebar)
   - Select "Add Files to Runner..."
   - Navigate to `ios/Runner/GoogleService-Info.plist`
   - **Important**: Make sure "Copy items if needed" is **UNCHECKED** (file already exists)
   - Make sure "Add to targets: Runner" is **CHECKED**
   - Click "Add"

3. Verify the file is added:
   - The `GoogleService-Info.plist` should appear in the Project Navigator
   - Click on it to verify it's properly configured
   - Make sure it shows up in the "Runner" target under "Build Phases" > "Copy Bundle Resources"

### Step 3: Verify Bundle ID

1. In Xcode, select the "Runner" project in the Project Navigator
2. Select the "Runner" target
3. Go to "Signing & Capabilities" tab
4. Verify the Bundle Identifier is: `com.example.levelUpSport`
5. This should match the `BUNDLE_ID` in `GoogleService-Info.plist`

### Step 4: Build and Test

1. Clean the build:
   ```bash
   flutter clean
   flutter pub get
   ```

2. Build for iOS:
   ```bash
   flutter build ios --no-codesign
   ```
   Or run directly on a simulator/device:
   ```bash
   flutter run -d ios
   ```

3. Check the console logs for:
   ```
   ✅ Firebase initialized successfully
   ```

### Step 5: Troubleshooting

#### If you see "No Firebase App '[DEFAULT]' has been created":
- Verify `GoogleService-Info.plist` is added to Xcode project
- Verify it's included in "Copy Bundle Resources"
- Run `flutter clean` and rebuild

#### If CocoaPods installation fails:
```bash
cd ios
pod deintegrate
pod install
```

#### If build fails with Firebase errors:
1. Make sure you opened `.xcworkspace`, not `.xcodeproj`
2. Verify all pods are installed: `pod install`
3. Clean derived data in Xcode: Product > Clean Build Folder

#### If GoogleService-Info.plist is not found:
- Verify the file exists at `ios/Runner/GoogleService-Info.plist`
- Make sure it's added to the Xcode project (not just in the file system)
- Check file permissions

### Step 6: Verify Firebase Configuration

The `GoogleService-Info.plist` should contain:
- `API_KEY`: AIzaSyAFyGkWjIrVHjCFEovUE8T5WuPxC20N_Ao
- `BUNDLE_ID`: com.example.levelUpSport
- `PROJECT_ID`: levelupsports-1014f
- `GOOGLE_APP_ID`: 1:779252114785:ios:a0f793440a748ea59c1120

### Alternative: Using Flutter's Automatic Pod Installation

Flutter can automatically install pods when building, but you still need to:
1. Add `GoogleService-Info.plist` to Xcode project (Step 2)
2. The first build will take longer as it installs pods

## Quick Checklist

- [ ] CocoaPods installed on macOS
- [ ] Ran `pod install` in `ios/` directory
- [ ] Opened `Runner.xcworkspace` (not `.xcodeproj`)
- [ ] Added `GoogleService-Info.plist` to Xcode project
- [ ] Verified Bundle ID matches: `com.example.levelUpSport`
- [ ] Built and tested the app
- [ ] Verified Firebase initialization in console logs

## Current Configuration

### Firebase Options (from `lib/firebase_options.dart`):
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyAFyGkWjIrVHjCFEovUE8T5WuPxC20N_Ao',
  appId: '1:779252114785:ios:a0f793440a748ea59c1120',
  messagingSenderId: '779252114785',
  projectId: 'levelupsports-1014f',
  storageBucket: 'levelupsports-1014f.firebasestorage.app',
  iosBundleId: 'com.example.levelUpSport',
);
```

### GoogleService-Info.plist Location:
- File: `ios/Runner/GoogleService-Info.plist`
- Bundle ID: `com.example.levelUpSport`
- Project ID: `levelupsports-1014f`

## Next Steps

Once setup is complete:
1. Test Firebase Auth functionality
2. Test Firestore read/write operations
3. Verify password reset emails work
4. Test on a physical iOS device (if needed)

## Notes for Windows Users

Since CocoaPods requires macOS:
1. Use a Mac for iOS development, or
2. Use a macOS virtual machine, or
3. Use a CI/CD service that supports macOS, or
4. Use Flutter's build system which will handle pods automatically (still need Xcode for adding the plist file)

The `GoogleService-Info.plist` file must be added to the Xcode project manually - this cannot be done from Windows.

