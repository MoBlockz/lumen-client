#!/bin/sh
# Builds build/LumenClient.dylib (arm64, iOS 15+). Needs macOS + Xcode (used by GitHub Actions).
set -e
cd "$(dirname "$0")"
mkdir -p build
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun -sdk iphoneos clang -arch arm64 -isysroot "$SDK" -miphoneos-version-min=15.0 \
  -fobjc-arc -O2 -Wall -Wno-deprecated-declarations -Wno-unused-function \
  -dynamiclib -install_name @executable_path/Frameworks/LumenClient.dylib \
  -framework Foundation -framework UIKit -framework QuartzCore -framework Metal \
  -framework GameController -framework CoreGraphics \
  src/*.m -o build/LumenClient.dylib
codesign -f -s - build/LumenClient.dylib
file build/LumenClient.dylib
ls -l build/LumenClient.dylib
