# VerveStride - Cloudflare Direct Download (No Redirect)

## 📌 Overview

```
User clicks "Download"
    ↓
Direct download from Cloudflare CDN
    ↓
Files served from Cloudflare (fast, global)
    ↓
No redirects, no GitHub
```

---

## 1️⃣ CLOUDFLARE SETUP

### Create Cloudflare Account

```
1. Go to cloudflare.com
2. Sign up
3. Add domain: vervestrideai.com
4. Update nameservers to Cloudflare
```

### Create Bucket for Downloads

```
In Cloudflare Dashboard:
1. Go to R2 (Object Storage)
2. Create bucket: "vervestride-downloads"
3. Set permissions: Public read access
```

### Bucket Structure

```
vervestride-downloads/
├─ v1.0.0/
│  ├─ vervestride-android-v1.0.0.apk
│  ├─ vervestride-ios-v1.0.0.ipa
│  └─ vervestride-web-v1.0.0.zip
├─ v1.1.0/
│  ├─ vervestride-android-v1.1.0.apk
│  ├─ vervestride-ios-v1.1.0.ipa
│  └─ vervestride-web-v1.1.0.zip
└─ latest/
   ├─ android → symlink to latest APK
   ├─ ios → symlink to latest IPA
   └─ web → symlink to latest ZIP
```

---

## 2️⃣ CLOUDFLARE R2 API SETUP

### Get API Tokens

```
1. Cloudflare Dashboard → Account Settings
2. Go to API Tokens
3. Create token with R2 permissions:
   ├─ Read: Object in R2
   ├─ Write: Object in R2
   └─ List: Bucket contents
4. Copy token & save securely
```

### Environment Variables

```bash
# .env (Never commit to git!)
CLOUDFLARE_ACCOUNT_ID=xxxxxxxxxxxx
CLOUDFLARE_API_TOKEN=xxxxxxxxxxxx
CLOUDFLARE_BUCKET_NAME=vervestride-downloads
CLOUDFLARE_CUSTOM_DOMAIN=https://downloads.vervestrideai.com
```

---

## 3️⃣ BACKEND - UPLOAD TO CLOUDFLARE

### Cloud Function: Upload File

```javascript
// Firebase Cloud Function: uploadToCloudflare

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

const CLOUDFLARE_ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID;
const CLOUDFLARE_API_TOKEN = process.env.CLOUDFLARE_API_TOKEN;
const CLOUDFLARE_BUCKET = process.env.CLOUDFLARE_BUCKET_NAME;
const CLOUDFLARE_DOMAIN = process.env.CLOUDFLARE_CUSTOM_DOMAIN;

exports.uploadBuildToCloudflare = functions.https.onCall(async (data, context) => {
  // Only admin can upload
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { filePath, fileName, version, platform } = data;
  // Example: 
  // filePath = '/tmp/vervestride-android.apk'
  // fileName = 'vervestride-android-v1.0.0.apk'
  // version = '1.0.0'
  // platform = 'android' | 'ios' | 'web'

  try {
    // 1. Read file from local storage
    const fileData = fs.readFileSync(filePath);

    // 2. Upload to Cloudflare R2
    const uploadUrl = `https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com/${CLOUDFLARE_BUCKET}/v${version}/${fileName}`;

    const response = await axios.put(uploadUrl, fileData, {
      headers: {
        'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
        'Content-Type': 'application/octet-stream',
      },
    });

    if (response.status === 200) {
      // 3. Create public URL
      const publicUrl = `${CLOUDFLARE_DOMAIN}/v${version}/${fileName}`;

      // 4. Save to Firestore
      await admin.firestore().collection('releases').doc(`v${version}`).update({
        [platform]: {
          fileName: fileName,
          downloadUrl: publicUrl,
          uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
          fileSize: fileData.length,
        }
      });

      console.log(`✅ Uploaded ${fileName} to Cloudflare R2`);

      return {
        success: true,
        downloadUrl: publicUrl,
        fileName: fileName,
        fileSize: fileData.length,
      };
    }
  } catch (error) {
    console.error('Upload failed:', error);
    throw new functions.https.HttpsError('internal', 'Upload failed: ' + error.message);
  }
});
```

