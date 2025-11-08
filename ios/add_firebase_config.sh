#!/bin/bash

# Script to add GoogleService-Info.plist to Xcode project
# Run this script on macOS after opening the project in Xcode

echo "🔧 iOS Firebase Setup Script"
echo "============================"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script must be run on macOS"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is not installed"
    exit 1
fi

# Navigate to ios directory
cd "$(dirname "$0")"
IOS_DIR=$(pwd)

echo "📍 Working directory: $IOS_DIR"
echo ""

# Check if GoogleService-Info.plist exists
PLIST_PATH="$IOS_DIR/Runner/GoogleService-Info.plist"
if [ ! -f "$PLIST_PATH" ]; then
    echo "❌ Error: GoogleService-Info.plist not found at $PLIST_PATH"
    exit 1
fi

echo "✅ Found GoogleService-Info.plist at $PLIST_PATH"
echo ""

# Check if CocoaPods is installed
if ! command -v pod &> /dev/null; then
    echo "⚠️  Warning: CocoaPods is not installed"
    echo "   Install it with: sudo gem install cocoapods"
    echo ""
fi

echo "📋 Setup Instructions:"
echo "====================="
echo ""
echo "1. Install CocoaPods dependencies:"
echo "   cd $IOS_DIR"
echo "   pod install"
echo ""
echo "2. Open Xcode workspace (IMPORTANT: Use .xcworkspace, not .xcodeproj):"
echo "   open $IOS_DIR/Runner.xcworkspace"
echo ""
echo "3. In Xcode:"
echo "   a. Right-click on 'Runner' folder in Project Navigator"
echo "   b. Select 'Add Files to Runner...'"
echo "   c. Navigate to: $PLIST_PATH"
echo "   d. Make sure 'Copy items if needed' is UNCHECKED"
echo "   e. Make sure 'Add to targets: Runner' is CHECKED"
echo "   f. Click 'Add'"
echo ""
echo "4. Verify the file is added:"
echo "   - Check Project Navigator for GoogleService-Info.plist"
echo "   - Verify it's in Build Phases > Copy Bundle Resources"
echo ""
echo "5. Build and test:"
echo "   flutter clean"
echo "   flutter pub get"
echo "   flutter run -d ios"
echo ""
echo "✅ Setup guide created: IOS_FIREBASE_SETUP.md"
echo ""

