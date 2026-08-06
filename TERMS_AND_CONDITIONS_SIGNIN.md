# Add Terms & Conditions Checkbox to Sign-In Screen

## Requirement
Users must **accept Terms & Conditions** before creating an account or signing in.

---

## Implementation Plan

### Step 1: Add Terms Acceptance State
**File**: `lib/auth/login_screen.dart`

Add to `_LoginScreenState`:
```dart
bool _acceptedTerms = false;  // NEW: Track T&C acceptance
bool _showTermsError = false; // NEW: Show error if not accepted
```

### Step 2: Create Terms & Conditions Dialog
**File**: `lib/auth/login_screen.dart`

Add new method:
```dart
void _showTermsDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Terms & Conditions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content goes here
            const Text(
              '1. Credit System\n'
              '• Each message costs credits based on tokens used\n'
              '• 1 credit = ₹4.15 (from ₹415 for 100 credits)\n'
              '• Credits are non-refundable\n'
              '• Token usage: Input tokens × \$0.30 + Output tokens × \$2.50\n\n'
              '2. Memory System\n'
              '• Thread Memory: Remembers current conversation only\n'
              '• Chat Memory: Remembers across all conversations\n'
              '• Users can toggle memory settings anytime\n\n'
              '3. Feature Costs\n'
              '• Chat messages: Token-based (mostly free)\n'
              '• Image generation: 1 credit each\n'
              '• Video generation: 8 credits each\n'
              '• Audio generation: 3 credits each\n\n'
              '4. User Responsibilities\n'
              '• You are responsible for your account\n'
              '• Don\'t share sensitive information in chats\n'
              '• Respect AI usage guidelines\n\n'
              '5. Privacy\n'
              '• Your conversations may be used to improve AI\n'
              '• Personal data is encrypted and stored securely\n'
              '• You can request data deletion anytime\n\n'
              '6. Liability\n'
              '• VerveStride AI is provided "as-is"\n'
              '• We are not liable for AI errors or inaccuracies\n'
              '• Use at your own risk\n',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Decline'),
        ),
        TextButton(
          onPressed: () {
            setState(() => _acceptedTerms = true);
            Navigator.pop(context);
          },
          child: const Text('Accept'),
        ),
      ],
    ),
  );
}
```

### Step 3: Add Checkbox to Sign-In Form
**File**: `lib/auth/login_screen.dart`

Add **before** the "Continue with Google" button:

```dart
// Terms & Conditions Checkbox
const SizedBox(height: 16),
GestureDetector(
  onTap: () => _showTermsDialog(),
  child: Row(
    children: [
      Checkbox(
        value: _acceptedTerms,
        onChanged: (_) {
          if (!_acceptedTerms) {
            _showTermsDialog();
          } else {
            setState(() => _acceptedTerms = false);
          }
        },
      ),
      Expanded(
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'I accept the ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: 'Terms & Conditions',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
if (_showTermsError)
  Padding(
    padding: const EdgeInsets.only(top: 8, left: 12),
    child: Text(
      'Please accept Terms & Conditions to continue',
      style: TextStyle(
        color: Colors.red.shade400,
        fontSize: 12,
      ),
    ),
  ),
const SizedBox(height: 16),
```

### Step 4: Validate Acceptance Before Sign-In
**File**: `lib/auth/login_screen.dart`

Update `_handleEmailAuth()` method:

