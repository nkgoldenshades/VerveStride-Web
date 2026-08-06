# Improving Email Deliverability for VerveStride

## Problem
Firebase Authentication emails are landing in spam folders because they use generic Firebase domains.

## Solutions

### Option 1: Customize Firebase Email Templates (Quick Fix)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select "vervestride-app" project
3. Navigate to **Authentication** → **Templates**
4. Click on **Password reset** template
5. Customize:
   - **From name**: "VerveStride Team" (instead of default)
   - **Subject**: "Reset Your VerveStride Password"
   - **Email body**: Make it more personal and branded
   - Add your logo/branding if possible

### Option 2: Custom Email Domain (Best for Production)
1. In Firebase Console → Authentication → Templates
2. Click "Customize action URL"
3. Set up custom domain (e.g., auth.vervestride.com)
4. Configure DNS records:
   - Add CNAME record pointing to Firebase
   - Add SPF record: `v=spf1 include:_spf.firebasemail.com ~all`
   - Add DKIM records (provided by Firebase)

### Option 3: Use Professional Email Service (Recommended for Scale)

Install email service in Firebase Functions:

```bash
cd functions
npm install nodemailer
npm install @sendgrid/mail
# or
npm install mailgun-js
```

Popular services:
- **SendGrid** (12,000 free emails/month)
- **Mailgun** (5,000 free emails/month)
- **AWS SES** (62,000 free emails/month)
- **Resend** (3,000 free emails/month)

### Option 4: Trigger Custom Email via Cloud Function

Create a custom password reset flow that sends emails through a professional service.

## Quick Wins (No Code Changes)

1. **Mark as "Not Spam"**: Ask users to mark the email as "Not Spam" - this trains email providers
2. **Add to Contacts**: Suggest users add noreply@vervestride-app.firebaseapp.com to contacts
3. **Whitelist Domain**: In your app's help section, mention checking spam folder initially

## Best Practice for Production

Use a combination:
- Custom domain for Firebase Auth emails
- Professional email service (SendGrid/Mailgun) for transactional emails
- Proper DNS configuration (SPF, DKIM, DMARC)
- Warm up your sending domain gradually

## Cost Comparison

| Service | Free Tier | Cost After |
|---------|-----------|------------|
| Firebase Default | Unlimited | Free |
| SendGrid | 100/day | $19.95/mo |
| Mailgun | 5,000/mo | $35/mo |
| AWS SES | 62,000/mo | $0.10/1000 |
| Resend | 3,000/mo | $20/mo |

## Recommendation for VerveStride

**Now (Development):**
- Customize Firebase email templates
- Add clear branding and messaging
- Inform users to check spam folder

**Before Launch:**
- Set up custom domain for auth emails
- Configure SPF/DKIM records
- Consider SendGrid or AWS SES for transactional emails

**After Launch:**
- Monitor email deliverability rates
- Collect user feedback
- Upgrade to professional service if needed
