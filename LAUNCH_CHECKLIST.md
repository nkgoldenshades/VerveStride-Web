# 🚀 VerveStride Launch Checklist

Use this checklist to track your progress to production launch.

---

## Phase 1: Configuration (Day 1)

### Razorpay Setup
- [ ] Log into Razorpay Dashboard
- [ ] Switch to "Live Mode" (toggle in top-left)
- [ ] Navigate to Settings → API Keys
- [ ] Copy Key ID (starts with `rzp_live_`)
- [ ] Copy Key Secret
- [ ] Save keys securely (password manager)

### Logo Setup
- [ ] Prepare company logo (PNG, 512x512px recommended)
- [ ] Upload to Firebase Storage OR
- [ ] Upload to your CDN/website
- [ ] Get public URL
- [ ] Test URL loads in browser

### Environment Variables
- [ ] Set `RAZORPAY_KEY_ID` environment variable
- [ ] Set `RAZORPAY_KEY_SECRET` environment variable
- [ ] Set `COMPANY_LOGO_URL` environment variable
- [ ] Verify variables are set correctly

---

## Phase 2: Build & Test (Day 2-5)

### Build Production APK
- [ ] Run `./build_production.sh android` (or .bat on Windows)
- [ ] Check build completes successfully
- [ ] Verify output: `build/app/outputs/flutter-apk/app-release.apk`
- [ ] Check logs show "PRODUCTION MODE: Using Razorpay LIVE keys"

### Install on Real Device
- [ ] Transfer APK to Android device
- [ ] Install APK
- [ ] Grant all permissions when prompted
- [ ] App launches successfully

### Test Core Features
- [ ] User can sign in with Google
- [ ] Home screen loads
- [ ] Workout tracking works
- [ ] Calendar loads
- [ ] Profile screen works
- [ ] Settings accessible

### Test Payment Flow
- [ ] Navigate to Premium/Subscription screen
- [ ] Select a plan (start with cheapest)
- [ ] Payment screen opens
- [ ] Company logo displays correctly
- [ ] Complete payment with small amount
- [ ] Payment succeeds
- [ ] Check Razorpay dashboard for transaction
- [ ] Subscription activates in app
- [ ] Premium features unlock

### Test Voice Features
- [ ] Tap floating AI button
- [ ] Chat opens
- [ ] Tap microphone button
- [ ] Button turns red (listening)
- [ ] Speak a message
- [ ] Text appears in real-time
- [ ] Message sends automatically
- [ ] AI responds
- [ ] Close chat
- [ ] Say "VerveStride AI"
- [ ] Chat opens automatically
- [ ] Long-press button to hide
- [ ] Say "VerveStride AI" again
- [ ] Button reappears

### Test Permissions
- [ ] Camera permission works (workout tracking)
- [ ] Microphone permission works (voice)
- [ ] Location permission works (if enabled)
- [ ] Notification permission works (reminders)

### Test Offline
- [ ] Turn off WiFi/data
- [ ] App still opens
- [ ] Can view cached data
- [ ] Turn on WiFi/data
- [ ] Data syncs

---

## Phase 3: Store Preparation (Day 6-10)

### Privacy Policy
- [ ] Open `PRIVACY_POLICY_TEMPLATE.md`
- [ ] Replace [DATE] with current date
- [ ] Replace [YOUR_EMAIL] with support email
- [ ] Replace [YOUR_WEBSITE] with website URL
- [ ] Replace [YOUR_ADDRESS] with company address
- [ ] Review and customize for your needs
- [ ] Have legal review (recommended)
- [ ] Upload to website
- [ ] Get public URL

### Terms of Service
- [ ] Open `TERMS_OF_SERVICE_TEMPLATE.md`
- [ ] Replace [DATE] with current date
- [ ] Replace [YOUR_EMAIL] with support email
- [ ] Replace [YOUR_WEBSITE] with website URL
- [ ] Replace [YOUR_ADDRESS] with company address
- [ ] Replace [YOUR_JURISDICTION] with your location
- [ ] Review and customize for your needs
- [ ] Have legal review (recommended)
- [ ] Upload to website
- [ ] Get public URL

### App Store Assets (Android)
- [ ] App icon (512x512px)
- [ ] Feature graphic (1024x500px)
- [ ] Screenshots (at least 2, up to 8):
  - [ ] Home screen
  - [ ] Workout tracking
  - [ ] AI assistant
  - [ ] Calendar/planning
  - [ ] Progress tracking
  - [ ] Premium features
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] App category: Health & Fitness
- [ ] Content rating questionnaire

### App Store Assets (iOS)
- [ ] App icon (1024x1024px)
- [ ] Screenshots for each device size:
  - [ ] iPhone 6.7" (1290x2796px) - 3-10 images
  - [ ] iPhone 6.5" (1242x2688px) - 3-10 images
  - [ ] iPhone 5.5" (1242x2208px) - 3-10 images
  - [ ] iPad Pro 12.9" (2048x2732px) - 3-10 images
- [ ] App preview videos (optional)
- [ ] Description (4000 chars max)
- [ ] Keywords (100 chars max)
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] Age rating

### App Descriptions
- [ ] Write compelling app description
- [ ] Highlight key features:
  - AI-powered fitness assistant
  - Voice commands
  - Pose detection
  - Nutrition tracking
  - Personalized plans
- [ ] Include subscription pricing
- [ ] Mention free tier availability
- [ ] Add call-to-action

---

## Phase 4: Google Play Store (Day 11-12)

### Account Setup
- [ ] Create Google Play Developer account ($25 one-time)
- [ ] Verify identity
- [ ] Set up merchant account (for paid apps)

