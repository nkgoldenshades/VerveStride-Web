# GitHub Actions - Build All Platforms

This workflow automatically builds VerveStride for all desktop platforms using GitHub's free cloud runners.

## 🚀 What Gets Built

- ✅ **Windows** (.zip) - ~50-80 MB
- ✅ **macOS** (.zip) - ~60-100 MB  
- ✅ **Linux** (.tar.gz) - ~40-70 MB
- ✅ **Android** (.apk) - ~103 MB

## 📋 How to Use

### Step 1: Push to GitHub

```bash
cd C:\vervestride
git add .
git commit -m "Add GitHub Actions build workflow"
git push origin main
```

### Step 2: Run the Workflow

1. Go to your GitHub repo: `https://github.com/nkgoldenshades/VerveStride`
2. Click the **Actions** tab at the top
3. Click on **Build All Desktop Platforms** workflow
4. Click **Run workflow** button (top right)
5. Click the green **Run workflow** button to confirm

### Step 3: Wait for Builds (~15-20 minutes)

The workflow will build all 4 platforms in parallel:
- Windows: ~10-15 minutes
- macOS: ~10-15 minutes
- Linux: ~5-10 minutes
- Android: ~8-12 minutes

You'll see progress for each platform in the Actions tab.

### Step 4: Download the Builds

Once completed (all green checkmarks):
1. Click on the completed workflow run
2. Scroll down to **Artifacts** section
3. Download each artifact:
   - `windows-build` → vervestride-windows-v1.0.0.zip
   - `macos-build` → vervestride-macos-v1.0.0.zip
   - `linux-build` → vervestride-linux-v1.0.0.tar.gz
   - `android-build` → vervestride-v1.0.0.apk

### Step 5: Upload to R2

1. Extract the downloaded artifacts
2. Upload each file to your R2 bucket:
   - `vervestride-windows-v1.0.0.zip` (replace placeholder)
   - `vervestride-macos-v1.0.0.zip` (replace placeholder)
   - `vervestride-linux-v1.0.0.tar.gz` (replace placeholder)
   - `vervestride-v1.0.0.apk` (replace placeholder if needed)

---

## 🔄 Automatic Builds

The workflow is configured to automatically run when you:
- Push changes to `main` branch
- Modify files in `lib/` folder
- Update `pubspec.yaml`
- Change the workflow file itself

You can also manually trigger it anytime from the Actions tab.

---

## 🆓 Cost

**FREE!** GitHub Actions provides:
- 2,000 minutes/month for free (public repos get unlimited)
- All 4 builds complete in ~20 minutes total
- You can run this ~100 times per month on free tier

---

## ⚠️ Note on Signing

These builds use debug signing for quick testing. For production:

### Android Production Signing:
Add your release keystore as GitHub Secrets:
- `ANDROID_KEYSTORE_BASE64` (base64 encoded keystore)
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

### macOS/Windows Code Signing:
For distribution outside app stores, you'll need:
- macOS: Apple Developer Certificate
- Windows: Code Signing Certificate

But for direct R2 downloads, the current builds work fine!

---

## 🎯 Next Steps After Build

1. ✅ Download all 4 artifacts from GitHub Actions
2. ✅ Upload to R2 bucket (replace placeholders)
3. ✅ Test downloads from `https://downloads.vervestrideai.com/`
4. ✅ Share with users!

---

## 📞 Troubleshooting

**Build fails on Windows?**
- Check if `dart:html` imports are properly conditionally imported
- Ensure `pwa_service.dart` uses conditional exports

**Build fails on macOS?**
- Check iOS-specific permissions in `Info.plist`
- Ensure CocoaPods dependencies are compatible

**Build fails on Linux?**
- Check if all native dependencies are listed
- Ensure no platform-specific imports without conditionals

**Build fails on Android?**
- Check `android/build.gradle.kts` for proper JVM targets
- Ensure all plugins support Android compilation

---

## ✨ Enjoy!

You now have automated builds for all platforms! Every time you push code, fresh builds are available within 20 minutes. 🚀
