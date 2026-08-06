# VerveStride - GitHub Redirect Setup (No Direct Download)

## 📌 Overview

```
User clicks "Download" 
    ↓
Redirect to GitHub Releases
    ↓
User downloads from GitHub directly
(Not from your server)
```

---

## 1️⃣ GITHUB RELEASES SETUP

### Create Release on GitHub

```
1. Go to: github.com/nkgoldenshades/vervestride/releases
2. Click "Create a new release"
3. Fill details:
   - Tag: v1.0.0
   - Title: VerveStride v1.0.0
   - Description: Release notes
   - Attach files:
     ├─ vervestride-android.apk
     ├─ vervestride-ios.ipa
     └─ vervestride-web.zip
4. Publish release
```

### GitHub Release URL Structure

```
https://github.com/nkgoldenshades/vervestride/releases/download/v1.0.0/vervestride-android.apk

Format:
https://github.com/{owner}/{repo}/releases/download/{tag}/{filename}
```

---

## 2️⃣ FRONTEND - REDIRECT TO GITHUB

### Option A: Simple Web Link

```dart
// lib/screens/download_screen.dart

import 'package:url_launcher/url_launcher.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  // GitHub release URLs
  static const String GITHUB_REPO = 'https://github.com/nkgoldenshades/vervestride';
  static const String RELEASES_PAGE = '$GITHUB_REPO/releases';
  
  static const String ANDROID_DOWNLOAD = '$GITHUB_REPO/releases/download/v1.0.0/vervestride-android.apk';
  static const String IOS_DOWNLOAD = '$GITHUB_REPO/releases/download/v1.0.0/vervestride-ios.ipa';
  static const String WEB_DOWNLOAD = '$GITHUB_REPO/releases/download/v1.0.0/vervestride-web.zip';

  Future<void> _openLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download VerveStride')),
      body: ListView(
        children: [
          // Android Download
          DownloadCard(
            title: 'Android',
            icon: Icons.android,
            description: 'APK for Android phones',
            onTap: () => _openLink(ANDROID_DOWNLOAD),
          ),
          
          // iOS Download
          DownloadCard(
            title: 'iPhone/iPad',
            icon: Icons.apple,
            description: 'iOS app for Apple devices',
            onTap: () => _openLink(IOS_DOWNLOAD),
          ),
          
          // Web Download
          DownloadCard(
            title: 'Web Version',
            icon: Icons.language,
            description: 'Download web build',
            onTap: () => _openLink(WEB_DOWNLOAD),
          ),
          
          // All Releases
          DownloadCard(
            title: 'All Releases',
            icon: Icons.history,
            description: 'View all versions on GitHub',
            onTap: () => _openLink(RELEASES_PAGE),
          ),
        ],
      ),
    );
  }
}

// Download Card Widget
class DownloadCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const DownloadCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Option B: Deep Link to GitHub Release

```dart
// lib/services/github_release_service.dart

import 'package:url_launcher/url_launcher.dart';

class GitHubReleaseService {
  static const String GITHUB_OWNER = 'nkgoldenshades';
  static const String GITHUB_REPO = 'vervestride';
  static const String REPO_URL = 
      'https://github.com/$GITHUB_OWNER/$GITHUB_REPO';

  /// Get latest release info from GitHub API
  static Future<Map<String, dynamic>> getLatestRelease() async {
    try {
      final url = 'https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        return {
          'version': json['tag_name'],  // e.g., v1.0.0
          'name': json['name'],
          'description': json['body'],
          'downloadUrl': '$REPO_URL/releases/download/${json['tag_name']}',
          'assets': json['assets'],  // List of files
        };
      }
    } catch (e) {
      debugPrint('Error fetching release info: $e');
    }
    
    return {};
  }

  /// Open GitHub releases page
  static Future<void> openReleasesPage() async {
    final Uri uri = Uri.parse('$REPO_URL/releases');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not open $uri';
    }
  }

  /// Open specific asset download
  static Future<void> downloadAsset(String assetUrl) async {
    final Uri uri = Uri.parse(assetUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not download $assetUrl';
    }
  }

  /// Open GitHub repo
  static Future<void> openGitHub() async {
    final Uri uri = Uri.parse(REPO_URL);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not open GitHub';
    }
  }
}
```

---

## 3️⃣ GITHUB ACTIONS - AUTO UPLOAD RELEASES

### Workflow: Auto-build & Upload to Releases

```yaml
# .github/workflows/release.yml

name: Build & Release

on:
  push:
    tags:
      - 'v*'  # Trigger on version tags like v1.0.0

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      # Checkout code
      - uses: actions/checkout@v3
      
      # Setup Flutter
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.13.0'
      
      # Get dependencies
      - run: flutter pub get
      
      # Build APK
      - name: Build Android APK
        run: flutter build apk --release
      
      # Build Web
      - name: Build Web
        run: flutter build web --release
      
      # Create Release
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            build/app/outputs/flutter-app.apk
            build/web/**/*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### How It Works

```
1. You tag a commit:
   git tag v1.0.0
   git push origin v1.0.0

2. GitHub Actions triggers

3. Builds APK, Web, iOS

4. Uploads to Releases automatically

5. Users can download from releases page
```

---

## 4️⃣ ENVIRONMENT SETUP

### pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  url_launcher: ^6.1.0
  http: ^1.1.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Add to main.dart

