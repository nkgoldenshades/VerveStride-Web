# 🚀 Quick Deployment Guide

## ⚡ Fast Track to Production

### Step 1: Test Locally (5 minutes)
```bash
flutter clean
flutter pub get
flutter run -d chrome
```
✅ Check console for: `✅ App Check activated`  
✅ Test AI chat works  
✅ Test document picker (+ button → Document / File)

---

### Step 2: Build & Deploy (5 minutes)
```bash
flutter build web --release
firebase deploy --only hosting
```
✅ Save your production URL  
✅ Test in incognito window  
✅ Verify all features work

---

### Step 3: Enforce Security (10 minutes)
Go to Firebase Console → Enforce App Check on:
- ✅ Firestore
- ✅ Vertex AI
- ✅ Authentication
- ✅ Functions

---

### Step 4: Update Payment Keys (5 minutes)
1. Get live keys from Razorpay Dashboard
2. Update `functions/index.js`:
   ```javascript
   key_id: 'rzp_live_XXXXXXXX',
   key_secret: 'YOUR_LIVE_SECRET',
   ```
3. Deploy: `firebase deploy --only functions`

---

### Step 5: Final Test (5 minutes)
- ✅ Clear cache
- ✅ Test all features
- ✅ Test payment with ₹10

---

## 🎉 Done! You're Live!

**Total Time:** ~30 minutes

**Full Details:** See `PRODUCTION_DEPLOYMENT_CHECKLIST.md`

---

## 🆘 Quick Troubleshooting

**App Check errors?**
→ Check reCAPTCHA key in Firebase Console

**AI not working?**
→ Verify Vertex AI is enforced in Firebase Console

**Payment fails?**
→ Double-check live keys in functions code

**Credits not showing?**
→ Force reload: `CreditsService.instance.load(force: true)`

---

**Need Help?** Check the full checklist: `PRODUCTION_DEPLOYMENT_CHECKLIST.md`
