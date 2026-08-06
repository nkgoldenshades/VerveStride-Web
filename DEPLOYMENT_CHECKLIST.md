# Firebase Backend Deployment Checklist ✅

## Pre-Deployment

### 1. Prerequisites
- [ ] Node.js 18+ installed
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)
- [ ] Firebase project created (vervestride)
- [ ] Razorpay account created
- [ ] Razorpay test keys obtained
- [ ] Razorpay live keys obtained (for production)

### 2. Project Setup
- [ ] Firebase CLI logged in (`firebase login`)
- [ ] Project initialized (`firebase init`)
- [ ] Functions dependencies installed (`cd functions && npm install`)
- [ ] Environment variables configured

---

## Development Environment

### 3. Local Testing
- [ ] Firebase emulators installed
- [ ] Emulators started (`firebase emulators:start`)
- [ ] Test subscription activation locally
- [ ] Test credits addition locally
- [ ] Test credits deduction locally
- [ ] Test credits refund locally
- [ ] Verify Firestore security rules locally

### 4. Code Review
- [ ] Review `functions/index.js` for errors
- [ ] Review `firestore.rules` for security
- [ ] Review `firestore.indexes.json` for performance
- [ ] Review `firebase_subscription_service.dart` integration
- [ ] Check for hardcoded secrets (should use env vars)

---

## Test Environment Deployment

### 5. Deploy to Test
- [ ] Set Razorpay test mode: `firebase functions:config:set razorpay.mode="test"`
- [ ] Set test keys: `firebase functions:config:set razorpay.test_key_id="..." razorpay.test_key_secret="..."`
- [ ] Deploy Firestore rules: `firebase deploy --only firestore:rules`
- [ ] Deploy Firestore indexes: `firebase deploy --only firestore:indexes`
- [ ] Deploy Cloud Functions: `firebase deploy --only functions`
- [ ] Verify deployment in Firebase Console

### 6. Test with Razorpay Test Mode
- [ ] Create test user account
- [ ] Test Pro monthly subscription purchase
- [ ] Verify subscription activated in Firestore
- [ ] Verify transaction logged
- [ ] Test credits purchase (100 credits)
- [ ] Verify credits added in Firestore
- [ ] Test AI feature (deduct credits)
- [ ] Verify credits deducted
- [ ] Test AI failure (refund credits)
- [ ] Verify credits refunded
- [ ] Test subscription expiry
- [ ] Test Elite unlimited access

### 7. Security Testing
- [ ] Try to modify subscription in Firestore directly → Should fail
- [ ] Try to add credits in Firestore directly → Should fail
- [ ] Try to access another user's data → Should fail
- [ ] Verify only authenticated users can call functions
- [ ] Test with invalid payment IDs → Should fail gracefully

---

## Production Deployment

### 8. Pre-Production Checklist
- [ ] All tests passing
- [ ] No console errors
- [ ] Function logs clean
- [ ] Security rules verified
- [ ] Performance acceptable
- [ ] Error handling tested
- [ ] Backup strategy in place

### 9. Switch to Live Mode
- [ ] Set Razorpay live mode: `firebase functions:config:set razorpay.mode="live"`
- [ ] Set live keys: `firebase functions:config:set razorpay.live_key_id="..." razorpay.live_key_secret="..."`
- [ ] Deploy functions: `firebase deploy --only functions`
- [ ] Verify live mode in function logs

### 10. Production Testing
- [ ] Test with small real payment (₹1)
- [ ] Verify payment captured in Razorpay dashboard
- [ ] Verify subscription activated
- [ ] Verify transaction logged
- [ ] Test credits purchase with real payment
- [ ] Verify credits added
- [ ] Monitor function logs for errors

---

## Post-Deployment

### 11. Monitoring Setup
- [ ] Enable Firebase Crashlytics
- [ ] Set up Firebase Alerts
- [ ] Configure function error notifications
- [ ] Set up Firestore usage alerts
- [ ] Monitor Razorpay dashboard