```dart
Future<void> _handleEmailAuth() async {
  // NEW: Check if terms accepted
  if (!_acceptedTerms) {
    setState(() => _showTermsError = true);
    _showSnack('Please accept Terms & Conditions to continue');
    return;
  }
  
  // ... rest of existing sign-in logic
  setState(() => _isLoading = true);
  try {
    // ... email auth code
  } catch (e) {
    // ... error handling
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

Also update `_signInWithGoogle()`:

```dart
Future<void> _signInWithGoogle() async {
  // NEW: Check if terms accepted
  if (!_acceptedTerms) {
    setState(() => _showTermsError = true);
    _showSnack('Please accept Terms & Conditions to continue');
    return;
  }
  
  setState(() => _isLoading = true);
  try {
    await AuthService().signInWithGoogle();
    if (kDebugMode) {
      debugPrint('Google Sign-In successful');
    }
    if (mounted) {
      Navigator.pushReplacementNamed(context, Routes.home);
    }
  } catch (e) {
    _showSnack('Google sign-in failed: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

And `_signInAsGuest()`:

```dart
Future<void> _signInAsGuest() async {
  // NEW: Check if terms accepted
  if (!_acceptedTerms) {
    setState(() => _showTermsError = true);
    _showSnack('Please accept Terms & Conditions to continue');
    return;
  }
  
  setState(() => _isLoading = true);
  try {
    await FirebaseAuth.instance.signInAnonymously();
    if (kDebugMode) {
      debugPrint('Guest Sign-In successful');
    }
    if (mounted) {
      Navigator.pushReplacementNamed(context, Routes.home);
    }
  } catch (e) {
    _showSnack('Guest sign-in failed: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### Step 5: Store Acceptance in Firestore (Optional but Recommended)
**File**: `lib/services/auth_service.dart`

After successful sign-in, store T&C acceptance:

```dart
// After user is created/signed in
await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set({
      'termsAcceptedAt': DateTime.now(),
      'termsVersion': '1.0',
      'acceptedTerms': true,
    }, SetOptions(merge: true));
```

---

## UI Flow

```
┌─────────────────────────────────────────┐
│ Email:      [____________]              │
│ Password:   [____________]              │
│                                         │
│ ☐ I accept the Terms & Conditions      │
│   (underlined, clickable)               │
│                                         │
│ [🔴 Please accept T&C]  (if error)     │
│                                         │
│        [Continue with Google]           │
│        [Sign in]                        │
│        [Continue as Guest]              │
└─────────────────────────────────────────┘

When user clicks "Terms & Conditions":
┌─────────────────────────────────────────┐
│     Terms & Conditions                  │
│                                         │
│ 1. Credit System                        │
│ • Each message costs credits...         │
│ • 1 credit = ₹4.15                      │
│ • Credits are non-refundable            │
│                                         │
│ 2. Memory System                        │
│ • Thread Memory...                      │
│ • Chat Memory...                        │
│                                         │
│ 3. Feature Costs                        │
│ • Chat: Token-based                     │
│ • Images: 1 credit                      │
│ • Videos: 8 credits                     │
│                                         │
│ 4. User Responsibilities                │
│ 5. Privacy                              │
│ 6. Liability                            │
│                                         │
│         [Decline]  [Accept]             │
└─────────────────────────────────────────┘
```

---

## What Users Will Know

By accepting T&C, users acknowledge:

✅ **Credit System**
- Messages cost credits based on tokens
- 1 credit = ₹4.15
- Non-refundable

✅ **Memory System**
- Thread Memory = current conversation only
- Chat Memory = across all conversations
- Can toggle anytime

✅ **Costs**
- Chat: Free to tiny amounts (tokens)
- Images: 1 credit
- Videos: 8 credits
- Audio: 3 credits

✅ **Privacy & Security**
- Conversations may improve AI
- Data is encrypted
- Can request deletion

✅ **Liability**
- AI provided "as-is"
- Not liable for errors
- Use at your own risk

---

## Benefits

1. **Legal Protection**: Users explicitly accept terms
2. **Transparency**: Users know credit costs upfront
3. **Accountability**: Clear guidelines on AI usage
4. **Compliance**: Can comply with app store requirements
5. **User Trust**: Shows professionalism

---

## Implementation Checklist

- [ ] Add `_acceptedTerms` and `_showTermsError` state
- [ ] Create `_showTermsDialog()` method
- [ ] Add checkbox UI to sign-in form
- [ ] Add validation to `_handleEmailAuth()`
- [ ] Add validation to `_signInWithGoogle()`
- [ ] Add validation to `_signInAsGuest()`
- [ ] (Optional) Store acceptance in Firestore
- [ ] Test all three sign-in methods
- [ ] Test checkbox toggle
- [ ] Test T&C dialog

---

## Notes

- Checkbox must be checked before ANY sign-in method works
- Dialog appears when user clicks checkbox or text
- Error message shows if user tries to sign in without accepting
- Can use this to update T&C in future by changing version

