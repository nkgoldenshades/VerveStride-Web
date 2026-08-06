const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const crypto = require('crypto');

admin.initializeApp();

// ═══════════════════════════════════════════════════════════════════════════
// RATE LIMITING — Firestore-based, no extra dependencies, works everywhere
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Check rate limit for a user + action combination.
 * Uses a sliding window stored in Firestore under rate_limits/{uid}_{action}.
 *
 * @param {string} uid        - Firebase user ID
 * @param {string} action     - Action name e.g. 'deductCredits'
 * @param {number} maxCalls   - Max allowed calls in the window
 * @param {number} windowSecs - Window size in seconds
 */
async function checkRateLimit(uid, action, maxCalls, windowSecs) {
  const key = `${uid}_${action}`;
  const ref = admin.firestore().collection('rate_limits').doc(key);
  const now = Date.now();
  const windowMs = windowSecs * 1000;

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : { calls: [], updatedAt: now };

    // Keep only calls within the current window
    const recent = (data.calls || []).filter(t => now - t < windowMs);

    if (recent.length >= maxCalls) {
      const oldestCall = Math.min(...recent);
      const retryAfterSecs = Math.ceil((oldestCall + windowMs - now) / 1000);
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Too many requests. Try again in ${retryAfterSecs} seconds.`
      );
    }

    recent.push(now);
    tx.set(ref, { calls: recent, updatedAt: now }, { merge: false });
  });
}

// Rate limit configs per action
const RATE_LIMITS = {
  claimDailyBonus:      { maxCalls: 3,   windowSecs: 60  }, // 3/min (idempotent anyway)
  deductCredits:        { maxCalls: 30,  windowSecs: 60  }, // 30/min
  refundCredits:        { maxCalls: 10,  windowSecs: 60  }, // 10/min
  addCredits:           { maxCalls: 5,   windowSecs: 60  }, // 5/min
  activateSubscription: { maxCalls: 5,   windowSecs: 60  }, // 5/min
  grantWelcomeCredits:  { maxCalls: 3,   windowSecs: 3600}, // 3/hour
  secureAIChat:         { maxCalls: 60,  windowSecs: 60  }, // 60/min
  secureImageGeneration:{ maxCalls: 10,  windowSecs: 60  }, // 10/min
  secureVideoGeneration:{ maxCalls: 5,   windowSecs: 60  }, // 5/min
};

// Lazy Razorpay initialization - avoids crash when env vars not set at load time
function getRazorpayInstance() {
  const razorpayKeyId = process.env.RAZORPAY_KEY_ID;
  const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET;

  if (!razorpayKeyId || !razorpayKeySecret) {
    throw new functions.https.HttpsError('internal', 'Razorpay keys not configured');
  }

  return new Razorpay({
    key_id: razorpayKeyId,
    key_secret: razorpayKeySecret,
  });
}

// Subscription plan configurations (must match client-side)
const SUBSCRIPTION_PLANS = {
  'pro_monthly': { tier: 'Pro', durationDays: 30 },
  'pro_yearly': { tier: 'Pro', durationDays: 365 },
  'elite_monthly': { tier: 'Elite', durationDays: 30 },
  'elite_yearly': { tier: 'Elite', durationDays: 365 },
  'lifetime': { tier: 'Lifetime', durationDays: null },
  'remove_ads': { tier: 'No Ads', durationDays: null },
};

// ═══════════════════════════════════════════════════════════════════════════
// SUBSCRIPTION MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Activate subscription after successful payment
 * Called from client after Razorpay payment success
 */
exports.activateSubscription = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  const { paymentId, planKey } = data;
  const userId = context.auth.uid;
  await checkRateLimit(userId, 'activateSubscription', RATE_LIMITS.activateSubscription.maxCalls, RATE_LIMITS.activateSubscription.windowSecs);

  // Validate plan
  const plan = SUBSCRIPTION_PLANS[planKey];
  if (!plan) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid subscription plan');
  }

  try {
    // Verify payment with Razorpay
    const payment = await getRazorpayInstance().payments.fetch(paymentId);
    
    if (payment.status !== 'captured' && payment.status !== 'authorized') {
      throw new functions.https.HttpsError('failed-precondition', 'Payment not successful');
    }

    // Idempotency — prevent double-activation with same paymentId
    const existingPayment = await admin.firestore().collection('payments').doc(paymentId).get();
    if (existingPayment.exists) {
      const existing = existingPayment.data();
      if (existing.userId === userId) {
        return { success: true, alreadyActivated: true, subscription: existing.subscription || {} };
      }
      throw new functions.https.HttpsError('permission-denied', 'Payment already used by another account');
    }

    // Calculate dates
    const now = admin.firestore.Timestamp.now();
    const startDate = now;
    const expiresAt = plan.durationDays 
      ? admin.firestore.Timestamp.fromMillis(now.toMillis() + (plan.durationDays * 24 * 60 * 60 * 1000))
      : null; // null = permanent (lifetime)

    // Update user subscription in Firestore
    await admin.firestore().collection('Users').doc(userId).set({
      subscription: {
        planKey,
        tier: plan.tier,
        startDate,
        expiresAt,
        status: 'active',
        paymentId,
        updatedAt: now,
      },
      updatedAt: now,
    }, { merge: true });

    // Log transaction
    await admin.firestore().collection('transactions').add({
      userId,
      type: 'subscription',
      planKey,
      tier: plan.tier,
      amount: payment.amount / 100, // Convert paise to rupees
      currency: payment.currency,
      paymentId,
      razorpayOrderId: payment.order_id,
      status: 'completed',
      timestamp: now,
      metadata: {
        method: payment.method,
        email: payment.email,
        contact: payment.contact,
      },
    });

    // Log payment
    await admin.firestore().collection('payments').doc(paymentId).set({
      userId,
      razorpayPaymentId: paymentId,
      razorpayOrderId: payment.order_id,
      amount: payment.amount / 100,
      currency: payment.currency,
      status: payment.status,
      method: payment.method,
      type: 'subscription',
      planKey,
      createdAt: now,
    });

    console.log(`✅ Subscription activated for user ${userId}`);

    return {
      success: true,
      subscription: {
        planKey,
        tier: plan.tier,
        startDate: startDate.toMillis(),
        expiresAt: expiresAt ? expiresAt.toMillis() : null,
      },
    };
  } catch (error) {
    console.error('Error activating subscription:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Get user subscription status
 * Called from client to sync subscription state
 */
exports.getSubscriptionStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const userId = context.auth.uid;

  try {
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    
    if (!userDoc.exists) {
      return {
        subscription: null,
        credits: { available: 0 },
      };
    }

    const userData = userDoc.data();
    const subscription = userData.subscription || null;
    const credits = userData.credits || { available: 0 };

    // Check if subscription is expired
    if (subscription && subscription.expiresAt) {
      const now = admin.firestore.Timestamp.now();
      if (subscription.expiresAt.toMillis() < now.toMillis()) {
        subscription.status = 'expired';
      }
    }

    return {
      subscription,
      credits,
    };
  } catch (error) {
    console.error('Error getting subscription status:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// SECURE CREDIT MANAGEMENT — backend-only writes to Users/{uid}.credits
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Daily login bonus — 1 credit per day, max once per calendar day
 * Call this on every app open; idempotent within the same day
 */
exports.claimDailyBonus = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  await checkRateLimit(uid, 'claimDailyBonus', RATE_LIMITS.claimDailyBonus.maxCalls, RATE_LIMITS.claimDailyBonus.windowSecs);
  const ref = admin.firestore().collection('Users').doc(uid);

  const today = new Date().toISOString().slice(0, 10); // "2026-04-24"
  const DAILY_BONUS = 1;

  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const doc = snap.data() || {};
    const credits = doc.credits || {};
    const lastBonus = credits.lastDailyBonus || '';

    if (lastBonus === today) {
      return { granted: false, available: credits.available || 0, nextBonusIn: 'tomorrow' };
    }

    const next = (credits.available || 0) + DAILY_BONUS;
    tx.set(ref, {
      credits: {
        available: next,
        totalPurchased: credits.totalPurchased || 0,
        totalUsed: credits.totalUsed || 0,
        welcomeGranted: credits.welcomeGranted || true,
        lastDailyBonus: today,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { granted: true, available: next, bonusAmount: DAILY_BONUS };
  });

  return { success: true, ...result };
});

exports.grantWelcomeCredits = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  await checkRateLimit(uid, 'grantWelcomeCredits', RATE_LIMITS.grantWelcomeCredits.maxCalls, RATE_LIMITS.grantWelcomeCredits.windowSecs);

  // Only grant to real accounts (email verified or phone), not anonymous
  const isAnonymous = context.auth.token.firebase?.sign_in_provider === 'anonymous';
  const emailVerified = context.auth.token.email_verified === true;
  const hasPhone = !!context.auth.token.phone_number;

  if (isAnonymous) {
    const ref = admin.firestore().collection('Users').doc(uid);
    const snap = await ref.get();
    const existing = snap.data()?.credits;
    if (existing?.welcomeGranted) return { success: true, credits: { granted: false, available: existing.available || 0, precise: existing.precise || existing.available || 0 } };
    await ref.set({ credits: { available: 5, precise: 5.0, totalPurchased: 0, totalUsed: 0, welcomeGranted: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return { success: true, credits: { granted: true, available: 5, precise: 5.0 } };
  }

  if (!emailVerified && !hasPhone) {
    const ref = admin.firestore().collection('Users').doc(uid);
    const snap = await ref.get();
    const existing = snap.data()?.credits;
    if (existing?.welcomeGranted) return { success: true, credits: { granted: false, available: existing.available || 0, precise: existing.precise || existing.available || 0 } };
    await ref.set({ credits: { available: 5, precise: 5.0, totalPurchased: 0, totalUsed: 0, welcomeGranted: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    return { success: true, credits: { granted: true, available: 5, precise: 5.0 } };
  }

  const ref = admin.firestore().collection('Users').doc(uid);
  const WELCOME = 20;

  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const doc = snap.data() || {};
    const credits = doc.credits || {};
    if (credits.welcomeGranted === true) {
      return { granted: false, available: credits.available || 0, precise: credits.precise || credits.available || 0 };
    }
    const currentAvailable = credits.available || 0;
    const currentPrecise = credits.precise || currentAvailable;
    const nextAvailable = currentAvailable + WELCOME;
    const nextPrecise = currentPrecise + WELCOME;
    
    tx.set(ref, {
      credits: {
        available: nextAvailable,
        precise: nextPrecise,
        totalPurchased: credits.totalPurchased || 0,
        totalUsed: credits.totalUsed || 0,
        welcomeGranted: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { granted: true, available: nextAvailable, precise: nextPrecise };
  });

  return { success: true, credits: result };
});

exports.deductCredits = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  await checkRateLimit(uid, 'deductCredits', RATE_LIMITS.deductCredits.maxCalls, RATE_LIMITS.deductCredits.windowSecs);
  const amount = Number(data?.amount);
  const description = typeof data?.description === 'string' ? data.description : 'AI usage';
  
  // Validate amount - must be a positive number (can be fractional)
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', `Invalid amount: ${amount} (must be positive number)`);
  }

  const ref = admin.firestore().collection('Users').doc(uid);
  const usageRef = admin.firestore().collection('credit_usage').doc();

  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'User not found');
    const credits = snap.data().credits || {};
    
    // Support both integer and precise (fractional) credits
    const currentAvailable = Number(credits.available || 0);
    const currentPrecise = Number(credits.precise || currentAvailable);
    
    if (currentPrecise < amount) {
      throw new functions.https.HttpsError('failed-precondition', `Insufficient credits: have ${currentPrecise.toFixed(4)}, need ${amount.toFixed(4)}`);
    }
    
    const remainingPrecise = Math.max(0, currentPrecise - amount);
    const remainingAvailable = Math.ceil(remainingPrecise); // Round up for display
    
    tx.set(ref, {
      credits: {
        available: remainingAvailable,
        precise: remainingPrecise,
        totalPurchased: credits.totalPurchased || 0,
        totalUsed: (credits.totalUsed || 0) + amount,
        welcomeGranted: credits.welcomeGranted || true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    
    tx.set(usageRef, { 
      userId: uid, 
      amount, 
      description, 
      remainingPrecise,
      remainingAvailable,
      createdAt: admin.firestore.FieldValue.serverTimestamp() 
    });
    
    return { remaining: remainingPrecise, available: remainingAvailable };
  });

  return { success: true, credits: { remaining: result.remaining, available: result.available } };
});

exports.refundCredits = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  await checkRateLimit(uid, 'refundCredits', RATE_LIMITS.refundCredits.maxCalls, RATE_LIMITS.refundCredits.windowSecs);
  const amount = Number(data?.amount);
  const reason = typeof data?.reason === 'string' ? data.reason : 'Refund';
  if (!Number.isFinite(amount) || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');

  const ref = admin.firestore().collection('Users').doc(uid);
  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new functions.https.HttpsError('not-found', 'User not found');
    const credits = snap.data().credits || {};
    const next = (credits.available || 0) + amount;
    tx.set(ref, {
      credits: {
        available: next,
        totalPurchased: credits.totalPurchased || 0,
        totalUsed: credits.totalUsed || 0,
        welcomeGranted: credits.welcomeGranted || true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { total: next };
  });

  return { success: true, credits: { total: result.total } };
});

exports.addCredits = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  await checkRateLimit(uid, 'addCredits', RATE_LIMITS.addCredits.maxCalls, RATE_LIMITS.addCredits.windowSecs);
  const paymentId = (data?.paymentId || '').toString();
  const packageKey = (data?.packageKey || '').toString();
  if (!paymentId || !packageKey) throw new functions.https.HttpsError('invalid-argument', 'Missing paymentId or packageKey');

  // Server-side mapping — client cannot inflate credits
  // priceInr matches client-side CreditPackage definitions exactly
  const PACKAGES = {
    credits_50:  { credits: 50,  priceInr: 249  },
    credits_100: { credits: 100, priceInr: 415  },
    credits_250: { credits: 280, priceInr: 830  },  // 250 + 30 bonus
    credits_500: { credits: 575, priceInr: 1499 },  // 500 + 75 bonus
  };
  const pkg = PACKAGES[packageKey];
  if (!pkg) throw new functions.https.HttpsError('invalid-argument', 'Invalid packageKey');
  const creditsToAdd = pkg.credits;

  // ── Verify payment with Razorpay API ──────────────────────────────────────
  try {
    const razorpay = getRazorpayInstance();
    const payment = await razorpay.payments.fetch(paymentId);

    // Must be captured (successful)
    if (payment.status !== 'captured' && payment.status !== 'authorized') {
      throw new functions.https.HttpsError('failed-precondition', `Payment not successful: ${payment.status}`);
    }

    // Verify payment amount matches expected package price (±5% tolerance for currency rounding)
    const expectedPaise = pkg.priceInr * 100;
    const actualPaise = payment.amount;
    const tolerance = expectedPaise * 0.05;
    if (Math.abs(actualPaise - expectedPaise) > tolerance) {
      console.error(`Amount mismatch: expected ${expectedPaise} paise, got ${actualPaise} paise for package ${packageKey}`);
      throw new functions.https.HttpsError('failed-precondition', 'Payment amount does not match package price');
    }

    // Verify the payment belongs to this user
    const notesUid = payment.notes?.uid || payment.notes?.userId;
    if (notesUid && notesUid !== uid) {
      console.error(`Payment ${paymentId} belongs to ${notesUid}, not ${uid}`);
      throw new functions.https.HttpsError('permission-denied', 'Payment does not belong to this user');
    }
  } catch (err) {
    if (err instanceof functions.https.HttpsError) throw err;
    console.error('Razorpay verification error:', err.message);
    throw new functions.https.HttpsError('internal', 'Payment verification failed');
  }
  // ─────────────────────────────────────────────────────────────────────────

  const ref = admin.firestore().collection('Users').doc(uid);
  const paymentRef = admin.firestore().collection('creditPayments').doc(paymentId);

  const result = await admin.firestore().runTransaction(async (tx) => {
    const existing = await tx.get(paymentRef);
    if (existing.exists) {
      const snap = await tx.get(ref);
      return { added: false, available: (snap.data()?.credits?.available || 0) };
    }
    const snap = await tx.get(ref);
    const credits = snap.data()?.credits || {};
    const currentAvailable = credits.available || 0;
    const currentPrecise = credits.precise || currentAvailable;
    const nextAvailable = currentAvailable + creditsToAdd;
    const nextPrecise = currentPrecise + creditsToAdd;
    
    tx.set(ref, {
      credits: {
        available: nextAvailable,
        precise: nextPrecise,  // ⚠️ CRITICAL: Must track precise credits!
        totalPurchased: (credits.totalPurchased || 0) + creditsToAdd,
        totalUsed: credits.totalUsed || 0,
        welcomeGranted: credits.welcomeGranted || true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(paymentRef, { userId: uid, paymentId, packageKey, creditsAdded: creditsToAdd, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    return { added: true, available: nextAvailable, precise: nextPrecise, creditsAdded: creditsToAdd };
  });

  return { success: true, credits: { remaining: result.available, precise: result.precise, added: result.added, creditsAdded: result.creditsAdded || 0 } };
});

// ═══════════════════════════════════════════════════════════════════════════
// WEBHOOKS (Optional - for server-side payment verification)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Razorpay webhook handler
 * Verifies payment signatures and processes payments server-side
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
  const signature = req.headers['x-razorpay-signature'];

  if (!webhookSecret || !signature) {
    console.error('Missing webhook secret or signature');
    return res.status(400).send('Invalid request');
  }

  try {
    // Verify signature
    const body = JSON.stringify(req.body);
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(body)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.error('Invalid webhook signature');
      return res.status(400).send('Invalid signature');
    }

    const event = req.body.event;
    const payload = req.body.payload.payment.entity;

    console.log(`Webhook received: ${event}`);

    // Handle different events
    switch (event) {
      case 'payment.captured':
        // Payment successful - you can add additional processing here
        console.log(`Payment captured: ${payload.id}`);
        break;
      
      case 'payment.failed':
        // Payment failed - log for debugging
        console.log(`Payment failed: ${payload.id}`);
        break;
      
      default:
        console.log(`Unhandled event: ${event}`);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).send('Internal error');
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// SECURE AI CHAT FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Secure AI chat endpoint - all AI calls go through server-side validation
 * This prevents client-side API key exposure and ensures proper credit/subscription validation
 */
exports.secureAIChat = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  const { message, history, persona, userStyle, useWebSearch, modelId, languageId } = data;
  const userId = context.auth.uid;
  await checkRateLimit(userId, 'secureAIChat', RATE_LIMITS.secureAIChat.maxCalls, RATE_LIMITS.secureAIChat.windowSecs);

  // Validate input
  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Message is required');
  }

  if (message.length > 50000) {
    throw new functions.https.HttpsError('invalid-argument', 'Message too long. Please keep messages under 50,000 characters.');
  }

  try {
    console.log(`🤖 Secure AI chat request from user ${userId}`);
    
    // Get user document to check subscription and credits
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const subscription = userData.subscription || {};
    const credits = userData.credits || { available: 0 };

    // Check subscription status
    const now = admin.firestore.Timestamp.now();
    let hasUnlimitedAccess = false;
    
    if (subscription.status === 'active') {
      if (subscription.tier === 'Lifetime') {
        hasUnlimitedAccess = true;
      } else if (subscription.expiresAt && subscription.expiresAt.toMillis() > now.toMillis()) {
        hasUnlimitedAccess = subscription.tier === 'Pro' || subscription.tier === 'Elite';
      }
    }

    console.log(`🔒 User access: hasUnlimited=${hasUnlimitedAccess}, credits=${credits.available}`);

    // Determine credits needed based on model
    const modelConfig = getModelConfig(modelId);
    const creditsNeeded = modelConfig.creditsPerMessage || 1;

    // Check if user has access
    if (!hasUnlimitedAccess && credits.available < creditsNeeded) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient credits. You need ${creditsNeeded} credits but only have ${credits.available} available.`
      );
    }

    // Use @google-cloud/vertexai with correct model
    const { VertexAI } = require('@google-cloud/vertexai');
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
    const vertexAI = new VertexAI({ project, location: 'us-central1' });
    const systemPrompt = buildSystemPrompt(persona, userStyle, useWebSearch, languageId);

    const generativeModel = vertexAI.getGenerativeModel({
      model: modelConfig.googleModelId,
      systemInstruction: { parts: [{ text: systemPrompt }] },
      generationConfig: { temperature: 0.9, topK: 40, topP: 0.95, maxOutputTokens: 8192 },
    });

    // Build chat history
    const chatHistory = [];
    if (history && Array.isArray(history)) {
      for (const msg of history) {
        if (!msg.role || !msg.content) continue;
        if (msg.role === 'user') chatHistory.push({ role: 'user', parts: [{ text: msg.content }] });
        else if (msg.role === 'model' || msg.role === 'assistant') chatHistory.push({ role: 'model', parts: [{ text: msg.content }] });
      }
    }

    const chat = generativeModel.startChat({ history: chatHistory });
    console.log(`🤖 Calling Vertex AI: ${modelConfig.googleModelId}`);

    const response = await Promise.race([
      chat.sendMessage(message),
      new Promise((_, reject) => setTimeout(() => reject(new Error('AI request timed out')), 55000))
    ]);

    const responseText = response.response.text();
    if (!responseText) throw new Error('AI returned empty response');
    console.log(`✅ AI response: ${responseText.substring(0, 100)}...`);

    const usage = response.response.usageMetadata;
    const inputTokens = usage?.promptTokenCount || 0;
    const outputTokens = usage?.candidatesTokenCount || 0;
    
    // Calculate cost based on model pricing (per 1M tokens)
    const inputCostPer1M = modelConfig.category === 'pro' ? 1.25 : 0.30;
    const outputCostPer1M = modelConfig.category === 'pro' ? 10.00 : 2.50;
    
    const apiCostUsd = (inputTokens * inputCostPer1M / 1000000.0) + 
                       (outputTokens * outputCostPer1M / 1000000.0);
    
    // Convert to credits: $0.06 per credit
    const preciseCreditsUsed = apiCostUsd / 0.06;

    console.log(`💰 Token usage: ${inputTokens} in + ${outputTokens} out = ${preciseCreditsUsed.toFixed(4)} credits`);

    // Deduct credits if not unlimited access
    if (!hasUnlimitedAccess && preciseCreditsUsed > 0) {
      const newCredits = Math.max(0, credits.available - preciseCreditsUsed);
      
      await admin.firestore().collection('Users').doc(userId).update({
        'credits.available': newCredits,
        'credits.totalUsed': (credits.totalUsed || 0) + preciseCreditsUsed,
        'credits.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log usage
      await admin.firestore().collection('credit_usage').add({
        userId,
        amount: preciseCreditsUsed,
        description: 'AI Chat',
        modelId: modelConfig.id,
        inputTokens,
        outputTokens,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`💳 Deducted ${preciseCreditsUsed.toFixed(4)} credits from user ${userId}`);
    }

    return {
      success: true,
      text: responseText,
      creditsUsed: preciseCreditsUsed,
      inputTokens,
      outputTokens,
      modelUsed: modelConfig.displayName,
    };

  } catch (error) {
    console.error('❌ Secure AI chat error:', error);
    console.error('❌ Error message:', error.message);
    console.error('❌ Error code:', error.code);
    console.error('❌ Error stack:', error.stack);
    
    // Return user-friendly error messages
    const errorMessage = error.message || error.toString();
    if (errorMessage.includes('timeout') || errorMessage.includes('timed out')) {
      throw new functions.https.HttpsError('deadline-exceeded', 'AI request timed out. Please try a shorter message.');
    }
    if (errorMessage.includes('quota') || errorMessage.includes('billing') || errorMessage.includes('RESOURCE_EXHAUSTED')) {
      throw new functions.https.HttpsError('resource-exhausted', 'AI quota exceeded. Please try again later.');
    }
    if (errorMessage.includes('credits') || errorMessage.includes('Insufficient')) {
      throw new functions.https.HttpsError('failed-precondition', errorMessage);
    }
    if (errorMessage.includes('API has not been used') || errorMessage.includes('is not enabled') || errorMessage.includes('SERVICE_DISABLED')) {
      throw new functions.https.HttpsError('failed-precondition', 'Vertex AI API not enabled. Please enable it in Google Cloud Console.');
    }
    if (errorMessage.includes('PERMISSION_DENIED') || errorMessage.includes('permission')) {
      throw new functions.https.HttpsError('permission-denied', 'Permission denied. Check Cloud Function service account permissions.');
    }
    
    throw new functions.https.HttpsError('internal', `AI error: ${errorMessage}`);
  }
});

