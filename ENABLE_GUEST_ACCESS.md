# 🔧 Enable Guest Access - Step by Step

## ⚠️ IMPORTANT: Manual Configuration Required

Anonymous authentication **cannot be enabled via code or CLI**. You must do this in Firebase Console.

---

## 📋 Step-by-Step Instructions

### **Step 1: Open Firebase Console**
Click this link: [Firebase Authentication Settings](https://console.firebase.google.com/project/vervestride-app/authentication/providers)

Or manually navigate:
1. Go to https://console.firebase.google.com/
2. Select project: **vervestride-app**
3. Click **Authentication** in left sidebar
4. Click **Sign-in method** tab

---

### **Step 2: Enable Anonymous Provider**

1. Scroll down to find **Anonymous** in the providers list
2. Click on **Anonymous**
3. Toggle the **Enable** switch to ON
4. Click **Save**

**Screenshot Guide:**
```
┌─────────────────────────────────────────┐
│ Sign-in providers                       │
├─────────────────────────────────────────┤
│ ✓ Email/Password          [Enabled]     │
│ ✓ Google                  [Enabled]     │
│ ○ Anonymous               [Disabled] ← Click here
│ ○ Phone                   [Disabled]     │
└─────────────────────────────────────────┘
```

After clicking:
```
┌─────────────────────────────────────────┐
│ Anonymous                               │
├─────────────────────────────────────────┤
│ Enable: [Toggle ON] ← Turn this on      │
│                                         │
│ [Cancel]  [Save] ← Click Save           │
└─────────────────────────────────────────┘
```

---

### **Step 3: Verify It's Enabled**

After saving, you should see:
```
┌─────────────────────────────────────────┐
│ Sign-in providers                       │
├─────────────────────────────────────────┤
│ ✓ Email/Password          [Enabled]     │
│ ✓ Google                  [Enabled]     │
│ ✓ Anonymous               [Enabled] ← Should show this
└─────────────────────────────────────────┘
```

---

### **Step 4: Test Guest Login**

1. Open your app (web or mobile)
2. Click **"Continue as Guest"** button
3. You should be logged in and redirected to home screen

**Expected Result:**
- No error messages
- User navigates to home screen
- User gets 5 welcome credits

---

## 🧪 Verification

### **Check in Firebase Console:**
1. Go to **Authentication** → **Users** tab
2. You should see a new user with:
   - **Provider**: Anonymous
   - **User UID**: Random string (e.g., `abc123xyz...`)
   - **Created**: Recent timestamp

### **Check in Firestore:**
1. Go to **Firestore Database**
2. Open **Users** collection
3. Find document with the anonymous user's UID
4. Verify it has:
   ```json
   {
     "credits": {
       "available": 5,
       "totalPurchased": 0,
       "totalUsed": 0,
       "welcomeGranted": true
     }
   }
   ```

---

## ❌ Troubleshooting

### **Error: "operation-not-allowed"**
**Cause**: Anonymous auth is not enabled in Firebase Console  
**Fix**: Follow Step 2 above to enable it

### **Error: "network-request-failed"**
**Cause**: Internet connection issue or CORS problem  
**Fix**: 
- Check internet connection
- Try in incognito mode
- Disable ad blockers
- Check browser console for CORS errors

### **Error: "app-check-token-invalid"**
**Cause**: App Check is blocking anonymous users  
**Fix**: App Check is currently disabled in the code, so this shouldn't happen. If it does, check `lib/main.dart` line 94-106.

---

## 📊 What I Fixed in Code

I improved the error handling in `lib/auth/login_screen.dart`:

**Before:**
```dart
catch (e) {
  _showSnack('Guest sign-in failed: $e');
}
```

**After:**
```dart
on FirebaseAuthException catch (e) {
  String errorMessage;
  switch (e.code) {
    case 'operation-not-allowed':
      errorMessage = 'Guest access is currently disabled. Please contact support or sign in with email/Google.';
      break;
    case 'network-request-failed':
      errorMessage = 'Network error. Please check your internet connection.';
      break;
    default:
      errorMessage = 'Guest sign-in failed: ${e.message ?? e.code}';
  }
  _showSnack(errorMessage);
}
```

Now users will see clearer error messages if something goes wrong.

---

## ✅ Summary

**What I Did:**
- ✅ Diagnosed the issue (Anonymous auth not enabled)
- ✅ Improved error handling in code
- ✅ Created this guide for you

**What You Need to Do:**
- ⏳ Enable Anonymous auth in Firebase Console (Step 2 above)
- ⏳ Test guest login in your app
- ⏳ Verify user creation in Firebase Console

---

## 🔗 Quick Links

- [Firebase Console - Authentication](https://console.firebase.google.com/project/vervestride-app/authentication/providers)
- [Firebase Anonymous Auth Docs](https://firebase.google.com/docs/auth/web/anonymous-auth)
- [Diagnostic Report](./GUEST_USER_DIAGNOSTIC.md)

---

**Last Updated**: May 25, 2026
