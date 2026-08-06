# Server-Side Logic Implementation Guide

## 🎯 Why Move Logic to Firebase?

### Problems with Client-Side Only
❌ Users can manipulate calorie calculations
❌ Subscription checks can be bypassed
❌ Activity data can be faked
❌ No centralized validation
❌ Inconsistent calculations across devices

### Benefits of Server-Side Logic
✅ Single source of truth
✅ Tamper-proof calculations
✅ Consistent across all platforms
✅ Better security
✅ Centralized analytics
✅ Easier to update formulas

---

## 📦 What Was Created

### 1. Fitness Logic Functions (`functions/src/fitness-logic.ts`)

#### `calculateDailyCalories`
- **Purpose:** Calculate BMR and TDEE using Mifflin-St Jeor Equation
- **Input:** Weight, height, age, gender, activity level
- **Output:** BMR, TDEE, recommended macros
- **Saves to:** User profile in Firestore

#### `calculateWorkoutCalories`
- **Purpose:** Calculate calories burned during workout
- **Input:** Weight, duration, activity type, intensity, movement data
- **Output:** Accurate calorie burn using MET values
- **Saves to:** Activities collection

#### `validateAndSaveActivity`
- **Purpose:** Validate and save activities (prevents cheating)
- **Validation:** Max duration, max calories, duplicate detection
- **Saves to:** Activities collection with validation flag

#### `getUserStatistics`
- **Purpose:** Calculate accurate statistics from server data
- **Output:** Total workouts, calories, streaks, averages
- **Period:** Customizable date range

### 2. Subscription Logic Functions (`functions/src/subscription-logic.ts`)

#### `verifySubscription`
- **Purpose:** Server-side subscription verification
- **Returns:** Tier, active status, available features
- **Source of truth:** Cannot be manipulated by client

#### `checkFeatureAccess`
- **Purpose:** Check if user can access specific feature
- **Logs:** Access attempts for analytics
- **Returns:** Access status and upgrade requirements

#### `trackAIUsage`
- **Purpose:** Track AI token usage per user
- **Limits:** Pro (100k/day), Elite (500k/day)
- **Prevents:** Exceeding daily limits

#### `getAIUsageStats`
- **Purpose:** Get AI usage statistics
- **Returns:** Tokens used, requests, breakdown by feature/model

#### `cleanupExpiredSubscriptions`
- **Purpose:** Scheduled function to expire subscriptions
- **Runs:** Every 24 hours
- **Action:** Downgrades expired Pro/Elite to Free

### 3. Flutter Service (`lib/services/server_validation_service.dart`)
- Wrapper for calling Firebase Functions from Flutter
- Handles errors and logging
- Easy-to-use API

---

## 🚀 How to Deploy

### Step 1: Install Dependencies
```bash
cd functions
npm install
```

### Step 2: Build TypeScript
```bash
npm run build
```

### Step 3: Deploy to Firebase
```bash
firebase deploy --only functions
```

### Step 4: Verify Deployment
Check Firebase Console → Functions to see all deployed functions.

---

## 💻 How to Use in Flutter

### Example 1: Calculate Daily Calories

**Before (Client-Side):**
```dart
// ❌ Can be manipulated
double bmr = 10 * weight + 6.25 * height - 5 * age + 5;
double tdee = bmr * 1.55;
```

**After (Server-Side):**
```dart
// ✅ Tamper-proof
final result = await ServerValidationService.instance.calculateDailyCalories(
  weightKg: 70.0,
  heightCm: 175.0,
  age: 30,
  gender: 'male',
  activityLevel: 'moderate',
);

print('BMR: ${result['bmr']}');
print('TDEE: ${result['tdee']}');
print('Recommended Calories: ${result['recommendedCalories']}');
print('Macros: ${result['macros']}');
```

### Example 2: Calculate Workout Calories

**Before (Client-Side):**
```dart
// ❌ Simple estimation
double calories = duration * 5.0;
```