/**
 * Generate image using Vertex AI Imagen 3
 * Costs 10 credits per image
 */
exports.generateImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  
  const { prompt, width = 1024, height = 1024 } = data;
  const userId = context.auth.uid;
  
  // Rate limiting
  await checkRateLimit(userId, 'secureImageGeneration', RATE_LIMITS.secureImageGeneration.maxCalls, RATE_LIMITS.secureImageGeneration.windowSecs);

  // Validate input
  if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
  }

  if (prompt.length > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt too long. Maximum 1000 characters.');
  }

  try {
    console.log(`🎨 Image generation request from user ${userId}: ${prompt.substring(0, 50)}...`);
    
    // Check user credits
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const credits = userData.credits || { available: 0 };
    const CREDITS_NEEDED = 10;

    if (credits.available < CREDITS_NEEDED) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient credits. You need ${CREDITS_NEEDED} credits but only have ${credits.available} available.`
      );
    }

    // Use Vertex AI Imagen 3
    const { VertexAI } = require('@google-cloud/vertexai');
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
    const vertexAI = new VertexAI({ project, location: 'us-central1' });
    
    const imageModel = vertexAI.getGenerativeModel({
      model: 'imagen-3.0-generate-001',
    });

    console.log(`🎨 Calling Vertex AI Imagen 3...`);
    
    const result = await imageModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        numberOfImages: 1,
        width,
        height,
      },
    });

    // Extract image data
    const imagePart = result.response.candidates[0].content.parts[0];
    if (!imagePart.inlineData || !imagePart.inlineData.data) {
      throw new Error('No image data returned from Vertex AI');
    }

    const imageBase64 = imagePart.inlineData.data;
    console.log(`✅ Image generated successfully`);

    // Deduct credits
    const newCredits = Math.max(0, credits.available - CREDITS_NEEDED);
    await admin.firestore().collection('Users').doc(userId).update({
      'credits.available': newCredits,
      'credits.totalUsed': (credits.totalUsed || 0) + CREDITS_NEEDED,
      'credits.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log usage
    await admin.firestore().collection('credit_usage').add({
      userId,
      amount: CREDITS_NEEDED,
      description: 'Image generation',
      prompt: prompt.substring(0, 100),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`💳 Deducted ${CREDITS_NEEDED} credits from user ${userId}`);

    return {
      success: true,
      image: imageBase64,
      creditsUsed: CREDITS_NEEDED,
    };

  } catch (error) {
    console.error('❌ Image generation error:', error);
    
    const errorMessage = error.message || error.toString();
    if (errorMessage.includes('quota') || errorMessage.includes('billing')) {
      throw new functions.https.HttpsError('resource-exhausted', 'Image generation quota exceeded. Please try again later.');
    }
    if (errorMessage.includes('credits') || errorMessage.includes('Insufficient')) {
      throw new functions.https.HttpsError('failed-precondition', errorMessage);
    }
    
    throw new functions.https.HttpsError('internal', `Image generation error: ${errorMessage}`);
  }
});

/**
 * Generate video using Vertex AI Veo
 * Costs 50 credits per video
 */
exports.generateVideo = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  
  const { prompt, duration = 5 } = data;
  const userId = context.auth.uid;
  
  // Rate limiting
  await checkRateLimit(userId, 'secureImageGeneration', RATE_LIMITS.secureImageGeneration.maxCalls, RATE_LIMITS.secureImageGeneration.windowSecs);

  // Validate input
  if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
  }

  if (prompt.length > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt too long. Maximum 1000 characters.');
  }

  if (duration < 1 || duration > 30) {
    throw new functions.https.HttpsError('invalid-argument', 'Duration must be between 1 and 30 seconds');
  }

  try {
    console.log(`🎬 Video generation request from user ${userId}: ${prompt.substring(0, 50)}...`);
    
    // Check user credits
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const credits = userData.credits || { available: 0 };
    const CREDITS_NEEDED = 50;

    if (credits.available < CREDITS_NEEDED) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient credits. You need ${CREDITS_NEEDED} credits but only have ${credits.available} available.`
      );
    }

    // Use Vertex AI Veo (video generation)
    const { VertexAI } = require('@google-cloud/vertexai');
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
    const vertexAI = new VertexAI({ project, location: 'us-central1' });
    
    const videoModel = vertexAI.getGenerativeModel({
      model: 'veo-001',
    });

    console.log(`🎬 Calling Vertex AI Veo...`);
    
    const result = await videoModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        duration: duration,
      },
    });

    // Extract video URL
    const videoPart = result.response.candidates[0].content.parts[0];
    if (!videoPart.fileData || !videoPart.fileData.fileUri) {
      throw new Error('No video data returned from Vertex AI');
    }

    const videoUrl = videoPart.fileData.fileUri;
    console.log(`✅ Video generated successfully: ${videoUrl}`);

    // Deduct credits
    const newCredits = Math.max(0, credits.available - CREDITS_NEEDED);
    await admin.firestore().collection('Users').doc(userId).update({
      'credits.available': newCredits,
      'credits.totalUsed': (credits.totalUsed || 0) + CREDITS_NEEDED,
      'credits.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log usage
    await admin.firestore().collection('credit_usage').add({
      userId,
      amount: CREDITS_NEEDED,
      description: 'Video generation',
      prompt: prompt.substring(0, 100),
      duration,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`💳 Deducted ${CREDITS_NEEDED} credits from user ${userId}`);

    return {
      success: true,
      videoUrl,
      creditsUsed: CREDITS_NEEDED,
    };

  } catch (error) {
    console.error('❌ Video generation error:', error);
    
    const errorMessage = error.message || error.toString();
    if (errorMessage.includes('quota') || errorMessage.includes('billing') || errorMessage.includes('RESOURCE_EXHAUSTED')) {
      throw new functions.https.HttpsError('resource-exhausted', 'Video generation quota exceeded. Please try again later.');
    }
    if (errorMessage.includes('credits') || errorMessage.includes('Insufficient')) {
      throw new functions.https.HttpsError('failed-precondition', errorMessage);
    }
    if (errorMessage.includes('API has not been used') || errorMessage.includes('is not enabled')) {
      throw new functions.https.HttpsError('failed-precondition', 'Veo API not enabled. Please enable it in Google Cloud Console.');
    }
    
    throw new functions.https.HttpsError('internal', `Video generation error: ${errorMessage}`);
  }
});