### Get Cloudflare Download Link

```dart
// Fetch from Firestore
Future<Map<String, dynamic>> getDownloadLinks(String version) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('releases')
        .doc('v$version')
        .get();

    return {
      'android': doc.data()?['android']?['downloadUrl'],
      'ios': doc.data()?['ios']?['downloadUrl'],
      'web': doc.data()?['web']?['downloadUrl'],
    };
  } catch (e) {
    debugPrint('Error fetching download links: $e');
    return {};
  }
}
```

---

## 4️⃣ CLOUDFLARE CUSTOM DOMAIN

### Set Up Custom Domain

```
1. Cloudflare Dashboard → R2
2. Select bucket: vervestride-downloads
3. Settings → Custom Domain
4. Add domain: downloads.vervestrideai.com
5. Add SSL/TLS certificate (auto-managed by Cloudflare)
```

### Download URLs

```
Before custom domain:
https://xxxx.r2.cloudflarestorage.com/vervestride-downloads/v1.0.0/vervestride-android.apk

After custom domain (fast):
https://downloads.vervestrideai.com/v1.0.0/vervestride-android.apk
```

---

## 5️⃣ FRONTEND - DIRECT DOWNLOAD

### Download Service

```dart
// lib/services/cloudflare_download_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class CloudflareDownloadService {
  static const String LATEST_VERSION = 'latest';

  /// Get download links for a version
  static Future<Map<String, String?>> getDownloadLinks(String version) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('releases')
          .doc('v$version')
          .get();

      if (!doc.exists) {
        debugPrint('❌ Release not found: v$version');
        return {};
      }

      return {
        'android': doc.data()?['android']?['downloadUrl'] as String?,
        'ios': doc.data()?['ios']?['downloadUrl'] as String?,
        'web': doc.data()?['web']?['downloadUrl'] as String?,
      };
    } catch (e) {
      debugPrint('❌ Error fetching download links: $e');
      return {};
    }
  }

  /// Get latest version
  static Future<String> getLatestVersion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('current_version')
          .get();

      return doc.data()?['version'] ?? '1.0.0';
    } catch (e) {
      debugPrint('❌ Error fetching version: $e');
      return '1.0.0';
    }
  }

  /// Download file (open Cloudflare URL in browser)
  static Future<void> downloadFile(String url, String fileName) async {
    try {
      final Uri uri = Uri.parse(url);
      
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
      
      debugPrint('✅ Download started: $fileName from $url');
    } catch (e) {
      debugPrint('❌ Download failed: $e');
    }
  }

  /// Get file info
  static Future<Map<String, dynamic>> getFileInfo(String version, String platform) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('releases')
          .doc('v$version')
          .get();

      final data = doc.data();
      final platformData = data?[platform] ?? {};

      return {
        'fileName': platformData['fileName'],
        'downloadUrl': platformData['downloadUrl'],
        'fileSize': platformData['fileSize'],
        'uploadedAt': platformData['uploadedAt'],
      };
    } catch (e) {
      debugPrint('❌ Error fetching file info: $e');
      return {};
    }
  }
}
```

### Download Screen

