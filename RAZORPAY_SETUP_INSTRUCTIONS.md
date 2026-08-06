# 🔑 Razorpay Live Keys Setup

## ⚠️ IMPORTANT: First Regenerate Your Keys!

Since you accidentally shared your keys, you MUST regenerate them first:

1. Go to https://dashboard.razorpay.com
2. Login and switch to **Live Mode**
3. Go to **Settings** → **API Keys**
4. Click **"Regenerate Key"**
5. Copy the NEW Key ID and Secret

---

## ✅ Step-by-Step Setup

### Step 1: Edit the .env File

1. Open `functions/.env` file in your code editor
2. Replace the placeholder values:

```env
RAZORPAY_KEY_ID=rzp_live_YOUR_NEW_KEY_ID
RAZORPAY_KEY_SECRET=YOUR_NEW_SECRET
```

**Example (use YOUR actual keys):**
```env
RAZORPAY_KEY_ID=rzp_live_ABC123XYZ456
RAZORPAY_KEY_SECRET=MyNewSecret789
```

3. **Save the file**

---

### Step 2: Deploy Functions

Open CMD in your project folder and run:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

---

### Step 3: Build and Deploy App

```bash
flutter clean
flutter pub get
flutter build web --release
firebase deploy --only hosting
```

---

## 🔒 Security Checklist:

- ✅ Regenerated keys in Razorpay Dashboard
- ✅ Updated `functions/.env` with NEW keys
- ✅ `.env` file is in `.gitignore` (already done)
- ✅ Never commit `.env` to git
- ✅ Never share keys in chat/email

---

## 🎯 What Happens:

1. Functions read keys from `.env` file
2. Keys are used for payment processing
3. Keys stay secret (not in git)
4. Only you have access to `.env` file

---

## ⚠️ Important Notes:

- **Keep `.env` file secret**
- **Never commit to git** (already in .gitignore)
- **Never share keys** with anyone
- **Regenerate if compromised**

---

## 🚀 After Setup:

Test your payment:
1. Open your production URL
2. Try buying credits (₹10 test)
3. Verify payment works
4. Check Razorpay Dashboard for transaction

---

**Status:** Ready to deploy after you update `.env` file! 🎉