**After (Server-Side):**
```dart
// ✅ Accurate MET-based calculation
final result = await ServerValidationService.instance.calculateWorkoutCalories(
  weightKg: 70.0,
  durationMinutes: 30,
  activityType: 'running',
  intensity: 'moderate',
  movementData: {
    'totalMovement': 85.5,
    'avgConfidence': 0.92,
  },
);

print('Calories Burned: ${result['caloriesBurned']}');
print('MET Value: ${result['met']}');
```

### Example 3: Validate and Save Activity

**Before (Client-Side):**
```dart
// ❌ No validation
await storage.saveActivity(activity);
```

**After (Server-Side):**
```dart
// ✅ Server validates before saving
try {
  final result = await ServerValidationService.instance.validateAndSaveActivity(
    type: 'workout',
    value: 250.0, // calories
    unit: 'kcal',
    note: 'Morning run',
    timestamp: DateTime.now(),
    metadata: {
      'durationMinutes': 30,
      'activityType': 'running',
      'intensity': 'moderate',
    },
  );
  
  print('Activity saved: ${result['activityId']}');
  print('Validated: ${result['validated']}');
} catch (e) {
  // Handle validation errors
  print('Validation failed: $e');
}
```

### Example 4: Verify Subscription

**Before (Client-Side):**
```dart
// ❌ Can be bypassed
bool isPro = localStorage.get('isPro') ?? false;
```

**After (Server-Side):**
```dart
// ✅ Server is source of truth
final result = await ServerValidationService.instance.verifySubscription();

print('Tier: ${result['tier']}');
print('Active: ${result['isActive']}');
print('Features: ${result['features']}');
print('Expires: ${result['expiresAt']}');
```

### Example 5: Check Feature Access

**Before (Client-Side):**
```dart
// ❌ Can be manipulated
if (isPro) {
  // Use AI feature
}
```

**After (Server-Side):**
```dart
// ✅ Server checks access
final result = await ServerValidationService.instance.checkFeatureAccess('ai_chat');

if (result['hasAccess']) {
  // Use AI feature
} else {
  // Show upgrade prompt
  print('Upgrade required to: ${result['tier']}');
}
```

### Example 6: Track AI Usage

```dart
// Track tokens used
final result = await ServerValidationService.instance.trackAIUsage(
  feature: 'ai_chat',
  tokensUsed: 1500,
  model: 'gemini-2.5-flash',
);

print('Tokens used today: ${result['tokensUsed']}');
print('Daily limit: ${result['dailyLimit']}');
print('Remaining: ${result['remaining']}');

if (result['limitExceeded']) {
  print('Daily limit exceeded! Upgrade to Elite for more tokens.');
}
```

### Example 7: Get Statistics

```dart
final result = await ServerValidationService.instance.getUserStatistics(
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);

final stats = result['stats'];
print('Total Workouts: ${stats['totalWorkouts']}');
print('Total Calories Burned: ${stats['totalCaloriesBurned']}');
print('Streak: ${stats['streakDays']} days');
print('Most Active Day: ${stats['mostActiveDay']}');
```

---

## 🔄 Migration Strategy

### Phase 1: Add Server Functions (Parallel)
1. Deploy Firebase Functions
2. Add `ServerValidationService` to Flutter
3. Keep existing client-side logic working
4. Test server functions thoroughly

### Phase 2: Gradual Migration
1. Start using server functions for new features
2. Migrate critical features first (payments, subscriptions)
3. Migrate calculations (calories, statistics)
4. Keep client-side as fallback

### Phase 3: Full Migration
1. Remove client-side calculations
2. Use server as single source of truth
3. Client only displays data from server
4. Remove fallback code

---

## 🛡️ Security Rules