### 12. Documentation
- [ ] Update README with deployment info
- [ ] Document environment variables
- [ ] Document testing procedures
- [ ] Create runbook for common issues
- [ ] Share access with team

### 13. Backup & Recovery
- [ ] Enable Firestore backups
- [ ] Document recovery procedures
- [ ] Test restore from backup
- [ ] Set up automated backups

---

## Optional Enhancements

### 14. Webhooks (Recommended)
- [ ] Get Cloud Function webhook URL
- [ ] Configure webhook in Razorpay dashboard
- [ ] Set webhook secret: `firebase functions:config:set razorpay.webhook_secret="..."`
- [ ] Deploy webhook function
- [ ] Test webhook with Razorpay test events
- [ ] Verify webhook signature validation

### 15. Analytics
- [ ] Enable Firebase Analytics
- [ ] Track subscription purchases
- [ ] Track credits purchases
- [ ] Track AI usage
- [ ] Set up conversion funnels

### 16. Admin Dashboard
- [ ] Create admin user in Firestore
- [ ] Set admin role
- [ ] Test admin access
- [ ] Create admin UI (optional)

---

## Maintenance

### 17. Regular Checks
- [ ] Weekly: Check function logs
- [ ] Weekly: Check Firestore usage
- [ ] Weekly: Check Razorpay settlements
- [ ] Monthly: Review costs
- [ ] Monthly: Review security rules
- [ ] Monthly: Update dependencies

### 18. Performance Optimization
- [ ] Monitor function execution time
- [ ] Optimize slow queries
- [ ] Add caching where needed
- [ ] Review Firestore indexes
- [ ] Optimize client-side caching

---

## Troubleshooting

### Common Issues

#### Functions Not Deploying
```bash
# Check Node.js version
node --version  # Should be 18+

# Reinstall dependencies
cd functions
rm -rf node_modules package-lock.json
npm install

# Deploy again
firebase deploy --only functions
```

#### Payment Not Activating
```bash
# Check function logs
firebase functions:log --only activateSubscription

# Verify payment ID in Razorpay dashboard
# Check Firestore for transaction
```

#### Credits Not Syncing
```bash
# Check function logs
firebase functions:log --only deductCredits

# Verify Firestore data
# Check client-side sync logic
```

#### Security Rules Blocking Access
```bash
# Check Firestore rules
firebase deploy --only firestore:rules

# Verify user authentication
# Check Firebase Console → Authentication
```

---

## Emergency Procedures

### Rollback Deployment
```bash
# List previous deployments
firebase functions:log

# Rollback to previous version
# (Manual process - redeploy previous code)
```

### Disable Functions
```bash
# Delete specific function
firebase functions:delete functionName

# Or disable in Firebase Console
```

### Emergency Contacts
- Firebase Support: https://firebase.google.com/support
- Razorpay Support: https://razorpay.com/support
- Team Lead: [Add contact]
- DevOps: [Add contact]

---

## Sign-Off

### Deployment Approval

**Deployed by:** _______________  
**Date:** _______________  
**Environment:** [ ] Test [ ] Production  
**Version:** _______________  

**Approved by:** _______________  
**Date:** _______________  

**Notes:**
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

---

## Quick Reference

### Useful Commands

```bash
# Deploy everything
firebase deploy

# Deploy specific service
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes

# View logs
firebase functions:log
firebase functions:log --only functionName

# Check config
firebase functions:config:get

# Start emulators
firebase emulators:start

# Open Firebase Console
firebase open
```

### Important URLs

- Firebase Console: https://console.firebase.google.com
- Razorpay Dashboard: https://dashboard.razorpay.com
- Function Logs: https://console.firebase.google.com/project/vervestride/functions
- Firestore: https://console.firebase.google.com/project/vervestride/firestore

---

**Status:** [ ] Not Started [ ] In Progress [ ] Completed [ ] Verified

**Last Updated:** _______________
