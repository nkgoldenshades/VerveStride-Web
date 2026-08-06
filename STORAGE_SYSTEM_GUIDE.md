# 💾 Cloud Storage System - Complete Guide

## Overview

VerveStride now includes a **cloud storage tracking system** that monitors user data usage and enforces storage limits based on subscription tiers.

---

## 📊 Storage Limits by Tier

### Free Tier
- **Storage Limit**: 500MB
- **Best For**: Casual users with basic tracking
- **Includes**: Basic workout and meal logging

### Pro Tier
- **Storage Limit**: 5GB
- **Best For**: Active users with regular photo uploads
- **Includes**: All Free features + meal photos + advanced analytics

### Elite Tier
- **Storage Limit**: 20GB
- **Best For**: Power users with extensive data
- **Includes**: All Pro features + unlimited AI + live coaching

### Lifetime Tier
- **Storage Limit**: 50GB
- **Best For**: Long-term users who want maximum storage
- **Includes**: All Elite features forever

---

## 🎯 What Counts Toward Storage?

### Meal Photos
- **Average Size**: 2MB per photo
- **Usage**: Uploaded when analyzing meals with AI
- **Example**: 250 meal photos = 500MB (Free tier full)

### Workout Data
- **Average Size**: 50KB per workout
- **Usage**: Saved after each workout session
- **Example**: 10,000 workouts = 500MB

### Activity Data
- **Average Size**: 10KB per activity
- **Usage**: Daily activity tracking
- **Example**: 50,000 activities = 500MB

### Chat Messages
- **Average Size**: 1KB per message
- **Usage**: AI chat conversations
- **Example**: 500,000 messages = 500MB

---

## 📱 Where Storage is Displayed

### 1. Premium Screen
**Location**: Premium/Subscription screen
**Display**: Full storage widget with:
- Current usage (e.g., "2.5 GB / 5 GB")
- Usage percentage (e.g., "50%")
- Progress bar (color-coded)
- Tier label (e.g., "Pro (5GB)")
- Warning messages (when storage is low)
- Upgrade button (to get more storage)

### 2. Settings Screen (Optional)
**Location**: Settings > Account
**Display**: Compact storage indicator
- Shows usage percentage
- Tap to see details

### 3. Upload Dialogs (Optional)
**Location**: When uploading meal photos
**Display**: Warning if storage is low
- "Storage almost full! Upgrade to continue."

---

## 🎨 Visual Design

### Storage Widget (Premium Screen)

```
┌─────────────────────────────────────────┐
│  ☁️  Cloud Storage                      │
│      Pro (5GB)                          │
│                                         │
│  2.5 GB / 5 GB                    50%   │
│  ████████████░░░░░░░░░░░░░░░░░░░       │
│                                         │
│  ⓘ Storage running low. Consider       │
│     upgrading your plan.                │
│                                         │
│  [🔼 Upgrade to Elite (20GB)]           │
└─────────────────────────────────────────┘
```

### Color Coding
- **Green** (0-79%): Healthy storage usage
- **Orange** (80-94%): Warning - storage running low
- **Red** (95-100%): Critical - storage almost full

---

## 🔧 Implementation Details

### Service: `StorageTrackingService`

**Location**: `lib/services/storage_tracking_service.dart`

**Key Methods**:
```dart
// Load storage usage
await StorageTrackingService.instance.load();

// Add storage usage (e.g., upload photo)
final success = await StorageTrackingService.instance.addUsage(
  2 * 1024 * 1024, // 2MB
  description: 'Meal photo',
);

// Remove storage usage (e.g., delete photo)
await StorageTrackingService.instance.removeUsage(
  2 * 1024 * 1024,
  description: 'Meal photo deleted',
);

// Check if user has space
if (StorageTrackingService.instance.hasSpace(2 * 1024 * 1024)) {
  // Upload photo
} else {
  // Show upgrade prompt
}

// Get usage info
final usageString = StorageTrackingService.instance.usageString;
// "2.5 GB / 5 GB"

final usagePercent = StorageTrackingService.instance.usagePercent;
// 0.5 (50%)

final warningLevel = StorageTrackingService.instance.warningLevel;
// 0 = OK, 1 = Warning, 2 = Critical
```

### Widget: `StorageUsageWidget`

**Location**: `lib/widgets/storage_usage_widget.dart`

**Usage**:
```dart
// Full storage widget (Premium screen)
StorageUsageWidget(
  showUpgradeButton: true,
  onUpgrade: () {
    // Navigate to subscription plans
  },
)

// Compact indicator (App bar)
StorageIndicator(
  onTap: () {
    // Navigate to storage details
  },
)
```

---

## 📝 Integration Examples

### Example 1: Meal Photo Upload

