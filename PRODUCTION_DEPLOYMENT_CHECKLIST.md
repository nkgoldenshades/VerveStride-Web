# 🚀 VerveStride Production Deployment Checklist

## ✅ COMPLETED TASKS

### 1. App Check Configuration
- ✅ App Check re-enabled in `lib/main.dart`
- ✅ Debug token removed from `web/index.html`
- ✅ reCAPTCHA v3 key configured: `6LdSKs8sAAAAAGdfilDGFnIQhRYkKOr3_4aI1jui`
- ✅ Misleading debug message removed

### 2. AI Features Complete
- ✅ Competitive AI system prompt (200+ lines)
- ✅ Universal domain expertise
- ✅ Smart completeness (no skipping)
- ✅ Web search integration
- ✅ Document picker added to AI chat
- ✅ Thread sidebar functionality
- ✅ Credits display fixed
- ✅ Download chat feature

### 3. Code Quality
- ✅ No compilation errors
- ✅ All diagnostics clean
- ✅ Document picker tested (no errors)

---

## 📋 DEPLOYMENT STEPS

### Step 1: Local Testing with App Check
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

**Expected Console Output:**
```
🔄 Activating App Check...
✅ App Check activated
```

**Test Checklist:**
- [ ] App loads without errors
- [ ] Credits display correctly (103 credits, not 20)
- [ ] AI chat works (send a test message)
- [ ] Floating AI works
- [ ] Document picker opens (click + → Document / File)
- [ ] Thread sidebar opens (click ☰)
- [ ] Download chat works (click 📥)

---

### Step 2: Build for Production
```bash
flutter build web --release
```

**Expected Output:**
```
✓ Built build/web
```

**Verify Build:**
- [ ] Build completes without errors
- [ ] Check `build/web` folder exists
- [ ] Check `build/web/index.html` exists

---

### Step 3: Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