/**
 * Generate audio/music using Vertex AI MusicLM or MusicFX
 * Costs 20 credits per audio
 */
exports.generateAudio = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  
  const { prompt, duration = 30 } = data;
  const userId = context.auth.uid;
  
  // Rate limiting (reuse image generation rate limit)
  await checkRateLimit(userId, 'secureImageGeneration', RATE_LIMITS.secureImageGeneration.maxCalls, RATE_LIMITS.secureImageGeneration.windowSecs);

  // Validate input
  if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
  }

  if (prompt.length > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt too long. Maximum 1000 characters.');
  }

  if (duration < 10 || duration > 120) {
    throw new functions.https.HttpsError('invalid-argument', 'Duration must be between 10 and 120 seconds');
  }

  try {
    console.log(`🎵 Audio generation request from user ${userId}: ${prompt.substring(0, 50)}... (${duration}s)`);
    
    // Check user credits
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const credits = userData.credits || { available: 0 };
    const CREDITS_NEEDED = 20;

    if (credits.available < CREDITS_NEEDED) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient credits. You need ${CREDITS_NEEDED} credits but only have ${credits.available} available.`
      );
    }

    // Use Vertex AI Lyria 3 Pro for audio generation (up to 180 seconds)
    const { VertexAI } = require('@google-cloud/vertexai');
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
    const vertexAI = new VertexAI({ project, location: 'us-central1' });
    
    // Use Lyria 3 Pro (supports up to 180 seconds)
    const audioModel = vertexAI.getGenerativeModel({
      model: 'lyria-3-pro',
    });

    console.log(`🎵 Calling Vertex AI Lyria 3 Pro...`);
    
    const result = await audioModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        duration: duration,
      },
    });

    // Extract audio URL
    const candidate = result.response.candidates[0];
    if (!candidate || !candidate.content || !candidate.content.parts || candidate.content.parts.length === 0) {
      throw new Error('No audio data returned from Vertex AI');
    }

    const audioPart = candidate.content.parts[0];
    if (!audioPart.fileData || !audioPart.fileData.fileUri) {
      throw new Error('No audio URL in response');
    }

    const audioUrl = audioPart.fileData.fileUri;
    console.log(`✅ Audio generated successfully: ${audioUrl}`);

    // Deduct credits
    const newCredits = Math.max(0, credits.available - CREDITS_NEEDED);
    await admin.firestore().collection('Users').doc(userId).update({
      'credits.available': newCredits,
      'credits.totalUsed': (credits.totalUsed || 0) + CREDITS_NEEDED,
      'credits.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log usage
    await admin.firestore().collection('credit_usage').add({
      userId,
      amount: CREDITS_NEEDED,
      description: 'Audio Generation',
      prompt: prompt.substring(0, 100),
      duration,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`💳 Deducted ${CREDITS_NEEDED} credits from user ${userId}`);

    return {
      success: true,
      audioUrl,
      creditsUsed: CREDITS_NEEDED,
    };

  } catch (error) {
    console.error('❌ Audio generation error:', error);
    console.error('❌ Error details:', error.message);
    
    const errorMessage = error.message || error.toString();
    if (errorMessage.includes('quota') || errorMessage.includes('billing') || errorMessage.includes('RESOURCE_EXHAUSTED')) {
      throw new functions.https.HttpsError('resource-exhausted', 'Audio generation quota exceeded. Please try again later.');
    }
    if (errorMessage.includes('credits') || errorMessage.includes('Insufficient')) {
      throw new functions.https.HttpsError('failed-precondition', errorMessage);
    }
    if (errorMessage.includes('API has not been used') || errorMessage.includes('is not enabled')) {
      throw new functions.https.HttpsError('failed-precondition', 'Lyria API not enabled. Please enable it in Google Cloud Console.');
    }
    
    throw new functions.https.HttpsError('internal', `Audio generation error: ${errorMessage}`);
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// REFERRAL SYSTEM
// ═══════════════════════════════════════════════════════════════════════════

const REFERRAL_BONUS = 10; // credits for both referrer and new user

/**
 * Get or create a referral code for the current user.
 * Code is stored in Users/{uid}.referralCode
 */
exports.getReferralCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const uid = context.auth.uid;
  const ref = admin.firestore().collection('Users').doc(uid);

  const snap = await ref.get();
  const existing = snap.data()?.referralCode;
  if (existing) return { success: true, code: existing };

  // Generate a short unique code: first 6 chars of uid + 4 random chars
  const code = (uid.substring(0, 6) + Math.random().toString(36).substring(2, 6)).toUpperCase();

  await ref.set({ referralCode: code, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  // Also index by code for fast lookup
  await admin.firestore().collection('referralCodes').doc(code).set({ uid, createdAt: admin.firestore.FieldValue.serverTimestamp() });

  return { success: true, code };
});

/**
 * Apply a referral code after signup.
 * - Validates code exists and belongs to a different user
 * - Idempotent: each user can only use one referral code
 * - Both referrer and new user get REFERRAL_BONUS credits
 */
exports.applyReferralCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Login required');
  const newUserUid = context.auth.uid;
  const code = (data?.code || '').toString().trim().toUpperCase();

  if (!code || code.length < 4) throw new functions.https.HttpsError('invalid-argument', 'Invalid referral code');

  // Look up who owns this code
  const codeDoc = await admin.firestore().collection('referralCodes').doc(code).get();
  if (!codeDoc.exists) throw new functions.https.HttpsError('not-found', 'Referral code not found');

  const referrerUid = codeDoc.data().uid;
  if (referrerUid === newUserUid) throw new functions.https.HttpsError('invalid-argument', 'Cannot use your own referral code');

  const newUserRef = admin.firestore().collection('Users').doc(newUserUid);
  const referrerRef = admin.firestore().collection('Users').doc(referrerUid);
  const referralRef = admin.firestore().collection('referrals').doc(`${code}_${newUserUid}`);

  await admin.firestore().runTransaction(async (tx) => {
    // Check idempotency — has this user already used a referral?
    const newUserSnap = await tx.get(newUserRef);
    const newUserData = newUserSnap.data() || {};
    if (newUserData.referredBy) throw new functions.https.HttpsError('already-exists', 'You have already used a referral code');

    // Check referral record doesn't exist
    const refSnap = await tx.get(referralRef);
    if (refSnap.exists) throw new functions.https.HttpsError('already-exists', 'Referral already applied');

    // Add credits to new user
    const newCredits = newUserData.credits || {};
    tx.set(newUserRef, {
      credits: {
        available: (newCredits.available || 0) + REFERRAL_BONUS,
        totalPurchased: newCredits.totalPurchased || 0,
        totalUsed: newCredits.totalUsed || 0,
        welcomeGranted: newCredits.welcomeGranted || true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      referredBy: referrerUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Add credits to referrer
    const referrerSnap = await tx.get(referrerRef);
    const referrerData = referrerSnap.data() || {};
    const refCredits = referrerData.credits || {};
    tx.set(referrerRef, {
      credits: {
        available: (refCredits.available || 0) + REFERRAL_BONUS,
        totalPurchased: refCredits.totalPurchased || 0,
        totalUsed: refCredits.totalUsed || 0,
        welcomeGranted: refCredits.welcomeGranted || true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Log the referral
    tx.set(referralRef, {
      code,
      referrerUid,
      newUserUid,
      bonusEach: REFERRAL_BONUS,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true, bonusCredits: REFERRAL_BONUS };
});

// ═══════════════════════════════════════════════════════════════════════════
// AI VOICE GENERATION
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Generate premium AI voice using ElevenLabs or Google Cloud TTS
 * Server-side to protect API keys and ensure proper billing
 */
exports.generateAIVoice = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { text, voiceId, provider, voiceModel } = data;
  const userId = context.auth.uid;

  // Validate input
  if (!text || typeof text !== 'string' || text.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Text is required');
  }

  if (text.length > 5000) {
    throw new functions.https.HttpsError('invalid-argument', 'Text too long. Maximum 5000 characters.');
  }

  try {
    console.log(`🎙️ AI Voice generation request from user ${userId}, provider: ${provider}`);
    
    // Get user document to check subscription and credits
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const subscription = userData.subscription || {};
    const credits = userData.credits || { available: 0 };

    // Check subscription status for premium voices
    const now = admin.firestore.Timestamp.now();
    let hasUnlimitedAccess = false;
    
    if (subscription.status === 'active') {
      if (subscription.tier === 'Lifetime') {
        hasUnlimitedAccess = true;
      } else if (subscription.expiresAt && subscription.expiresAt.toMillis() > now.toMillis()) {
        hasUnlimitedAccess = subscription.tier === 'Elite';
      }
    }

    // Calculate credits needed based on text length and provider
    const estimatedMinutes = text.length / 1000.0; // Rough estimate
    const creditsPerMinute = provider === 'elevenlabs' ? 2.0 : 1.0;
    const creditsNeeded = estimatedMinutes * creditsPerMinute;

    console.log(`🔒 Voice access check: hasUnlimited=${hasUnlimitedAccess}, credits=${credits.available}, needed=${creditsNeeded}`);

    // Check if user has access
    if (!hasUnlimitedAccess && credits.available < creditsNeeded) {
      throw new functions.https.HttpsError(
        'failed-precondition', 
        `Insufficient credits. You need ${creditsNeeded.toFixed(2)} credits for AI voice generation.`
      );
    }

    let audioData;

    if (provider === 'elevenlabs') {
      audioData = await generateElevenLabsVoice(text, voiceId);
    } else if (provider === 'google_cloud') {
      audioData = await generateGoogleCloudVoice(text, voiceId);
    } else {
      throw new functions.https.HttpsError('invalid-argument', 'Unsupported voice provider');
    }

    if (!audioData) {
      throw new functions.https.HttpsError('internal', 'Failed to generate voice audio');
    }

    // Deduct credits if not unlimited access
    if (!hasUnlimitedAccess && creditsNeeded > 0) {
      const newCredits = Math.max(0, credits.available - creditsNeeded);
      
      await admin.firestore().collection('Users').doc(userId).update({
        'credits.available': newCredits,
        'credits.totalUsed': (credits.totalUsed || 0) + creditsNeeded,
        'credits.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log usage
      await admin.firestore().collection('credit_usage').add({
        userId,
        amount: creditsNeeded,
        description: `AI Voice: ${voiceModel}`,
        provider,
        textLength: text.length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`💳 Deducted ${creditsNeeded.toFixed(2)} credits from user ${userId}`);
    }

    // Return base64 encoded audio
    return {
      success: true,
      audioData: audioData.toString('base64'),
      provider,
      voiceModel,
      creditsUsed: creditsNeeded,
    };

  } catch (error) {
    console.error('❌ AI Voice generation error:', error);
    
    if (error.code) {
      throw error; // Re-throw Firebase errors
    }
    
    throw new functions.https.HttpsError('internal', 'Voice generation failed');
  }
});

/**
 * Generate voice using ElevenLabs API
 */
async function generateElevenLabsVoice(text, voiceId) {
  const elevenLabsApiKey = process.env.ELEVENLABS_API_KEY;
  
  if (!elevenLabsApiKey) {
    throw new functions.https.HttpsError('internal', 'ElevenLabs API key not configured');
  }

  const response = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
    method: 'POST',
    headers: {
      'Accept': 'audio/mpeg',
      'Content-Type': 'application/json',
      'xi-api-key': elevenLabsApiKey,
    },
    body: JSON.stringify({
      text: text,
      model_id: 'eleven_monolingual_v1',
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.5,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('ElevenLabs API error:', response.status, errorText);
    throw new Error(`ElevenLabs API error: ${response.status}`);
  }

  return Buffer.from(await response.arrayBuffer());
}

/**
 * Generate voice using Google Cloud Text-to-Speech
 */
async function generateGoogleCloudVoice(text, voiceId) {
  const { TextToSpeechClient } = require('@google-cloud/text-to-speech');
  
  const client = new TextToSpeechClient();

  const request = {
    input: { text: text },
    voice: { 
      name: voiceId,
      languageCode: voiceId.startsWith('en-') ? voiceId.substring(0, 5) : 'en-US',
    },
    audioConfig: { 
      audioEncoding: 'MP3',
      effectsProfileId: ['telephony-class-application'],
      pitch: 0,
      speakingRate: 1.0,
    },
  };

  const [response] = await client.synthesizeSpeech(request);
  return response.audioContent;
}


// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
// IMAGE & VIDEO GENERATION
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Generate image using Vertex AI Imagen 3
 * Costs 20 credits per image
 */
exports.generateImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  
  const { prompt } = data;
  const userId = context.auth.uid;
  
  // Rate limiting
  await checkRateLimit(userId, 'secureImageGeneration', RATE_LIMITS.secureImageGeneration.maxCalls, RATE_LIMITS.secureImageGeneration.windowSecs);

  // Validate input
  if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
  }

  if (prompt.length > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt too long. Maximum 1000 characters.');
  }

  try {
    console.log(`🎨 Image generation request from user ${userId}: ${prompt.substring(0, 50)}...`);
    
    // Check user credits
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const credits = userData.credits || { available: 0 };
    const CREDITS_NEEDED = 20;

    if (credits.available < CREDITS_NEEDED) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient credits. You need ${CREDITS_NEEDED} credits but only have ${credits.available} available.`
      );
    }

    // Use Vertex AI Imagen 3
    const { VertexAI } = require('@google-cloud/vertexai');
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
    const vertexAI = new VertexAI({ project, location: 'us-central1' });
    
    const imageModel = vertexAI.getGenerativeModel({
      model: 'imagen-3.0-generate-001',
    });

    console.log(`🎨 Calling Vertex AI Imagen 3...`);
    
    const result = await imageModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        numberOfImages: 1,
      },
    });

    // Extract image data
    const candidate = result.response.candidates[0];
    if (!candidate || !candidate.content || !candidate.content.parts || candidate.content.parts.length === 0) {
      throw new Error('No image data returned from Vertex AI');
    }

    const imagePart = candidate.content.parts[0];
    if (!imagePart.inlineData || !imagePart.inlineData.data) {
      throw new Error('No image data in response');
    }

    const imageBase64 = imagePart.inlineData.data;
    console.log(`✅ Image generated successfully (${imageBase64.length} bytes)`);

    // Deduct credits
    const newCredits = Math.max(0, credits.available - CREDITS_NEEDED);
    await admin.firestore().collection('Users').doc(userId).update({
      'credits.available': newCredits,
      'credits.totalUsed': (credits.totalUsed || 0) + CREDITS_NEEDED,
      'credits.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log usage
    await admin.firestore().collection('credit_usage').add({
      userId,
      amount: CREDITS_NEEDED,
      description: 'Image Generation',
      prompt: prompt.substring(0, 100),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`💳 Deducted ${CREDITS_NEEDED} credits from user ${userId}`);

    return {
      success: true,
      image: imageBase64,
      creditsUsed: CREDITS_NEEDED,
    };

  } catch (error) {
    console.error('❌ Image generation error:', error);
    console.error('❌ Error details:', error.message);
    
    const errorMessage = error.message || error.toString();
    if (errorMessage.includes('quota') || errorMessage.includes('billing') || errorMessage.includes('RESOURCE_EXHAUSTED')) {
      throw new functions.https.HttpsError('resource-exhausted', 'Image generation quota exceeded. Please try again later.');
    }
    if (errorMessage.includes('credits') || errorMessage.includes('Insufficient')) {
      throw new functions.https.HttpsError('failed-precondition', errorMessage);
    }
    if (errorMessage.includes('API has not been used') || errorMessage.includes('is not enabled')) {
      throw new functions.https.HttpsError('failed-precondition', 'Imagen API not enabled. Please enable it in Google Cloud Console.');
    }
    
    throw new functions.https.HttpsError('internal', `Image generation error: ${errorMessage}`);
  }
});

