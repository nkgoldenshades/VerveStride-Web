# Alarm Not Working - Diagnosis & Fix

## 🔍 Common Reasons Why Alarms Don't Work

### 1. **Android 12+ Exact Alarm Permission** (Most Common)
Starting from Android 12 (API 31), apps need **explicit user permission** to schedule exact alarms.

#### Check if Permission is Granted:
```dart
// In MainActivity.kt
alarmManager.canScheduleExactAlarms() // Returns false if permission denied
```

#### How to Request Permission:
The app must redirect users to system settings to grant this permission.

**Add to MainActivity.kt:**
```kotlin
import android.provider.Settings
import android.os.Build

// Check permission
"checkAlarmPermission" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        result.success(alarmManager.canScheduleExactAlarms())
    } else {
        result.success(true) // Always granted on older Android
    }
}

// Open settings to grant permission
"requestAlarmPermission" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
        startActivity(intent)
    }
    result.success(null)
}
```

**Add to Flutter (custom_reminder_service.dart):**
```dart
Future<bool> checkAlarmPermission() async {
  if (kIsWeb) return true;
  try {
    final hasPermission = await _platform.invokeMethod<bool>('checkAlarmPermission');
    return hasPermission ?? false;
  } catch (e) {
    return false;
  }
}

Future<void> requestAlarmPermission() async {
  if (kIsWeb) return;
  try {
    await _platform.invokeMethod('requestAlarmPermission');
  } catch (e) {
    debugPrint('Error requesting alarm permission: $e');
  }
}
```

---

### 2. **Battery Optimization Restrictions**
Android kills apps in the background to save battery, which prevents alarms from firing.

#### Solution: Request Battery Optimization Exemption
**Check AndroidManifest.xml** - Already has:
```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

**Add to MainActivity.kt:**
```kotlin
import android.os.PowerManager

"requestBatteryOptimizationExemption" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
    }
    result.success(null)
}
```

---

### 3. **Notification Channel Not Properly Configured**
Alarms require a high-importance notification channel.

#### Check Channel Configuration:
In `custom_reminder_service.dart`, the channel is already configured but might need adjustment:

```dart
final androidDetails = AndroidNotificationDetails(
  'reminders_alarm',  // ✅ Correct
  'Alarms',          // ✅ Correct
  importance: Importance.max,  // ✅ Correct
  priority: Priority.max,      // ✅ Correct
  fullScreenIntent: true,      // ✅ Correct - Shows over lock screen
  playSound: true,             // ✅ Correct
  enableVibration: true,       // ✅ Correct
  category: AndroidNotificationCategory.alarm,  // ✅ Correct
);
```

**This looks correct!** ✅

---

### 4. **Time is in the Past**
The code already handles this:
```dart
if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
  debugPrint('⚠️ Scheduled time is in the past, adjusting...');
  // If daily repeat, schedule for tomorrow
  if (reminder.repeat == 'daily') {
    final tomorrow = scheduledDate.add(const Duration(days: 1));
    await _scheduleNotificationAt(reminder, tomorrow, notificationId);
    return;
  }
  debugPrint('⚠️ Skipping past notification');
  return;
}
```

**This looks correct!** ✅

---

### 5. **App is Force-Stopped by User**
If a user force-stops the app from Settings, all alarms are canceled by Android.

#### Solution: BOOT_COMPLETED Receiver
**Check AndroidManifest.xml** - Already has:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<receiver android:name=".AlarmReceiver" .../>
```

**Need to add BOOT_COMPLETED handling** in AlarmReceiver.kt

---

## 🚀 Step-by-Step Fix

### Step 1: Add Alarm Permission Check UI

Create a dialog to request exact alarm permission from users:

**Add to `custom_reminder_service.dart`:**
```dart
Future<bool> ensureAlarmPermission(BuildContext context) async {
  if (kIsWeb) return true;
  
  final hasPermission = await checkAlarmPermission();
  if (hasPermission) return true;
  
  // Show dialog
  final shouldRequest = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Alarm Permission Required'),
      content: const Text(
        'VerveStride needs permission to schedule exact alarms. '
        'This ensures your workout reminders ring at the exact time you set.\n\n'
        'Tap "Grant Permission" to open system settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Grant Permission'),
        ),
      ],
    ),
  );
  
  if (shouldRequest == true) {
    await requestAlarmPermission();
    // Wait a bit and check again
    await Future.delayed(const Duration(seconds: 2));
    return await checkAlarmPermission();
  }
  
  return false;
}
```