**Expected Output:**
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/YOUR_PROJECT/overview
Hosting URL: https://YOUR_PROJECT.web.app
```

**Save Your URLs:**
- Production URL: `_______________________________`
- Firebase Console: `_______________________________`

---

### Step 4: Test Production Deployment

Open your production URL and test:

- [ ] App loads without errors
- [ ] No console errors
- [ ] Credits display correctly
- [ ] AI chat works (send test message)
- [ ] Floating AI works
- [ ] Document picker works
- [ ] Thread sidebar works
- [ ] Download chat works
- [ ] Web search toggle works

---

### Step 5: Enforce App Check in Firebase Console

⚠️ **IMPORTANT:** Only do this AFTER confirming production deployment works!

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Navigate to each service and enforce App Check:

#### A. Cloud Firestore
- Go to **Firestore Database** → **App Check** tab
- Click **Enforce** for Firestore
- Confirm enforcement

#### B. Firebase AI (Vertex AI)
- Go to **Build** → **Vertex AI in Firebase**
- Click **App Check** tab
- Click **Enforce** for Vertex AI
- Confirm enforcement

#### C. Authentication (if using)
- Go to **Authentication** → **Settings** → **App Check**
- Click **Enforce**
- Confirm enforcement

#### D. Cloud Functions
- Go to **Functions** → **App Check** tab
- Click **Enforce** for each function:
  - `createRazorpayOrder`
  - `verifyRazorpayPayment`
  - Any other functions you have
- Confirm enforcement

**Enforcement Checklist:**
- [ ] Firestore enforced
- [ ] Vertex AI enforced
- [ ] Authentication enforced (if applicable)
- [ ] Cloud Functions enforced

---

### Step 6: Update Razorpay Keys to Live

⚠️ **CRITICAL:** Switch from test keys to live keys for production payments!

1. Go to Razorpay Dashboard: https://dashboard.razorpay.com
2. Switch to **Live Mode** (toggle in top-right)
3. Go to **Settings** → **API Keys**
4. Generate new **Live API Keys** if you don't have them
5. Copy **Key ID** and **Key Secret**

#### Update Firebase Functions:
```bash
cd functions
```

Edit `functions/index.js` or `functions/src/index.ts`:

**Find this:**
```javascript
const razorpay = new Razorpay({
  key_id: 'rzp_test_XXXXXXXXXXXXXXXX',  // Test key
  key_secret: 'YOUR_TEST_SECRET',        // Test secret
});
```

**Replace with:**
```javascript
const razorpay = new Razorpay({
  key_id: 'rzp_live_XXXXXXXXXXXXXXXX',  // Live key
  key_secret: 'YOUR_LIVE_SECRET',        // Live secret
});
```

#### Deploy Updated Functions:
```bash
firebase deploy --only functions
```

**Razorpay Update Checklist:**
- [ ] Switched to Live Mode in Razorpay Dashboard
- [ ] Generated Live API Keys
- [ ] Updated `key_id` in functions code
- [ ] Updated `key_secret` in functions code
- [ ] Deployed functions with live keys
- [ ] Tested a small payment (₹1 or ₹10)

---

### Step 7: Final Production Test

After enforcing App Check and updating Razorpay:

1. **Clear browser cache** (Ctrl+Shift+Delete)
2. **Open production URL in incognito/private window**
3. **Test everything:**

- [ ] App loads without errors
- [ ] No App Check errors in console
- [ ] Credits display correctly
- [ ] AI chat works (send test message)
- [ ] Floating AI works
- [ ] Document picker works
- [ ] Thread sidebar works
- [ ] Download chat works
- [ ] Web search works
- [ ] **Payment works** (test with small amount)
- [ ] Credits deduct correctly after AI usage
- [ ] Credits add correctly after payment

---

## 🎯 SUCCESS CRITERIA

Your app is production-ready when:

✅ All local tests pass  
✅ Production build succeeds  
✅ Firebase deployment succeeds  
✅ Production URL loads without errors  
✅ App Check is enforced on all services  
✅ Razorpay live keys are active  
✅ All features work in production  
✅ No console errors  
✅ Payments work correctly  

---

## 🆘 TROUBLESHOOTING

### Issue: App Check errors in production
**Solution:** 
- Verify reCAPTCHA key is correct
- Check Firebase Console → App Check → Web apps
- Ensure your domain is registered

### Issue: AI not working after enforcement
**Solution:**
- Check Firebase Console → Vertex AI → App Check
- Verify App Check is activated in code
- Check browser console for specific errors

### Issue: Payment fails with live keys
**Solution:**
- Verify live keys are correct (no typos)
- Check Razorpay Dashboard for error logs
- Ensure live mode is enabled in Razorpay
- Test with a small amount first

### Issue: Credits not deducting
**Solution:**
- Check Firestore rules allow writes
- Verify CreditsService is working
- Check browser console for errors
- Force reload credits: `CreditsService.instance.load(force: true)`

---

## 📝 NOTES

### Why NOT to Add Claude/ChatGPT APIs
You asked about adding Claude and ChatGPT APIs. Here's why you should stick with Firebase Vertex AI:

1. **Simpler:** One integration vs. managing multiple API keys
2. **Cheaper:** Google Cloud pricing is competitive, no need to pay multiple providers
3. **Better Integrated:** Firebase AI works seamlessly with your existing Firebase setup
4. **Unified Billing:** Everything in one Google Cloud bill
5. **App Check Security:** Protects all Firebase services including AI
6. **No Extra Code:** Already implemented and working

### Deployment Order Matters
1. ✅ Update code FIRST (App Check enabled)
2. ✅ Deploy to Firebase Hosting
3. ✅ Test production deployment
4. ✅ THEN enforce App Check in Firebase Console
5. ✅ Update Razorpay keys last

**Why this order?**
- If you enforce App Check before deploying, your app won't work
- If you update Razorpay keys before testing, you can't test payments
- This order ensures smooth transition with minimal downtime

---

## 🎉 AFTER DEPLOYMENT

Once everything is working:

1. **Monitor Firebase Console** for usage and errors
2. **Check Razorpay Dashboard** for payment activity
3. **Monitor credits usage** to ensure deductions work
4. **Test regularly** to catch issues early
5. **Keep backups** of your Firebase config

---

## 📞 SUPPORT

If you encounter issues:
- Check Firebase Console logs
- Check browser console errors
- Check Razorpay Dashboard logs
- Review this checklist step-by-step

---

**Last Updated:** May 1, 2026  
**Status:** Ready for Production Deployment 🚀
