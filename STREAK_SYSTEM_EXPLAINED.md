# Streak System - How It Works

**Date: May 27, 2026**

## 🔥 What is the Streak?

The streak tracks **consecutive days of completing your daily goals**.

## ✅ How to Earn a Streak

You must complete **BOTH** daily habits:

### 1. Movement Goal (100%)
- Burn your target calories
- Complete workouts/activities
- **Must reach 100%** of calorie goal

### 2. Hydration Goal (70%)
- Drink water throughout the day
- **Must reach 70%** of water goal

## 📊 Streak Logic

```dart
// From home_screen.dart line 416-421

const totalHabitsToday = 2;  // Movement + Hydration

final movementDone = burnPercent >= 0.999;  // 100% calories
final hydrationDone = waterPercent >= 0.70;  // 70% water

final completedHabits = (movementDone ? 1 : 0) + (hydrationDone ? 1 : 0);

// Streak increments when:
final isAllDone = completedHabits >= totalHabitsToday;  // Both done!
```

## 🎯 When Streak Increments

**Trigger:** When you complete BOTH habits (line 468)

```dart
if (isAllDone && !_completionCelebrated) {
  // Success haptic - celebrate!
  HapticService.instance.success();
  
  _incrementStreakOnCompletion();  // ← Streak increments here!
  
  // Show completion pulse animation
}
```

## 📅 Streak Rules

### ✅ Increment Streak:
- **First completion today:** Streak = 1
- **Completed yesterday + today:** Streak = 2
- **Completed 7 days in a row:** Streak = 7

### ❌ Reset Streak:
- **Miss a day:** Streak resets to 0
- **Only complete 1 habit:** Streak doesn't increment
- **Complete <100% movement:** Doesn't count
- **Complete <70% water:** Doesn't count

## 🔍 Where Streak is Stored

**Storage Keys:**
```dart
'streak_days' → Current streak count
'streak_last_active_day_key' → Last completion date (YYYYMMDD format)
```

**Example:**
```json
{
  "streak_days": 5,
  "streak_last_active_day_key": "20260527"
}
```

## 📱 Where Streak is Displayed

### Home Screen (line 577-598):
```dart
if (_streakDays > 0)
  Container(
    child: Text(
      '🔥 ${_streakDays}-day streak',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    ),
  ),
```

**Shows:** "🔥 5-day streak" badge below the progress ring

### Share Template:
- Shows streak when sharing progress
- Flame icon color changes based on streak length:
  - 🔥 Orange (1-6 days)
  - 🔥 Deep Orange (7-29 days)
  - 🔥 Gold (30+ days)

## 🎨 Visual Indicators

### 1. Streak Badge
- **Location:** Below progress ring on home screen
- **Format:** "🔥 X-day streak"
- **Color:** Primary color with subtle background
- **Visibility:** Only shows if `_streakDays > 0`

### 2. Flame Animation
- **Trigger:** When completing daily goals
- **Effect:** Growing flame animation around progress ring
- **Duration:** 1.5 seconds

### 3. Completion Pulse
- **Trigger:** When both habits completed
- **Effect:** Pulsing ring animation
- **Haptic:** Success vibration

## 🐛 Why Streak Might Not Show

### Issue 1: Not Completing Both Habits
```
Movement: 95% ❌ (need 100%)
Water: 80% ✅
Result: No streak increment
```

### Issue 2: Streak is 0
```
If you've never completed both habits, streak = 0
Badge only shows if streak > 0
```

### Issue 3: Missed Yesterday
```
Last completion: May 25
Today: May 27 (skipped May 26)
Result: Streak reset to 0
```

### Issue 4: Storage Not Loaded
```
If _loadStreakData() fails, streak shows as 0
Check console for errors
```

## 🧪 Testing the Streak

### Day 1:
1. Open app
2. Complete workout (reach 100% calories)
3. Drink water (reach 70% goal)
4. **Result:** "🔥 1-day streak" appears

### Day 2:
1. Open app (streak still shows "🔥 1-day streak")
2. Complete both habits again
3. **Result:** "🔥 2-day streak" appears

### Day 3 (Skip):
1. Open app
2. Don't complete habits
3. **Result:** Streak still shows "🔥 2-day streak"

### Day 4:
1. Open app
2. Complete both habits
3. **Result:** Streak resets to "🔥 1-day streak" (because Day 3 was skipped)

## 📝 Other Places Streak Increments

### 1. Activity Tracking (line 546):
```dart
await _storage.addActivity(payload);
await StreakService.markActiveToday();
```
**When:** Logging any activity/workout

### 2. Meal Logging (line 1458):
```dart
await StreakService.markActiveToday();
```
**When:** Logging a meal

**Note:** These also increment the streak, but the main trigger is completing both daily habits on the home screen.

## 🎯 Summary

**Streak = Consecutive days of completing BOTH:**
1. ✅ 100% movement goal (calories burned)
2. ✅ 70% hydration goal (water intake)

**Display:**
- Shows as "🔥 X-day streak" badge
- Only visible if streak > 0
- Resets if you miss a day

**Current Implementation:** ✅ Working as designed!

The streak is meant to be **earned** by completing your daily goals, not just by opening the app. This encourages consistent healthy habits! 💪