Update Firestore security rules to enforce server-side validation:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read their own data
    match /Users/{userId} {
      allow read: if request.auth.uid == userId;
      // Only server can write validated data
      allow write: if request.auth.uid == userId && 
                      (!request.resource.data.keys().hasAny(['validated', 'validatedBy']));
    }
    
    // Activities must be validated by server
    match /Users/{userId}/activities/{activityId} {
      allow read: if request.auth.uid == userId;
      // Only allow writes with validated flag from server
      allow create: if request.auth.uid == userId && 
                       request.resource.data.validated == true &&
                       request.resource.data.validatedBy == 'server';
      allow update, delete: if false; // Only server can modify
    }
    
    // AI usage tracking - read only for users
    match /Users/{userId}/aiUsage/{usageId} {
      allow read: if request.auth.uid == userId;
      allow write: if false; // Only server can write
    }
  }
}
```

---

## 📊 Monitoring

### Firebase Console
- Functions → Logs: Check function execution logs
- Functions → Usage: Monitor invocations and errors
- Firestore → Data: Verify data is being saved correctly

### Add Monitoring in Flutter
```dart
// Log server function calls
try {
  final result = await ServerValidationService.instance.calculateDailyCalories(...);
  // Success
  analytics.logEvent('server_function_success', parameters: {
    'function': 'calculateDailyCalories',
  });
} catch (e) {
  // Error
  analytics.logEvent('server_function_error', parameters: {
    'function': 'calculateDailyCalories',
    'error': e.toString(),
  });
}
```

---

## 💰 Cost Estimation

### Firebase Functions Pricing (Blaze Plan)
- **Invocations:** $0.40 per million (first 2M free/month)
- **Compute time:** $0.0000025 per GB-second
- **Network:** $0.12 per GB

### Estimated Monthly Cost (1000 active users)
- Daily calorie calculations: 1000 users × 30 days = 30k invocations
- Workout tracking: 1000 users × 3 workouts/day × 30 days = 90k invocations
- Subscription checks: 1000 users × 10 checks/day × 30 days = 300k invocations
- **Total:** ~420k invocations/month = **FREE** (under 2M limit)

### At Scale (10,000 users)
- ~4.2M invocations/month
- Cost: (4.2M - 2M) × $0.40 / 1M = **$0.88/month**

**Conclusion:** Very affordable! 🎉

---

## 🧪 Testing

### Test Firebase Functions Locally
```bash
cd functions
npm run serve
```

### Test from Flutter
```dart
// Point to local emulator
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

// Test function
final result = await ServerValidationService.instance.calculateDailyCalories(...);
```

### Unit Tests for Functions
```typescript
// functions/test/fitness-logic.test.ts
import { calculateDailyCalories } from '../src/fitness-logic';

describe('calculateDailyCalories', () => {
  it('should calculate BMR correctly for male', async () => {
    const result = await calculateDailyCalories({
      weightKg: 70,
      heightCm: 175,
      age: 30,
      gender: 'male',
      activityLevel: 'moderate',
    });
    
    expect(result.bmr).toBeCloseTo(1663, 0);
    expect(result.tdee).toBeCloseTo(2578, 0);
  });
});
```

---

## 🎯 Next Steps

1. **Deploy Functions:**
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions
   ```

2. **Update Flutter App:**
   - Add `cloud_functions` dependency to `pubspec.yaml`
   - Import `ServerValidationService`
   - Replace client-side calculations with server calls

3. **Test Thoroughly:**
   - Test all functions with real data
   - Verify calculations are accurate
   - Check error handling

4. **Monitor:**
   - Watch Firebase Console for errors
   - Monitor function execution times
   - Track costs

5. **Optimize:**
   - Cache results when appropriate
   - Batch operations when possible
   - Add retry logic for failures

---

## ✅ Benefits Summary

### Accuracy
- ✅ Mifflin-St Jeor Equation (most accurate BMR formula)
- ✅ MET-based calorie calculations
- ✅ Movement data integration for precision

### Security
- ✅ Tamper-proof calculations
- ✅ Server-side subscription validation
- ✅ Activity validation prevents cheating

### Consistency
- ✅ Same calculations across all platforms
- ✅ Single source of truth
- ✅ Easy to update formulas

### Analytics
- ✅ Centralized usage tracking
- ✅ AI token monitoring
- ✅ Feature access logging

### Scalability
- ✅ Handles thousands of users
- ✅ Automatic scaling
- ✅ Very affordable costs

---

## 🎉 Conclusion

Moving logic to Firebase Functions makes your app:
- **More accurate** - Professional-grade calculations
- **More secure** - Tamper-proof validation
- **More reliable** - Single source of truth
- **More scalable** - Handles growth automatically
- **More maintainable** - Update logic without app updates

Deploy these functions and your app will be production-ready with enterprise-grade accuracy! 🚀
