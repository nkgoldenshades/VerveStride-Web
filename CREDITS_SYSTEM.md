# AI Credits System Documentation

## Overview

The AI Credits system provides a pay-as-you-go option for users to access AI features without a subscription. Users can purchase credit packages and use them for various AI operations.

## Architecture

### Models (`lib/models/ai_credits.dart`)

#### CreditTransaction
Tracks all credit-related transactions:
- `purchase`: Credits bought by user
- `usage`: Credits consumed for AI operations
- `refund`: Credits returned to user
- `bonus`: Free credits given to user

#### CreditPackage
Defines available credit packages for purchase:
- Starter Pack: 100 credits - $4.99 / ₹415
- Basic Pack: 250 + 25 bonus - $9.99 / ₹830
- Popular Pack: 500 + 75 bonus - $19.99 / ₹1,660
- Power Pack: 1000 + 200 bonus - $34.99 / ₹2,905
- Ultimate Pack: 2500 + 750 bonus - $79.99 / ₹6,640

### Services

#### CreditsService (`lib/services/credits_service.dart`)
Manages credit balance and transactions:
- `availableCredits`: Current credit balance
- `addCredits()`: Add credits after purchase
- `useCredits()`: Deduct credits for AI usage
- `load()`: Load credits from storage
- `clear()`: Clear credits on sign-out

Credit costs per operation:
- Meal Analysis: 2 credits
- Workout Coaching: 5 credits
- Form Analysis: 3 credits
- Chat Message: 1 credit

#### PaymentService (`lib/services/payment_service.dart`)
Extended to support credit purchases:
- `openCreditsCheckout()`: Open payment for credit package
- `onCreditsSuccess`: Callback when credit purchase succeeds

#### UserSubscriptionService (`lib/services/user_subscription_service.dart`)
Integrated with credits:
- Loads credits on initialization
- Clears credits on sign-out

## UI Components

### Premium Screen (`lib/screens/premium/premium_screen.dart`)
Enhanced with credits section:
1. **Credits Balance Card** (top): Shows current credit balance with gradient design
2. **Subscription Plans**: Pro and Elite tiers
3. **One-time Purchases**: Remove Ads and Lifetime
4. **Buy AI Credits**: Credit packages with bonus indicators

### Credits Info Widget (`lib/widgets/credits_info_widget.dart`)
Displays:
- Current credit balance
- Credit costs per AI operation
- Usage breakdown

## Integration Guide

### 1. Check Credits Before AI Operation

```dart
import '../services/credits_service.dart';

Future<bool> canUseAIFeature() async {
  final sub = UserSubscriptionService.instance;
  
  // Subscription users have unlimited/monthly limits
  if (sub.isPro || sub.isElite || sub.isLifetime) {
    return true;
  }
  
  // Check if user has enough credits
  final creditsService = CreditsService.instance;
  final requiredCredits = CreditsService.creditsPerMealAnalysis;
  
  if (creditsService.availableCredits >= requiredCredits) {
    return true;
  }
  
  return false;
}
```

### 2. Deduct Credits After AI Operation

```dart
Future<void> performMealAnalysis() async {
  final sub = UserSubscriptionService.instance;
  
  // Subscription users don't use credits
  if (!sub.isPro && !sub.isElite && !sub.isLifetime) {
    // Deduct credits for free users
    final success = await CreditsService.instance.useCredits(
      CreditsService.creditsPerMealAnalysis,
      description: 'Meal analysis',
    );
    
    if (!success) {
      throw Exception('Insufficient credits');
    }
  }
  
  // Perform AI operation
  // ...
}
```

### 3. Display Credits in UI

```dart
import '../widgets/credits_info_widget.dart';

// In your widget build method:
Column(
  children: [
    CreditsInfoWidget(),
    // Other widgets...
  ],
)
```

## User Flow

### Purchase Credits
1. User navigates to Premium screen
2. Views current credit balance at top
3. Scrolls to "Buy AI Credits" section
4. Selects a credit package
5. Completes payment via Razorpay
6. Credits are added to balance immediately

### Use Credits
1. User attempts AI operation (meal analysis, chat, etc.)
2. System checks subscription status:
   - Pro/Elite/Lifetime: Use subscription allowance
   - Free: Check credit balance
3. If sufficient credits:
   - Deduct credits
   - Perform AI operation
4. If insufficient:
   - Show error message
   - Prompt to purchase credits or upgrade

## Storage

Credits are stored in local storage via `LocalStorageService`:
- Key: `ai_credits`
- Type: `int`
- Persists across app sessions
- Cleared on sign-out

## Future Enhancements

### Recommended Additions:
1. **Credit History**: Track all transactions in Firestore
2. **Credit Expiry**: Optional expiration dates for credits
3. **Referral Bonuses**: Give credits for referrals
4. **Daily Login Rewards**: Small credit bonuses
5. **Credit Gifting**: Transfer credits between users
6. **Bulk Discounts**: Better rates for larger packages
7. **Auto-Recharge**: Automatically buy credits when low
8. **Usage Analytics**: Show credit usage patterns

### Backend Integration:
Currently credits are stored locally. For production:
1. Store credit balance in Firestore
2. Validate transactions server-side
3. Prevent credit manipulation
4. Sync across devices
5. Add transaction history

## Testing

### Test Mode
Payment service supports test mode for development:
- Set `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` as test keys
- Credits are added without real payment
- Test all credit packages

### Manual Testing Checklist
- [ ] Purchase each credit package
- [ ] Verify bonus credits are added
- [ ] Use credits for AI operations
- [ ] Check balance updates correctly
- [ ] Test insufficient credits scenario
- [ ] Verify credits persist after app restart
- [ ] Test credits clear on sign-out
- [ ] Check UI displays correct balance

## Support

For issues or questions:
1. Check credit balance in Premium screen
2. Verify payment was successful
3. Check local storage for `ai_credits` key
4. Review logs for credit transactions
5. Contact support with payment ID