/**
 * Generate video using Vertex AI Veo
 * Costs 50 credits per video
 */
exports.generateVideo = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  
  const { prompt, duration = 5 } = data;
  const userId = context.auth.uid;
  
  // Rate limiting
  await checkRateLimit(userId, 'secureVideoGeneration', RATE_LIMITS.secureVideoGeneration.maxCalls, RATE_LIMITS.secureVideoGeneration.windowSecs);

  // Validate input
  if (!prompt || typeof prompt !== 'string' || prompt.trim().length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt is required');
  }

  if (prompt.length > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'Prompt too long. Maximum 1000 characters.');
  }

  if (duration < 1 || duration > 60) {
    throw new functions.https.HttpsError('invalid-argument', 'Duration must be between 1 and 60 seconds');
  }

  try {
    console.log(`🎬 Video generation request from user ${userId}: ${prompt.substring(0, 50)}... (${duration}s)`);
    
    // Check user credits
    const userDoc = await admin.firestore().collection('Users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User profile not found');
    }

    const userData = userDoc.data();
    const credits = userData.credits || { available: 0 };
    const CREDITS_NEEDED = 50;

    if (credits.available < CREDITS_NEEDED) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Insufficient credits. You need ${CREDITS_NEEDED} credits but only have ${credits.available} available.`
      );
    }

    // Use Vertex AI Veo (video generation)
    const { VertexAI } = require('@google-cloud/vertexai');
    const project = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
    const vertexAI = new VertexAI({ project, location: 'us-central1' });
    
    const videoModel = vertexAI.getGenerativeModel({
      model: 'veo-001',
    });

    console.log(`🎬 Calling Vertex AI Veo...`);
    
    const result = await videoModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        duration: duration,
      },
    });

    // Extract video URL
    const candidate = result.response.candidates[0];
    if (!candidate || !candidate.content || !candidate.content.parts || candidate.content.parts.length === 0) {
      throw new Error('No video data returned from Vertex AI');
    }

    const videoPart = candidate.content.parts[0];
    if (!videoPart.fileData || !videoPart.fileData.fileUri) {
      throw new Error('No video URL in response');
    }

    const videoUrl = videoPart.fileData.fileUri;
    console.log(`✅ Video generated successfully: ${videoUrl}`);

    // Deduct credits
    const newCredits = Math.max(0, credits.available - CREDITS_NEEDED);
    await admin.firestore().collection('Users').doc(userId).update({
      'credits.available': newCredits,
      'credits.totalUsed': (credits.totalUsed || 0) + CREDITS_NEEDED,
      'credits.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log usage
    await admin.firestore().collection('credit_usage').add({
      userId,
      amount: CREDITS_NEEDED,
      description: 'Video Generation',
      prompt: prompt.substring(0, 100),
      duration,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`💳 Deducted ${CREDITS_NEEDED} credits from user ${userId}`);

    return {
      success: true,
      videoUrl,
      creditsUsed: CREDITS_NEEDED,
    };

  } catch (error) {
    console.error('❌ Video generation error:', error);
    console.error('❌ Error details:', error.message);
    
    const errorMessage = error.message || error.toString();
    if (errorMessage.includes('quota') || errorMessage.includes('billing') || errorMessage.includes('RESOURCE_EXHAUSTED')) {
      throw new functions.https.HttpsError('resource-exhausted', 'Video generation quota exceeded. Please try again later.');
    }
    if (errorMessage.includes('credits') || errorMessage.includes('Insufficient')) {
      throw new functions.https.HttpsError('failed-precondition', errorMessage);
    }
    if (errorMessage.includes('API has not been used') || errorMessage.includes('is not enabled')) {
      throw new functions.https.HttpsError('failed-precondition', 'Veo API not enabled. Please enable it in Google Cloud Console.');
    }
    
    throw new functions.https.HttpsError('internal', `Video generation error: ${errorMessage}`);
  }
});

// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Get model configuration by ID
 */
function getModelConfig(modelId) {
  const models = {
    'vs_flash_lite': { id: 'vs_flash_lite', displayName: 'VerveStride AI Speed Lite', googleModelId: 'gemini-2.0-flash-lite', creditsPerMessage: 1, category: 'flash' },
    'vs_flash': { id: 'vs_flash', displayName: 'VerveStride AI Speed', googleModelId: 'gemini-2.0-flash', creditsPerMessage: 1, category: 'flash' },
    'vs_flash_2_0': { id: 'vs_flash_2_0', displayName: 'VerveStride AI Speed', googleModelId: 'gemini-2.0-flash', creditsPerMessage: 1, category: 'flash' },
    'vs_flash_2_0_lite': { id: 'vs_flash_2_0_lite', displayName: 'VerveStride AI Speed Lite', googleModelId: 'gemini-2.0-flash-lite', creditsPerMessage: 1, category: 'flash' },
    'vs_pro_2_5': { id: 'vs_pro_2_5', displayName: 'VerveStride AI Smart', googleModelId: 'gemini-2.5-pro', creditsPerMessage: 2, category: 'pro' },
    'vs_pro_25': { id: 'vs_pro_25', displayName: 'VerveStride AI Smart', googleModelId: 'gemini-2.5-pro', creditsPerMessage: 2, category: 'pro' },
    'vs_gemini3': { id: 'vs_gemini3', displayName: 'VerveStride AI Power', googleModelId: 'gemini-2.5-pro', creditsPerMessage: 3, category: 'pro' },
    'vs_vision': { id: 'vs_vision', displayName: 'VerveStride AI Vision', googleModelId: 'gemini-2.0-flash', creditsPerMessage: 1, category: 'vision' },
  };
  return models[modelId] || models['vs_flash'];
}

/**
 * Build system prompt for AI chat
 */
function buildSystemPrompt(persona, userStyle, useWebSearch, languageId) {
  let prompt = `You are VerveStride AI — a world-class AI assistant created by VerveStride.

