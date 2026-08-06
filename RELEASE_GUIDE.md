# Release Guide

This document explains how to create automatic releases for VerveStride.

## 🚀 Automatic Release Process

The GitHub Actions workflow automatically builds and releases your app for all platforms.

### How It Works:

1. **Push a version tag** to GitHub
2. GitHub Actions automatically:
   - Builds Android APK
   - Builds Windows EXE
   - Builds Linux bundle
   - Builds macOS app
   - Creates a GitHub Release
   - Uploads all files to the release

### Step-by-Step:

#### 1. Commit your changes
```bash
git add .
git commit -m "Release v1.0.0"
```

#### 2. Create and push a version tag
```bash
git tag v1.0.0
git push origin v1.0.0
```

**That's it!** GitHub Actions will handle the rest.

---

## 📦 What Gets Built:

- **Android**: `vervestride-v1.0.0.apk`
- **Windows**: `vervestride-windows-v1.0.0.zip`
- **Linux**: `vervestride-linux-v1.0.0.tar.gz`
- **macOS**: `vervestride-macos-v1.0.0.zip`

All files are automatically uploaded to:
```
https://github.com/nkgoldenshades/VerveStride/releases/tag/v1.0.0
```

---

## 🔗 Download Links (Auto-Generated):

After the workflow completes, your download links will be:

```
Android:
https://github.com/nkgoldenshades/VerveStride/releases/download/v1.0.0/vervestride-v1.0.0.apk

Windows:
https://github.com/nkgoldenshades/VerveStride/releases/download/v1.0.0/vervestride-windows-v1.0.0.zip

Linux:
https://github.com/nkgoldenshades/VerveStride/releases/download/v1.0.0/vervestride-linux-v1.0.0.tar.gz

macOS:
https://github.com/nkgoldenshades/VerveStride/releases/download/v1.0.0/vervestride-macos-v1.0.0.zip
```

---

## 🔄 Making New Releases:

Just create a new tag with the next version:

```bash
# For version 1.0.1
git tag v1.0.1
git push origin v1.0.1

# For version 1.1.0
git tag v1.1.0
git push origin v1.1.0

# For version 2.0.0
git tag v2.0.0
git push origin v2.0.0
```

Each tag triggers a new build and release automatically!

---

## 🛠️ Manual Trigger (Optional):

You can also manually trigger the workflow from GitHub:

1. Go to: `https://github.com/nkgoldenshades/VerveStride/actions`
2. Click "Build and Release"
3. Click "Run workflow"
4. Enter a tag name (e.g., `v1.0.0`)
5. Click "Run workflow"

---

## 📋 Workflow Status:

Check the build progress at:
```
https://github.com/nkgoldenshades/VerveStride/actions
```

---

## ⏱️ Build Time:

Typical build times:
- Android: ~5 minutes
- Windows: ~8 minutes
- Linux: ~6 minutes
- macOS: ~10 minutes
- **Total**: ~15-20 minutes (runs in parallel)

---

## 🎯 First Release:

To create your first release right now:

```bash
# Make sure all changes are committed
git add .
git commit -m "Prepare for v1.0.0 release"

# Create and push the tag
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

Then watch the magic happen at:
```
https://github.com/nkgoldenshades/VerveStride/actions
```

---

## 📝 Notes:

- Tags must start with `v` (e.g., `v1.0.0`, `v2.1.3`)
- Follows semantic versioning: `vMAJOR.MINOR.PATCH`
- Downloads page automatically uses these links
- GitHub Actions is free for public repositories
- Builds run in parallel for speed

---

## 🐛 Troubleshooting:

**Build fails?**
- Check the Actions tab for error logs
- Make sure all dependencies are in `pubspec.yaml`
- Verify Flutter version compatibility

**Release not created?**
- Check if tag was pushed: `git push origin v1.0.0`
- Verify workflow file exists: `.github/workflows/release.yml`
- Check GitHub Actions permissions in repository settings

---

## 🎉 Success!

Once the workflow completes, your release is live at:
```
https://github.com/nkgoldenshades/VerveStride/releases
```

And users can download directly from:
```
https://vervestrideai.com/downloads
```

No GitHub branding visible to users! ✨