```dart
// lib/screens/download_screen.dart

import 'package:flutter/material.dart';
import 'package:vervestride/services/cloudflare_download_service.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  late Future<Map<String, String?>> _downloadLinks;
  late Future<String> _latestVersion;

  @override
  void initState() {
    super.initState();
    _latestVersion = CloudflareDownloadService.getLatestVersion();
    _downloadLinks = _latestVersion.then((version) =>
        CloudflareDownloadService.getDownloadLinks(version));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download VerveStride'),
        centerTitle: true,
      ),
      body: FutureBuilder<String>(
        future: _latestVersion,
        builder: (context, versionSnapshot) {
          if (!versionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final version = versionSnapshot.data!;

          return FutureBuilder<Map<String, String?>>(
            future: _downloadLinks,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final links = snapshot.data!;

              return ListView(
                children: [
                  // Version info
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue.withOpacity(0.1),
                    child: Column(
                      children: [
                        const Text(
                          'Latest Version',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          version,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Android Download
                  if (links['android'] != null)
                    DownloadTile(
                      title: 'Android',
                      icon: Icons.android,
                      description: 'APK for Android phones',
                      downloadUrl: links['android']!,
                      fileName: 'VerveStride-v$version.apk',
                    ),

                  // iOS Download
                  if (links['ios'] != null)
                    DownloadTile(
                      title: 'iPhone/iPad',
                      icon: Icons.apple,
                      description: 'iOS app for Apple devices',
                      downloadUrl: links['ios']!,
                      fileName: 'VerveStride-v$version.ipa',
                    ),

                  // Web Download
                  if (links['web'] != null)
                    DownloadTile(
                      title: 'Web Version',
                      icon: Icons.language,
                      description: 'Download web build',
                      downloadUrl: links['web']!,
                      fileName: 'VerveStride-v$version.zip',
                    ),

                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Files are served from Cloudflare CDN for fast downloads worldwide.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Download Tile Widget
class DownloadTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final String downloadUrl;
  final String fileName;

  const DownloadTile({
    required this.title,
    required this.icon,
    required this.description,
    required this.downloadUrl,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: ElevatedButton.icon(
          onPressed: () async {
            await CloudflareDownloadService.downloadFile(
              downloadUrl,
              fileName,
            );
          },
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        ),
      ),
    );
  }
}
```

---

## 6️⃣ FIRESTORE STRUCTURE

### Release Document

```json
{
  "version": "1.0.0",
  "releaseDate": "2026-07-23T10:00:00Z",
  "android": {
    "fileName": "vervestride-android-v1.0.0.apk",
    "downloadUrl": "https://downloads.vervestrideai.com/v1.0.0/vervestride-android-v1.0.0.apk",
    "fileSize": 47358976,
    "uploadedAt": "2026-07-23T09:00:00Z"
  },
  "ios": {
    "fileName": "vervestride-ios-v1.0.0.ipa",
    "downloadUrl": "https://downloads.vervestrideai.com/v1.0.0/vervestride-ios-v1.0.0.ipa",
    "fileSize": 125829120,
    "uploadedAt": "2026-07-23T09:00:00Z"
  },
  "web": {
    "fileName": "vervestride-web-v1.0.0.zip",
    "downloadUrl": "https://downloads.vervestrideai.com/v1.0.0/vervestride-web-v1.0.0.zip",
    "fileSize": 89128960,
    "uploadedAt": "2026-07-23T09:00:00Z"
  }
}
```

### App Config

```json
{
  "current_version": "1.0.0",
  "min_version": "1.0.0",
  "update_required": false,
  "announcement": "Welcome to VerveStride!",
  "lastUpdated": "2026-07-23T10:00:00Z"
}
```

---

## 7️⃣ UPLOAD WORKFLOW

### Manual Upload

```bash
# 1. Build the app
flutter build apk --release
flutter build ios --release
flutter build web --release

# 2. Upload to Cloudflare (via Firebase Cloud Function)
# Call: uploadBuildToCloudflare({
#   filePath: 'build/app/outputs/flutter-app.apk',
#   fileName: 'vervestride-android-v1.0.0.apk',
#   version: '1.0.0',
#   platform: 'android'
# })

# 3. Update Firestore with download links

# 4. Update current_version in app_config
```

### Automated Upload (GitHub Actions)

```yaml
# .github/workflows/build-and-upload.yml

name: Build & Upload to Cloudflare

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      
      - run: flutter pub get
      - run: flutter build apk --release
      - run: flutter build web --release
      
      - name: Upload to Cloudflare
        run: |
          curl -X PUT \
            "https://${{ secrets.CLOUDFLARE_ACCOUNT_ID }}.r2.cloudflarestorage.com/${{ secrets.CLOUDFLARE_BUCKET }}/v${{ github.ref_name }}/vervestride-android.apk" \
            -H "Authorization: Bearer ${{ secrets.CLOUDFLARE_API_TOKEN }}" \
            -d @build/app/outputs/flutter-app.apk
```