```dart
// Before uploading photo
final storage = StorageTrackingService.instance;
final photoSize = 2 * 1024 * 1024; // 2MB

if (!storage.hasSpace(photoSize)) {
  // Show upgrade prompt
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Storage Full'),
      content: Text(
        'You need ${storage.remainingString} more storage.\n'
        'Upgrade to ${_getNextTier()} to continue.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, Routes.premium);
          },
          child: const Text('Upgrade'),
        ),
      ],
    ),
  );
  return;
}

// Upload photo
final bytes = await imageFile.readAsBytes();
await uploadToCloud(bytes);

// Track storage usage
await storage.addUsage(bytes.length, description: 'Meal photo');
```

### Example 2: Delete Meal Photo

```dart
// When user deletes a meal photo
final photoSize = 2 * 1024 * 1024; // 2MB

// Delete from cloud
await deleteFromCloud(photoId);

// Update storage tracking
await StorageTrackingService.instance.removeUsage(
  photoSize,
  description: 'Meal photo deleted',
);
```

### Example 3: Show Storage in Settings

```dart
// In settings screen
ListTile(
  leading: const Icon(Icons.cloud_outlined),
  title: const Text('Cloud Storage'),
  subtitle: Text(StorageTrackingService.instance.usageString),
  trailing: StorageIndicator(),
  onTap: () {
    // Navigate to storage details or premium screen
    Navigator.pushNamed(context, Routes.premium);
  },
)
```

---

## 🚀 Next Steps

### 1. Test Storage Display
- Open Premium screen
- Verify storage widget appears
- Check color coding (green/orange/red)
- Test upgrade button

### 2. Integrate with Photo Uploads
- Add storage check before meal photo upload
- Track storage usage after upload
- Show error if storage full

### 3. Integrate with Data Deletion
- Remove storage usage when deleting photos
- Remove storage usage when deleting workouts
- Update display in real-time

### 4. Add Storage Warnings
- Show warning when storage reaches 80%
- Show critical alert at 95%
- Prompt upgrade when full

---

## 📊 Storage Usage Estimates

### Typical User Scenarios

**Casual User (Free - 500MB)**
- 100 meal photos (200MB)
- 500 workouts (25MB)
- 1000 activities (10MB)
- 10,000 chat messages (10MB)
- **Total**: ~245MB (49% used)
- **Verdict**: ✅ Plenty of space

**Active User (Pro - 5GB)**
- 1000 meal photos (2GB)
- 5000 workouts (250MB)
- 10,000 activities (100MB)
- 50,000 chat messages (50MB)
- **Total**: ~2.4GB (48% used)
- **Verdict**: ✅ Comfortable space

**Power User (Elite - 20GB)**
- 5000 meal photos (10GB)
- 20,000 workouts (1GB)
- 50,000 activities (500MB)
- 200,000 chat messages (200MB)
- **Total**: ~11.7GB (59% used)
- **Verdict**: ✅ Good space

**Lifetime User (50GB)**
- 15,000 meal photos (30GB)
- 50,000 workouts (2.5GB)
- 100,000 activities (1GB)
- 500,000 chat messages (500MB)
- **Total**: ~34GB (68% used)
- **Verdict**: ✅ Excellent space

---

## 🎯 Benefits of Storage System

### For Users
1. **Transparency**: See exactly how much storage they're using
2. **Control**: Know when to upgrade or clean up data
3. **Value**: Understand what they get with each tier
4. **Peace of Mind**: No surprise "storage full" errors

### For Business
1. **Monetization**: Encourage upgrades for more storage
2. **Cost Control**: Limit free tier storage usage
3. **Scalability**: Plan infrastructure based on tier limits
4. **Differentiation**: Clear value proposition for each tier

---

## 🔒 Important Notes

### Storage is Local (For Now)
- Current implementation tracks storage **locally**
- Actual cloud storage integration requires backend
- This is a **tracking system** to prepare for cloud storage

### Future Enhancements
1. **Real Cloud Storage**: Integrate with Firebase Storage or AWS S3
2. **Automatic Cleanup**: Delete old data when storage is full
3. **Compression**: Compress photos to save space
4. **Selective Sync**: Let users choose what to sync
5. **Storage Analytics**: Show breakdown by data type

---

## ✅ Summary

The storage system is now **fully implemented** with:

✅ **Storage limits** for all tiers (500MB to 50GB)
✅ **Storage tracking** service with real-time updates
✅ **Storage widget** for Premium screen
✅ **Color-coded indicators** (green/orange/red)
✅ **Warning messages** when storage is low
✅ **Upgrade prompts** to get more storage
✅ **Integration ready** for photo uploads and data deletion

**Next Step**: Test the storage widget in the Premium screen!

---

**Last Updated**: April 20, 2026
**Status**: ✅ **READY FOR TESTING**