### Create App Listing
- [ ] Go to [Google Play Console](https://play.google.com/console)
- [ ] Create new app
- [ ] App name: VerveStride
- [ ] Default language: English (or your language)
- [ ] App or game: App
- [ ] Free or paid: Free (with in-app purchases)

### Store Listing
- [ ] Upload app icon
- [ ] Upload feature graphic
- [ ] Upload screenshots
- [ ] Enter short description
- [ ] Enter full description
- [ ] Select category: Health & Fitness
- [ ] Add tags (optional)
- [ ] Enter contact email
- [ ] Add privacy policy URL
- [ ] Add terms of service URL (optional)

### Content Rating
- [ ] Complete questionnaire
- [ ] Submit for rating
- [ ] Apply rating to app

### App Content
- [ ] Privacy policy URL
- [ ] Ads declaration (Yes - AdMob for free tier)
- [ ] Target audience: 13+
- [ ] Data safety form:
  - [ ] List data collected
  - [ ] List data shared
  - [ ] Security practices

### Pricing & Distribution
- [ ] Select countries (or worldwide)
- [ ] Confirm free app
- [ ] Set up in-app products:
  - [ ] Pro Monthly
  - [ ] Elite Monthly
  - [ ] Lifetime
- [ ] Content guidelines compliance

### Release
- [ ] Create production release
- [ ] Upload app bundle (.aab file)
- [ ] Release name: v1.0.0
- [ ] Release notes
- [ ] Review and rollout
- [ ] Submit for review

---

## Phase 5: Apple App Store (Day 11-12)

### Account Setup
- [ ] Enroll in Apple Developer Program ($99/year)
- [ ] Verify identity
- [ ] Accept agreements

### App Store Connect
- [ ] Go to [App Store Connect](https://appstoreconnect.apple.com/)
- [ ] Create new app
- [ ] Bundle ID: com.vervestride.app
- [ ] App name: VerveStride
- [ ] Primary language: English

### Build Upload
- [ ] Open project in Xcode
- [ ] Select "Any iOS Device"
- [ ] Product → Archive
- [ ] Wait for archive to complete
- [ ] Window → Organizer
- [ ] Select archive
- [ ] Validate App
- [ ] Fix any issues
- [ ] Distribute App
- [ ] Upload to App Store
- [ ] Wait for processing (10-30 min)

### App Information
- [ ] App name: VerveStride
- [ ] Subtitle (30 chars)
- [ ] Category: Health & Fitness
- [ ] Secondary category (optional)
- [ ] Content rights
- [ ] Age rating

### Pricing & Availability
- [ ] Price: Free
- [ ] Availability: All countries
- [ ] Set up in-app purchases:
  - [ ] Pro Monthly
  - [ ] Elite Monthly
  - [ ] Lifetime

### App Privacy
- [ ] Complete privacy questionnaire
- [ ] List data types collected
- [ ] List data usage
- [ ] Link to privacy policy

### Version Information
- [ ] Upload screenshots (all sizes)
- [ ] Upload app preview videos (optional)
- [ ] Description (4000 chars)
- [ ] Keywords (100 chars)
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] Version: 1.0.0
- [ ] Copyright
- [ ] Release notes

### Review Information
- [ ] Contact information
- [ ] Demo account (if needed)
- [ ] Notes for reviewer
- [ ] Attach documents (if needed)

### Submit
- [ ] Review all information
- [ ] Submit for review
- [ ] Wait for review (1-7 days)

---

## Phase 6: Post-Launch (Ongoing)

### Monitoring (Daily)
- [ ] Check Firebase Crashlytics for errors
- [ ] Check Razorpay dashboard for payments
- [ ] Monitor app store reviews
- [ ] Check Firebase Analytics
- [ ] Review user feedback

### Marketing (Week 1)
- [ ] Announce launch on social media
- [ ] Email existing users (if any)
- [ ] Submit to app review sites
- [ ] Create launch blog post
- [ ] Share with fitness communities

### Support (Ongoing)
- [ ] Set up support email
- [ ] Respond to user reviews
- [ ] Answer support questions
- [ ] Track feature requests
- [ ] Monitor bug reports

### Updates (Regular)
- [ ] Plan update schedule
- [ ] Fix critical bugs immediately
- [ ] Release minor updates every 2 weeks
- [ ] Release major updates every 1-2 months
- [ ] Keep dependencies updated

---

## Emergency Contacts

### If Payment Issues
- Razorpay Support: support@razorpay.com
- Razorpay Dashboard: https://dashboard.razorpay.com/

### If Firebase Issues
- Firebase Support: https://firebase.google.com/support
- Firebase Console: https://console.firebase.google.com/

### If App Store Issues
- Google Play Support: https://support.google.com/googleplay/android-developer
- Apple Developer Support: https://developer.apple.com/support/

---

## Success Metrics

Track these metrics after launch:

### Week 1
- [ ] Downloads: _____
- [ ] Active users: _____
- [ ] Subscriptions: _____
- [ ] Crash-free rate: ____%
- [ ] Average rating: _____

### Month 1
- [ ] Total downloads: _____
- [ ] Monthly active users: _____
- [ ] Total subscriptions: _____
- [ ] Revenue: _____
- [ ] Retention rate: ____%

---

## 🎉 Launch Complete!

Once all items are checked, you've successfully launched VerveStride!

**Congratulations! 🚀**

Remember:
- Monitor daily for first week
- Respond to reviews quickly
- Fix critical bugs immediately
- Plan regular updates
- Listen to user feedback

Good luck! 🎊