**Call this before scheduling any alarm:**
```dart
Future<String> scheduleReminder({
  required String title,
  required String body,
  required DateTime scheduledTime,
  // ... other params
}) async {
  await _ensureInitialized();
  
  // NEW: Check alarm permission first
  if (!kIsWeb && alertType == 'alarm') {
    final hasPermission = await checkAlarmPermission();
    if (!hasPermission) {
      throw Exception('Exact alarm permission not granted. Please enable it in Settings.');
    }
  }
  
  // Continue with existing code...
}
```

---

### Step 2: Add Method Channel Handlers

**In `MainActivity.kt`, add these methods:**

```kotlin
"checkAlarmPermission" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        result.success(alarmManager.canScheduleExactAlarms())
    } else {
        result.success(true) // Permission not needed on older Android
    }
}

"requestAlarmPermission" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback for devices that don't support this intent
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }
    result.success(null)
}

"requestBatteryOptimizationExemption" -> {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("VerveStride", "Failed to request battery optimization exemption", e)
        }
    }
    result.success(null)
}
```

---

### Step 3: Add BOOT_COMPLETED Handler

**In `AlarmReceiver.kt`, add:**

```kotlin
override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
        "android.intent.action.BOOT_COMPLETED" -> {
            // Reschedule all alarms after device reboot
            // You'll need to implement this by reading stored reminders
            // and calling scheduleAlarm for each active one
            Log.d("VerveStride", "Device rebooted - rescheduling alarms")
        }
        else -> {
            // Existing alarm trigger code
            val alarmId = intent.getStringExtra("alarm_id") ?: return
            // ... rest of alarm trigger code
        }
    }
}
```

**Update AlarmReceiver registration in AndroidManifest.xml:**
```xml
<receiver
    android:name=".AlarmReceiver"
    android:enabled="true"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

---

## 🧪 Testing Checklist

### Test 1: Permission Check
1. Open app
2. Try to create an alarm
3. Should show permission dialog if not granted
4. Grant permission in settings
5. Try creating alarm again

### Test 2: Alarm Fires
1. Set alarm for 1 minute in future
2. Lock phone
3. Wait for alarm
4. Should see full-screen notification with alarm sound

### Test 3: Background Behavior
1. Set alarm for 5 minutes
2. Force-stop app from Settings
3. Wait for alarm time
4. ⚠️ **Won't work** - this is Android limitation
5. Reopen app → alarm reschedules

### Test 4: Reboot
1. Set alarm for future time
2. Reboot device
3. Alarm should still fire (once BOOT_COMPLETED is implemented)

---

## 📊 Debug Logs to Check

Look for these in logcat when setting an alarm:

```
✅ AlarmManager alarm scheduled for 2024-01-15 08:00:00.000
✅ Reminder scheduled: Morning Workout at 2024-01-15 08:00:00.000
```

If you see:
```
⚠️ AlarmManager schedule failed (will rely on notification tap): ...
```

This means the alarm permission is NOT granted or AlarmManager failed.

---

## 🎯 Most Likely Issue

**Android 12+ Exact Alarm Permission Not Granted**

**Quick Fix:**
1. Implement the permission check methods above
2. Show dialog when creating alarm
3. Direct user to settings to grant permission
4. Retry alarm scheduling

---

## 💡 Alternative: Use android_alarm_manager_plus Plugin

If the custom implementation is too complex, consider using:
```yaml
dependencies:
  android_alarm_manager_plus: ^3.0.4
```

This plugin handles all the permission management and complexity automatically.

---

## Summary

The code looks correct, but the **most likely issue** is:
- ✅ Android 12+ requires explicit "Schedule Exact Alarm" permission
- ✅ User hasn't granted this permission
- ✅ App needs to show dialog and redirect to settings

Implement Step 1 & 2 above to fix this!