IDENTITY RULES:
- You are VerveStride AI, created and trained by VerveStride
- You are NOT Gemini, NOT ChatGPT, NOT Claude, NOT any other AI
- NEVER mention Google, OpenAI, Anthropic, or any AI company
- If asked about your identity, say: "I'm VerveStride AI, created by VerveStride."

CORE CAPABILITIES:
- Expert-level knowledge across ALL domains
- High-quality code generation with proper formatting
- Creative content generation (stories, scripts, video concepts)
- Advanced formatting using markdown
- Context-aware response quality
- Step-by-step reasoning
- Never refuse reasonable requests

RESPONSE STYLE:
- Match the user's tone and style
- Be natural, conversational, and helpful
- Provide complete, accurate, actionable information
- Use markdown for formatting when appropriate

`;

  if (useWebSearch) {
    prompt += `\nWEB SEARCH: You have real-time internet access. Use it for current information.\n`;
  }

  if (persona) {
    prompt += `\nPERSONA: ${persona}\n`;
  }

  if (userStyle) {
    prompt += `\nUSER STYLE: ${userStyle}\n`;
  }

  return prompt;
}


// ═══════════════════════════════════════════════════════════════════════════
// REPLICATE API PROXY - Bypass CORS for image/video/audio generation
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Proxy for Replicate API to bypass CORS restrictions
 * Handles image, video, and audio generation
 */
exports.replicateProxy = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { action, model, input, predictionId } = data;
  const userId = context.auth.uid;
  
  // Rate limiting based on action type
  const rateLimitKey = action === 'create' ? 'replicateCreate' : 'replicateGet';
  const maxCalls = action === 'create' ? 10 : 60; // 10 creates/min, 60 gets/min
  await checkRateLimit(userId, rateLimitKey, maxCalls, 60);

  // Get API token from environment variables
  const REPLICATE_API_TOKEN = process.env.REPLICATE_API_TOKEN;
  if (!REPLICATE_API_TOKEN) {
    throw new functions.https.HttpsError('internal', 'Replicate API token not configured');
  }
  const REPLICATE_API_URL = 'https://api.replicate.com/v1';

  try {
    if (action === 'create') {
      // Create a new prediction
      console.log(`🎨 [Replicate Proxy] Creating prediction for user ${userId}`);
      console.log(`🎨 [Replicate Proxy] Model: ${model}`);
      
      const fetch = require('node-fetch');
      const response = await fetch(`${REPLICATE_API_URL}/predictions`, {
        method: 'POST',
        headers: {
          'Authorization': `Token ${REPLICATE_API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          version: model,
          input: input,
        }),
      });

      const result = await response.json();
      
      if (!response.ok) {
        console.error(`❌ [Replicate Proxy] Create failed: ${response.status}`, result);
        throw new functions.https.HttpsError('internal', `Replicate API error: ${result.detail || 'Unknown error'}`);
      }

      console.log(`✅ [Replicate Proxy] Prediction created: ${result.id}`);
      return { success: true, prediction: result };

    } else if (action === 'get') {
      // Get prediction status
      if (!predictionId) {
        throw new functions.https.HttpsError('invalid-argument', 'predictionId is required for get action');
      }

      const fetch = require('node-fetch');
      const response = await fetch(`${REPLICATE_API_URL}/predictions/${predictionId}`, {
        method: 'GET',
        headers: {
          'Authorization': `Token ${REPLICATE_API_TOKEN}`,
        },
      });

      const result = await response.json();
      
      if (!response.ok) {
        console.error(`❌ [Replicate Proxy] Get failed: ${response.status}`, result);
        throw new functions.https.HttpsError('internal', `Replicate API error: ${result.detail || 'Unknown error'}`);
      }

      return { success: true, prediction: result };

    } else {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid action. Must be "create" or "get"');
    }

  } catch (error) {
    console.error('❌ [Replicate Proxy] Error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message || 'Replicate proxy error');
  }
});

