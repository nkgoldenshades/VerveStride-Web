VerveStride Downloads - R2 Upload Instructions
================================================

FOLDER: E:\vervestride\downloads-r2

This folder contains placeholder files with correct naming for R2 upload.

UPLOAD TO CLOUDFLARE R2:
========================

1. Go to: https://dash.cloudflare.com
2. Navigate to: R2 Object Storage
3. Open bucket: vervestride-downloads
4. Upload all 4 files from this folder:
   - vervestride-v1.0.0.apk
   - vervestride-windows-v1.0.0.zip
   - vervestride-macos-v1.0.0.zip
   - vervestride-linux-v1.0.0.tar.gz

5. In bucket Settings > Public Access > Custom Domains:
   - Add domain: downloads.vervestrideai.com
   - Wait for DNS to propagate (1-2 minutes)

6. Test downloads at:
   https://downloads.vervestrideai.com/vervestride-v1.0.0.apk
   https://downloads.vervestrideai.com/vervestride-windows-v1.0.0.zip
   https://downloads.vervestrideai.com/vervestride-macos-v1.0.0.zip
   https://downloads.vervestrideai.com/vervestride-linux-v1.0.0.tar.gz


REPLACING PLACEHOLDERS WITH REAL BUILDS:
=========================================

When you have a machine with proper build environment:

ANDROID (requires Android Studio):
----------------------------------
flutter build apk --release
File location: build/app/outputs/flutter-apk/app-release.apk
Rename to: vervestride-v1.0.0.apk
Replace in R2 bucket

WINDOWS (requires Visual Studio):
----------------------------------
flutter build windows --release
Zip folder: build/windows/runner/Release/
Rename to: vervestride-windows-v1.0.0.zip
Replace in R2 bucket

MACOS (requires Mac + Xcode):
------------------------------
flutter build macos --release
Zip: build/macos/Build/Products/Release/VerveStride.app
Rename to: vervestride-macos-v1.0.0.zip
Replace in R2 bucket

LINUX (requires Linux or WSL):
-------------------------------
flutter build linux --release
Create tar.gz: tar -czf vervestride-linux-v1.0.0.tar.gz -C build/linux/x64/release bundle
Upload to R2 bucket


NOTES:
======
- These are placeholder files for testing R2 setup
- Download links will work but files won't be installable until replaced
- R2 free tier: 10GB storage, 10M operations/month (enough for downloads)
- No GitHub exposure - clean professional URLs
- iOS not included (requires App Store submission)