```dart
// lib/main.dart

import 'package:vervestride/screens/download_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VerveStride',
      home: Scaffold(
        appBar: AppBar(title: const Text('VerveStride')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadScreen()),
              );
            },
            child: const Text('Download'),
          ),
        ),
      ),
    );
  }
}
```

---

## 5️⃣ RELEASE CHECKLIST

### Before Tagging Release

```
✅ Update version in pubspec.yaml
✅ Update CHANGELOG.md
✅ Test on all platforms
✅ Update README.md
✅ Create GitHub release notes
```

### pubspec.yaml Version

```yaml
version: 1.0.0+1
  ↑ ↑ ↑
  | | └─ Build number
  | └─ Minor version
  └─ Major version
```

### Create Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push tag to GitHub
git push origin v1.0.0

# Or push all tags
git push origin --tags
```

---

## 6️⃣ GITHUB RELEASE PAGE STRUCTURE

```
VerveStride v1.0.0
─────────────────────────

Release Date: 2026-07-23
Latest Stable Version

📝 Release Notes:
• New AI chat features
• Improved form analysis
• Bug fixes
• Performance improvements

📥 Downloads:
├─ vervestride-android.apk       (45 MB)
├─ vervestride-ios.ipa            (120 MB)
└─ vervestride-web.zip            (85 MB)

🔗 Links:
├─ View on GitHub
├─ Compare with previous version
└─ View all releases

⭐ View source code
```

---

## 7️⃣ REDIRECT LINKS FOR SHARING

### Short Links

```
GitHub Releases:
https://github.com/nkgoldenshades/vervestride/releases

Latest Release:
https://github.com/nkgoldenshades/vervestride/releases/latest

Android APK:
https://github.com/nkgoldenshades/vervestride/releases/download/v1.0.0/vervestride-android.apk

iOS:
https://github.com/nkgoldenshades/vervestride/releases/download/v1.0.0/vervestride-ios.ipa

Web:
https://github.com/nkgoldenshades/vervestride/releases/download/v1.0.0/vervestride-web.zip
```

### Use Bit.ly or TinyURL for Short Links

```
Long: https://github.com/nkgoldenshades/vervestride/releases/download/v1.0.0/vervestride-android.apk
Short: https://bit.ly/vervestride-android
```

---

## 8️⃣ API ENDPOINT - GET LATEST RELEASE

```dart
// Fetch latest release info programmatically

Future<void> checkForUpdates() async {
  try {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/nkgoldenshades/vervestride/releases/latest'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      final latestVersion = data['tag_name'];  // "v1.0.0"
      final downloadUrl = data['html_url'];     // Release page URL

      debugPrint('Latest version: $latestVersion');
      debugPrint('Download: $downloadUrl');

      // Compare with current version
      // If newer, show update dialog
    }
  } catch (e) {
    debugPrint('Error checking updates: $e');
  }
}
```

---

## 9️⃣ COMPLETE DOWNLOAD FLOW

```
┌─────────────────────────────────────────────┐
│ USER CLICKS "DOWNLOAD"                      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ FRONTEND: Open GitHub Redirect              │
│ url_launcher.launchUrl(githubUrl)           │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ USER: Opens GitHub Releases Page in Browser │
└─────────────────────────────────────────────┘
                    ↓
        ┌─────────────┴─────────────┐
        │                           │
        ▼                           ▼
    Select Platform            Read Release Notes
    ├─ Android                  ├─ Features
    ├─ iOS                      ├─ Fixes
    └─ Web                      └─ Download info
        │                           │
        └─────────────┬─────────────┘
                      ▼
        ┌─────────────────────────────────────┐
        │ CLICK DOWNLOAD BUTTON               │
        │ (Browser downloads from GitHub CDN) │
        └─────────────────────────────────────┘
                      ↓
        ┌─────────────────────────────────────┐
        │ FILE SAVES TO DEVICE                │
        │ vervestride-android.apk             │
        └─────────────────────────────────────┘
                      ↓
        ┌─────────────────────────────────────┐
        │ USER INSTALLS APP                   │
        │ (From local file)                   │
        └─────────────────────────────────────┘
                      ✅ DONE
```

---

## 🔟 CODE SUMMARY

### Files to Create

```
lib/
├─ screens/
│  └─ download_screen.dart      ← Download UI
├─ services/
│  └─ github_release_service.dart  ← GitHub API
└─ main.dart                    ← Add download route

.github/
└─ workflows/
   └─ release.yml              ← Auto-build releases
```

### No Backend Needed!

```
✅ No server hosting required
✅ No bandwidth cost
✅ GitHub CDN handles downloads
✅ Automatic versioning
✅ Built-in release notes
✅ Users can verify files
✅ Open source transparency
```

---

## 🎯 BENEFITS

```
✅ Free hosting (GitHub)
✅ Unlimited downloads
✅ Fast CDN delivery
✅ Version history preserved
✅ Release notes per version
✅ Community contributions
✅ Transparent (open source)
✅ No storage costs
✅ Automatic backups
✅ Professional look
```

---

## Quick Setup Command

```bash
# 1. Create release
git tag v1.0.0
git push origin v1.0.0

# 2. Upload files manually (or use GitHub Actions)
# Go to: https://github.com/nkgoldenshades/vervestride/releases
# Click "Create release"
# Attach APK/iOS/Web files

# 3. Share link
https://github.com/nkgoldenshades/vervestride/releases/latest
```