// Helper function to get model configuration
function getModelConfig(modelId) {
  const models = {
    'flash': { id: 'flash', googleModelId: 'gemini-2.0-flash-exp', displayName: 'VerveStride AI Speed', category: 'flash', creditsPerMessage: 1 },
    'flash-thinking': { id: 'flash-thinking', googleModelId: 'gemini-2.0-flash-thinking-exp-1219', displayName: 'VerveStride AI Smart', category: 'flash', creditsPerMessage: 2 },
    'pro': { id: 'pro', googleModelId: 'gemini-2.5-pro', displayName: 'VerveStride AI Pro', category: 'pro', creditsPerMessage: 3 },
  };
  return models[modelId] || models['flash'];
}

// Helper function to build system prompt
function buildSystemPrompt(persona, userStyle, useWebSearch, languageId) {
  let prompt = 'You are VerveStride AI, a helpful fitness and wellness assistant.';
  
  if (persona) {
    prompt += ` Persona: ${persona}.`;
  }
  
  if (userStyle) {
    prompt += ` User communication style: ${userStyle}.`;
  }
  
  if (useWebSearch) {
    prompt += ' You have access to web search for current information.';
  }
  
  if (languageId && languageId !== 'en-US') {
    prompt += ` Respond in ${languageId} language.`;
  }
  
  return prompt;
}