---

## 8️⃣ DOWNLOAD FLOW

```
┌────────────────────────────────────────┐
│ USER OPENS DOWNLOAD SCREEN             │
└────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────┐
│ FETCH LATEST VERSION FROM FIRESTORE    │
│ app_config.current_version = "1.0.0"   │
└────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────┐
│ FETCH DOWNLOAD LINKS FROM FIRESTORE    │
│ releases/v1.0.0                        │
│ {                                      │
│   android: "https://downloads.../..." │
│   ios: "https://downloads.../..."     │
│   web: "https://downloads.../..."     │
│ }                                      │
└────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────┐
│ DISPLAY DOWNLOAD SCREEN                │
│ ├─ Android (Button)                    │
│ ├─ iOS (Button)                        │
│ └─ Web (Button)                        │
└────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────┐
│ USER TAPS DOWNLOAD BUTTON              │
└────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────┐
│ CLOUDFLARE CDN DELIVERS FILE           │
│ ✅ Direct download (no redirect)       │
│ ✅ Fast global CDN                     │
│ ✅ No GitHub, no external links        │
└────────────────────────────────────────┘
                    ✅ FILE DOWNLOADED
```

---

## 9️⃣ CLOUDFLARE SETTINGS

### Enable Caching

```
Cloudflare Dashboard → R2 → Settings
├─ Cache: Enabled
├─ TTL: 7 days
└─ Compress: Enabled (gzip, brotli)
```

### Security Settings

```
├─ Public read access: Enabled
├─ SSL/TLS: Automatic
├─ CORS: Enabled for downloads.vervestrideai.com
└─ Rate limiting: Enabled (1000 req/min per IP)
```

### Analytics

```
View stats:
├─ Total downloads
├─ Bandwidth used
├─ Popular files
├─ Geographic distribution
└─ Performance metrics
```

---

## 🔟 COST BREAKDOWN

```
Cloudflare R2 Pricing:
├─ Storage: $0.015/GB/month
├─ Upload: $0.005/million requests
├─ Download: $0.015/GB transferred
└─ API calls: Free (up to limit)

Example (1000 Android downloads, 50MB each):
├─ Storage: $0.015 × 50GB = $0.75/month
├─ Download: $0.015 × 50GB = $0.75/month
└─ Total: ~$1.50/month for 50GB storage + 50GB traffic

Very cheap! ✅
```

---

## 📋 SETUP CHECKLIST

```
✅ Create Cloudflare account
✅ Create R2 bucket: vervestride-downloads
✅ Generate API token
✅ Set up custom domain: downloads.vervestrideai.com
✅ Create Cloud Function: uploadBuildToCloudflare
✅ Set up Firestore schema for releases
✅ Create Flutter download screen
✅ Test download (Android, iOS, Web)
✅ Set up GitHub Actions for auto-upload
✅ Monitor analytics
```

---

## 🚀 QUICK COMMANDS

```bash
# Upload file to Cloudflare R2
curl -X PUT \
  "https://{account-id}.r2.cloudflarestorage.com/{bucket-name}/v1.0.0/vervestride-android.apk" \
  -H "Authorization: Bearer {api-token}" \
  --data-binary @build/app/outputs/flutter-app.apk

# Download from Cloudflare
curl -O https://downloads.vervestrideai.com/v1.0.0/vervestride-android.apk
```

---

## Summary

| Feature | Direct Cloudflare |
|---------|------------------|
| **Download Speed** | ⚡⚡⚡ Very fast (global CDN) |
| **Cost** | 💰 ~$1-2/month for typical usage |
| **Redirect** | ❌ No (direct from Cloudflare) |
| **GitHub** | ❌ No (files stored in R2) |
| **Control** | ✅ Full control |
| **Custom Domain** | ✅ downloads.vervestrideai.com |
| **Analytics** | ✅ Built-in |
| **Reliability** | ✅ 99.99% uptime |

