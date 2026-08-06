import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import * as cors from "cors";
import Stripe from "stripe";
const corsHandler = (cors as any).default ? (cors as any).default({ origin: true }) : (cors as any)({ origin: true });

admin.initializeApp();

function _requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in");
  }
  return uid;
}

function _userRef(uid: string) {
  return admin.firestore().collection("Users").doc(uid);
}

export const grantWelcomeCredits = functions.https.onCall(async (_data, context) => {
  const uid = _requireAuth(context);
  const ref = _userRef(uid);

  const WELCOME_CREDITS = 20;

  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const doc = snap.data() || {};
    const credits = (doc as any).credits || {};
    const alreadyGranted = credits.welcomeGranted === true;

    const currentAvailable = Number(credits.available ?? 0);
    const currentPrecise = Number(credits.precise ?? currentAvailable);
    const currentPurchased = Number(credits.totalPurchased ?? 0);
    const currentUsed = Number(credits.totalUsed ?? 0);

    if (alreadyGranted) {
      return {
        granted: false,
        available: currentAvailable,
        precise: currentPrecise,
        totalPurchased: currentPurchased,
        totalUsed: currentUsed,
      };
    }

    const nextAvailable = currentAvailable + WELCOME_CREDITS;
    const nextPrecise = currentPrecise + WELCOME_CREDITS;
    tx.set(
      ref,
      {
        credits: {
          available: nextAvailable,
          precise: nextPrecise,
          totalPurchased: currentPurchased,
          totalUsed: currentUsed,
          welcomeGranted: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      granted: true,
      available: nextAvailable,
      precise: nextPrecise,
      totalPurchased: currentPurchased,
      totalUsed: currentUsed,
    };
  });

  return {
    success: true,
    credits: result,
  };
});

export const deductCredits = functions.https.onCall(async (data, context) => {
  const uid = _requireAuth(context);

  const amount = Number(data?.amount);
  const description = typeof data?.description === "string" ? data.description : "AI usage";

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid amount");
  }

  const user = _userRef(uid);
  const usageRef = admin.firestore().collection("credit_usage").doc();

  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(user);
    const doc = snap.data() || {};
    const credits = (doc as any).credits || {};

    const current = Number(credits.available ?? 0);
    const currentPrecise = Number(credits.precise ?? current);
    const totalPurchased = Number(credits.totalPurchased ?? 0);
    const totalUsed = Number(credits.totalUsed ?? 0);

    // Check both available and precise (use precise for accuracy)
    if (currentPrecise < amount) {
      throw new functions.https.HttpsError("failed-precondition", "Insufficient credits");
    }

    const remaining = current - Math.ceil(amount);  // Integer credits
    const remainingPrecise = currentPrecise - amount;  // Precise credits

    tx.set(
      user,
      {
        credits: {
          available: Math.max(0, remaining),
          precise: Math.max(0, remainingPrecise),
          totalPurchased,
          totalUsed: totalUsed + amount,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(usageRef, {
      userId: uid,
      amount,
      description,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { remaining: Math.max(0, remaining), precise: Math.max(0, remainingPrecise) };
  });

  return {
    success: true,
    credits: {
      remaining: result.remaining,
      precise: result.precise,
    },
  };
});

export const refundCredits = functions.https.onCall(async (data, context) => {
  const uid = _requireAuth(context);

  const amount = Number(data?.amount);
  const reason = typeof data?.reason === "string" ? data.reason : "Refund";

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid amount");
  }

  const user = _userRef(uid);
  const usageRef = admin.firestore().collection("credit_usage").doc();

  const result = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(user);
    const doc = snap.data() || {};
    const credits = (doc as any).credits || {};

    const current = Number(credits.available ?? 0);
    const currentPrecise = Number(credits.precise ?? current);
    const totalPurchased = Number(credits.totalPurchased ?? 0);
    const totalUsed = Number(credits.totalUsed ?? 0);

    const next = current + amount;
    const nextPrecise = currentPrecise + amount;
    tx.set(
      user,
      {
        credits: {
          available: next,
          precise: nextPrecise,
          totalPurchased,
          totalUsed,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(usageRef, {
      userId: uid,
      amount: -amount,
      description: `Refund: ${reason}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { total: next, precise: nextPrecise };
  });

  return {
    success: true,
    credits: {
      total: result.total,
      precise: result.precise,
    },
  };
});

export const addCredits = functions.https.onCall(async (data, context) => {
  const uid = _requireAuth(context);

  const paymentId = (data?.paymentId ?? "").toString();
  const packageKey = (data?.packageKey ?? "").toString();

  if (!paymentId || !packageKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required fields: paymentId, packageKey"
    );
  }

  // Validate payment ID format (basic check)
  if (!paymentId.startsWith("pay_") && !paymentId.startsWith("test_") && !paymentId.includes("razorpay")) {
    functions.logger.warn(`Suspicious payment ID format: ${paymentId}`);
  }

  // Server-side mapping: prevents client from inflating credits.
  const PACKAGES: Record<string, number> = {
    credits_50: 50,
    credits_100: 100,
    credits_250: 280,  // 250 + 30 bonus
    credits_500: 575,  // 500 + 75 bonus
  };
  const creditsToAdd = PACKAGES[packageKey];
  if (!creditsToAdd) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid packageKey");
  }

  functions.logger.info(`Adding credits: uid=${uid}, paymentId=${paymentId}, package=${packageKey}, credits=${creditsToAdd}`);

  const user = _userRef(uid);
  const paymentRef = admin.firestore().collection("creditPayments").doc(paymentId);

  const out = await admin.firestore().runTransaction(async (tx) => {
    const existingPayment = await tx.get(paymentRef);
    if (existingPayment.exists) {
      // Idempotent: return current credits if already processed.
      functions.logger.info(`Payment ${paymentId} already processed (idempotency check)`);
      const userSnap = await tx.get(user);
      const userData = userSnap.data() || {};
      const currentAvailable = Number((userData as any).credits?.available ?? 0);
      const currentPrecise = Number((userData as any).credits?.precise ?? currentAvailable);
      return { added: false, available: currentAvailable, precise: currentPrecise, creditsAdded: 0 };
    }

    const userSnap = await tx.get(user);
    const userData = userSnap.data() || {};
    const credits = (userData as any).credits || {};

    const currentAvailable = Number(credits.available ?? 0);
    const currentPrecise = Number(credits.precise ?? currentAvailable);
    const currentPurchased = Number(credits.totalPurchased ?? 0);
    const currentUsed = Number(credits.totalUsed ?? 0);

    const nextAvailable = currentAvailable + creditsToAdd;
    const nextPrecise = currentPrecise + creditsToAdd;

    tx.set(
      user,
      {
        credits: {
          available: nextAvailable,
          precise: nextPrecise,
          totalPurchased: currentPurchased + creditsToAdd,
          totalUsed: currentUsed,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(paymentRef, {
      userId: uid,
      paymentId,
      packageKey,
      creditsAdded: creditsToAdd,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info(`Credits added successfully: ${creditsToAdd} credits to uid=${uid}`);

    return { added: true, available: nextAvailable, precise: nextPrecise, creditsAdded: creditsToAdd };
  });

  return {
    success: true,
    credits: {
      remaining: out.available,
      precise: out.precise,
      added: out.added,
      creditsAdded: out.creditsAdded ?? 0,
    },
  };
});

type AiProvider = "openai" | "anthropic" | "gemini";

type PlanTier = "basic" | "advanced" | "expert" | "pro" | "elite" | "lifetime";
type BillingPeriod = "monthly" | "quarterly" | "half_yearly" | "yearly";

interface SubscriptionPlan {
  tier: PlanTier;
  period: BillingPeriod;
  priceId: string;
  priceUsd: number;
  interval: "month" | "year";
  intervalCount: number;
  tokensPerDay?: number;
}

const SUBSCRIPTION_PLANS: Record<string, SubscriptionPlan> = {
  basic_monthly: {
    tier: "basic",
    period: "monthly",
    priceId: "price_basic_monthly",
    priceUsd: 4.99,
    interval: "month",
    intervalCount: 1,
  },
  basic_quarterly: {
    tier: "basic",
    period: "quarterly",
    priceId: "price_basic_quarterly",
    priceUsd: 12.99,
    interval: "month",
    intervalCount: 3,
  },
  basic_yearly: {
    tier: "basic",
    period: "yearly",
    priceId: "price_basic_yearly",
    priceUsd: 39.99,
    interval: "year",
    intervalCount: 1,
  },
  advanced_monthly: {
    tier: "advanced",
    period: "monthly",
    priceId: "price_advanced_monthly",
    priceUsd: 9.99,
    interval: "month",
    intervalCount: 1,
  },
  advanced_quarterly: {
    tier: "advanced",
    period: "quarterly",
    priceId: "price_advanced_quarterly",
    priceUsd: 26.99,
    interval: "month",
    intervalCount: 3,
  },
  advanced_yearly: {
    tier: "advanced",
    period: "yearly",
    priceId: "price_advanced_yearly",
    priceUsd: 79.99,
    interval: "year",
    intervalCount: 1,
  },
  expert_monthly: {
    tier: "expert",
    period: "monthly",
    priceId: "price_expert_monthly",
    priceUsd: 19.99,
    interval: "month",
    intervalCount: 1,
  },
  expert_quarterly: {
    tier: "expert",
    period: "quarterly",
    priceId: "price_expert_quarterly",
    priceUsd: 49.99,
    interval: "month",
    intervalCount: 3,
  },
  expert_yearly: {
    tier: "expert",
    period: "yearly",
    priceId: "price_expert_yearly",
    priceUsd: 149.99,
    interval: "year",
    intervalCount: 1,
  },

  // Pro (new)
  pro_monthly: {
    tier: "pro",
    period: "monthly",
    priceId: "price_pro_monthly",
    priceUsd: 4.99,
    interval: "month",
    intervalCount: 1,
    tokensPerDay: 100000,
  },
  pro_quarterly: {
    tier: "pro",
    period: "quarterly",
    priceId: "price_pro_quarterly",
    priceUsd: 12.99,
    interval: "month",
    intervalCount: 3,
    tokensPerDay: 100000,
  },
  pro_half_yearly: {
    tier: "pro",
    period: "half_yearly",
    priceId: "price_pro_half_yearly",
    priceUsd: 22.99,
    interval: "month",
    intervalCount: 6,
    tokensPerDay: 100000,
  },
  pro_yearly: {
    tier: "pro",
    period: "yearly",
    priceId: "price_pro_yearly",
    priceUsd: 39.99,
    interval: "year",
    intervalCount: 1,
    tokensPerDay: 100000,
  },

  // Elite (new)
  elite_monthly: {
    tier: "elite",
    period: "monthly",
    priceId: "price_elite_monthly",
    priceUsd: 9.99,
    interval: "month",
    intervalCount: 1,
    tokensPerDay: 500000,
  },
  elite_quarterly: {
    tier: "elite",
    period: "quarterly",
    priceId: "price_elite_quarterly",
    priceUsd: 24.99,
    interval: "month",
    intervalCount: 3,
    tokensPerDay: 500000,
  },
  elite_half_yearly: {
    tier: "elite",
    period: "half_yearly",
    priceId: "price_elite_half_yearly",
    priceUsd: 44.99,
    interval: "month",
    intervalCount: 6,
    tokensPerDay: 500000,
  },
  elite_yearly: {
    tier: "elite",
    period: "yearly",
    priceId: "price_elite_yearly",
    priceUsd: 79.99,
    interval: "year",
    intervalCount: 1,
    tokensPerDay: 500000,
  },
};

interface OneTimePlan {
  kind: "lifetime" | "remove_ads";
  priceId: string;
  priceUsd: number;
  tokensPerDay?: number;
}

const ONE_TIME_PLANS: Record<string, OneTimePlan> = {
  lifetime: {
    kind: "lifetime",
    priceId: "price_lifetime",
    priceUsd: 149.99,
    tokensPerDay: 100000,
  },
  remove_ads: {
    kind: "remove_ads",
    priceId: "price_remove_ads",
    priceUsd: 1.99,
  },
};

function _getStripeKeys() {
  const cfg = (() => {
    try {
      return (((functions as any).config?.() as any)?.stripe as any) || {};
    } catch {
      return {};
    }
  })();

  const secretKey =
    process.env.STRIPE_SECRET_KEY ||
    cfg.secret_key;

  if (!secretKey) {
    functions.logger.error("Missing Stripe secret key (STRIPE_SECRET_KEY)");
    throw new functions.https.HttpsError(
      "internal",
      "Server misconfigured: Missing Stripe secret key"
    );
  }

  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || cfg.webhook_secret;
  if (!webhookSecret) {
    functions.logger.error("Missing Stripe webhook secret (STRIPE_WEBHOOK_SECRET)");
    throw new functions.https.HttpsError(
      "internal",
      "Server misconfigured: Missing Stripe webhook secret"
    );
  }

  return { secretKey, webhookSecret };
}

function _isObject(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

function _normalizeProvider(p: unknown): AiProvider | null {
  const s = (p ?? "").toString().trim().toLowerCase();
  if (s === "openai" || s === "anthropic" || s === "gemini") return s;
  return null;
}

function _readApiKeyFromHeaders(req: functions.https.Request): string {
  // Preferred: x-ai-api-key (single header across providers)
  const h = req.headers["x-ai-api-key"];
  const k1 = Array.isArray(h) ? h[0] : h;
  if (typeof k1 === "string" && k1.trim().length > 0) return k1.trim();

  // Provider-specific fallbacks
  const openai = req.headers["authorization"];
  const openaiStr = Array.isArray(openai) ? openai[0] : openai;
  if (typeof openaiStr === "string") {
    const m = openaiStr.match(/^Bearer\s+(.+)$/i);
    if (m && m[1]) return m[1].trim();
  }

  const anthropic = req.headers["x-api-key"];
  const a = Array.isArray(anthropic) ? anthropic[0] : anthropic;
  if (typeof a === "string" && a.trim().length > 0) return a.trim();

  return "";
}

async function _verifyFirebaseAuth(req: functions.https.Request): Promise<string> {
  const auth = req.headers.authorization;
  const authStr = Array.isArray(auth) ? auth[0] : auth;
  if (!authStr || typeof authStr !== "string") {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Missing Authorization header"
    );
  }

  const m = authStr.match(/^Bearer\s+(.+)$/i);
  if (!m || !m[1]) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Invalid Authorization header"
    );
  }

  const decoded = await admin.auth().verifyIdToken(m[1]);
  if (!decoded?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Invalid token"
    );
  }
  return decoded.uid;
}

async function _forwardToProvider(params: {
  provider: AiProvider;
  apiKey: string;
  endpoint: string;
  body: unknown;
}) {
  const { provider, apiKey, endpoint, body } = params;
  const fetch = (await import("node-fetch")).default;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 30000);

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };

  let url = endpoint;
  if (provider === "openai") {
    headers["Authorization"] = `Bearer ${apiKey}`;
  } else if (provider === "anthropic") {
    headers["x-api-key"] = apiKey;
    headers["anthropic-version"] = "2023-06-01";
  } else if (provider === "gemini") {
    // Gemini uses API key in query string.
    url = endpoint.includes("?") ? `${endpoint}&key=${apiKey}` : `${endpoint}?key=${apiKey}`;
  }

  const resp = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(body ?? {}),
    signal: controller.signal,
  }).finally(() => clearTimeout(timeoutId));

  const text = await resp.text();
  const contentType = (resp.headers.get("content-type") ?? "").toLowerCase();
  const parsed = contentType.includes("application/json") ? (() => {
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  })() : text;

  return {
    ok: resp.ok,
    status: resp.status,
    body: parsed,
    rawText: text,
  };
}

// HTTP AI Proxy for Web - supports BYO key via request header and bypasses CORS.
// Flutter Web calls this endpoint; mobile/desktop can continue direct calls.
export const aiProxyHttp = functions.https.onRequest((req, res) => {
  corsHandler(req as any, res as any, async () => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ success: false, error: "Only POST allowed" });
      return;
    }

    try {
      await _verifyFirebaseAuth(req);

      const body = req.body;
      if (!_isObject(body)) {
        res.status(400).json({ success: false, error: "Invalid JSON body" });
        return;
      }

      const provider = _normalizeProvider(body.provider);
      const endpoint = (body.endpoint ?? "").toString();
      const payload = body.body;

      if (!provider || !endpoint) {
        res.status(400).json({
          success: false,
          error: "Missing required fields: provider, endpoint",
        });
        return;
      }

      const apiKey = _readApiKeyFromHeaders(req);
      if (!apiKey) {
        res.status(400).json({
          success: false,
          error: "Missing API key header: x-ai-api-key",
        });
        return;
      }

      const out = await _forwardToProvider({
        provider,
        apiKey,
        endpoint,
        body: payload,
      });

      if (!out.ok) {
        functions.logger.error(
          `AI Proxy HTTP error: ${provider} ${out.status} ${typeof out.rawText === "string" ? out.rawText : ""}`
        );
        res.status(out.status).json({
          success: false,
          statusCode: out.status,
          body: out.body,
        });
        return;
      }

      res.status(200).json({
        success: true,
        statusCode: out.status,
        body: out.body,
      });
    } catch (err: any) {
      const msg = err?.message ?? "Unknown error";
      const code = err?.code;
      const status = code === "unauthenticated" ? 401 : 500;
      functions.logger.error("AI Proxy HTTP exception", err);
      res.status(status).json({ success: false, error: msg });
    }
  });
});

// AI Proxy for Web - forwards requests to AI providers to bypass CORS
export const aiProxy = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in to use AI features"
    );
  }

  const { provider, apiKey, endpoint, body } = data;

  if (!provider || !apiKey || !endpoint) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing required fields: provider, apiKey, endpoint"
    );
  }

  // Validate provider
  const validProviders = ["openai", "anthropic", "gemini"];
  if (!validProviders.includes(provider)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Invalid provider. Must be one of: ${validProviders.join(", ")}`
    );
  }

  try {
    // Make the request to the AI provider
    const fetch = (await import("node-fetch")).default;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);
    
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };

    if (provider === "openai") {
      headers["Authorization"] = `Bearer ${apiKey}`;
    } else if (provider === "anthropic") {
      headers["x-api-key"] = apiKey;
      headers["anthropic-version"] = "2023-06-01";
    } else if (provider === "gemini") {
      // Gemini uses API key in URL, handled below
    }

    const url = provider === "gemini" 
      ? `${endpoint}&key=${apiKey}`
      : endpoint;

    functions.logger.info(`AI Proxy: ${provider} request to ${url.replace(apiKey, "***")}`);

    const response = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
      signal: controller.signal,
    }).finally(() => clearTimeout(timeoutId));

    const responseBody = await response.text();

    if (!response.ok) {
      functions.logger.error(`AI Proxy error: ${provider} ${response.status} ${responseBody}`);
      return {
        success: false,
        error: `AI provider error: ${response.status}`,
        statusCode: response.status,
        body: responseBody,
      };
    }

    return {
      success: true,
      statusCode: response.status,
      body: JSON.parse(responseBody),
    };
  } catch (error: any) {
    functions.logger.error("AI Proxy error:", error);
    return {
      success: false,
      error: error.message || "Unknown error",
    };
  }
});

const getRazorpayKeys = () => {
  const cfg = (() => {
    try {
      return (((functions as any).config?.() as any)?.razorpay as any) || {};
    } catch {
      return {};
    }
  })();

  const keyId =
    process.env.RAZORPAY_KEY_ID ||
    cfg.key_id ||
    "rzp_test_SG4j6JKI0h5GkH";
  const keySecret = process.env.RAZORPAY_KEY_SECRET || cfg.key_secret;

  if (!keySecret) {
    functions.logger.error("Missing Razorpay API Secret (RAZORPAY_KEY_SECRET)");
    throw new functions.https.HttpsError(
      "internal",
      "Server misconfigured: Missing API Secret"
    );
  }

  if (!keyId) {
    functions.logger.error("Missing Razorpay API Key ID (RAZORPAY_KEY_ID)");
    throw new functions.https.HttpsError(
      "internal",
      "Server misconfigured: Missing API Key ID"
    );
  }

  return { keyId, keySecret };
};

export const razorpaywebhook = functions.https.onRequest((req, res) => {
  corsHandler(req as any, res as any, async () => {
    if (req.method !== "POST") {
      res.status(405).send("Only POST allowed");
      return;
    }

    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;

    if (!webhookSecret) {
      functions.logger.error(
        "Missing Razorpay webhook secret. Set env RAZORPAY_WEBHOOK_SECRET."
      );
      res.status(500).send("Server misconfigured");
      return;
    }

    const signatureHeader = req.headers["x-razorpay-signature"];
    const signature =
      Array.isArray(signatureHeader) ?
        signatureHeader[0] :
        signatureHeader;
    if (!signature || typeof signature !== "string") {
      res.status(400).send("Missing signature");
      return;
    }

    const rawBodyAny = (req as any).rawBody;
    if (!rawBodyAny || !Buffer.isBuffer(rawBodyAny)) {
      functions.logger.error(
        "rawBody missing/not Buffer; cannot verify Razorpay signature"
      );
      res.status(500).send("Server misconfigured");
      return;
    }

    const rawBody: Buffer = rawBodyAny;
    const expectedSig = crypto
      .createHmac("sha256", webhookSecret)
      .update(rawBody)
      .digest("hex");

    const sigOk = (() => {
      try {
        return crypto.timingSafeEqual(
          Buffer.from(signature, "hex"),
          Buffer.from(expectedSig, "hex")
        );
      } catch {
        return false;
      }
    })();

    if (!sigOk) {
      functions.logger.warn("Invalid Razorpay signature");
      res.status(401).send("Bad signature");
      return;
    }

    const eventType = req.body?.event;
    if (!eventType || typeof eventType !== "string") {
      res.status(400).send("Missing event type");
      return;
    }

    // --- Strict Event Type Check ---
    if (eventType !== "payment_link.paid") {
      functions.logger.info(`Ignored event: ${eventType}`);
      res.status(200).send("Ignored event");
      return;
    }

    // --- Secure Payment Verification Flow (Updated) ---

    const payload = req.body.payload || {};

    // 1. Identify Payment Link
    const paymentLinkId = payload.payment_link?.entity?.id;

    if (!paymentLinkId) {
      functions.logger.error("Missing paymentLinkId in webhook payload");
      res.status(400).send("Missing paymentLinkId");
      return;
    }

    // 2. Verify Payment Link Exists in Firestore (Source of Truth)
    const linkDoc = await admin
      .firestore()
      .collection("paymentLinks")
      .doc(paymentLinkId)
      .get();

    if (!linkDoc.exists) {
      functions.logger.error(`Unknown payment link: ${paymentLinkId}`);
      res.status(400).send("Unknown payment link");
      return;
    }

    const startData = linkDoc.data();
    const userId = startData?.uid;

    if (!userId) {
      functions.logger.error(`Payment link ${paymentLinkId} has no bound UID`);
      res.status(403).send("Invalid link data");
      return;
    }

    // 3. Amount Verification
    const paidAmount = payload.payment?.entity?.amount || payload.payment_link?.entity?.amount;
    const expectedAmountPaise = Math.round(Number(startData?.amount) * 100);
    if (!paidAmount || Number(paidAmount) !== expectedAmountPaise) {
      functions.logger.error(
        `Amount mismatch for link ${paymentLinkId}: expected ${expectedAmountPaise}, got ${paidAmount}`
      );
      res.status(400).send("Amount mismatch");
      return;
    }

    // 4/5. Idempotent processing (transactional): Prevent duplicate processing
    // Prefer Razorpay payment entity id.
    const paymentId = payload.payment?.entity?.id || null;

    try {
      await admin.firestore().runTransaction(async (tx) => {
        const fresh = await tx.get(linkDoc.ref);
        const freshData = fresh.data();

        if (freshData?.status === "paid") {
          return;
        }

        const premiumPayload = {
          Lifetime: true,
          adsFree: true,
          paymentId: paymentId,
          purchaseTime: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        tx.set(admin.firestore().collection("Users").doc(userId), premiumPayload, {
          merge: true,
        });

        tx.update(linkDoc.ref, {
          status: "paid",
          paymentId: paymentId,
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      functions.logger.info(
        `Lifetime access granted to ${userId} via secure link: ${paymentLinkId}`
      );
    } catch (error) {
      functions.logger.error("Firestore transaction failed", error);
      // Still 200 OK — Razorpay retries on non-2xx
    }

    res.status(200).send("OK");
  });
});

export const createpaymentlink = functions.https.onCall(async (data, context) => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const Razorpay = require("razorpay");

  const { keyId, keySecret } = getRazorpayKeys();

  functions.logger.info(
    `Razorpay createpaymentlink using key_id: ${String(keyId).substring(0, 12)}...`
  );

  // Strict Authentication Requirement
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in to create a payment link"
    );
  }

  const { amount, description } = data;
  const userId = context.auth.uid;
  const userEmail = context.auth.token.email || "customer@example.com";

  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid amount");
  }

  if (!userId) {
    throw new functions.https.HttpsError("unauthenticated", "User must be logged in or UID provided");
  }

  try {
    const razorpay = new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });

    const paymentLink = await razorpay.paymentLink.create({
      amount: Math.round(amount * 100),
      currency: "INR",
      accept_partial: false,
      description: description || "VerveStride Lifetime Access",
      customer: {
        name: "VerveStride User",
        email: userEmail,
      },
      notify: {
        sms: false,
        email: true,
      },
      reminder_enable: true,
      notes: {
        // We still keep notes for debugging, but we don't rely on them for logic anymore
        uid: userId,
        source: "vervestride_app"
      },
      callback_url: "https://vervestride-app.web.app/",
      callback_method: "get",
    });

    // --- SECURE: Store Link Metadata in Firestore ---
    await admin.firestore().collection("paymentLinks").doc(paymentLink.id).set({
      uid: userId,
      email: userEmail,
      amount: amount,
      description: description,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "created",
      razorpayId: paymentLink.id
    });

    return {
      success: true,
      id: paymentLink.id,
      short_url: paymentLink.short_url,
    };
  } catch (error: any) {
    functions.logger.error("Razorpay Payment Link creation failed", error);
    return {
      success: false,
      error: error.message || "Unknown error",
      details: JSON.stringify(error),
    };
  }
});

export const createorder = functions.https.onCall(async (data, context) => {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const Razorpay = require("razorpay");

  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in to create an order"
    );
  }

  const { keyId, keySecret } = getRazorpayKeys();

  const amount = data?.amount;
  const description = data?.description;

  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid amount");
  }

  const amountPaise = Math.round(amount * 100);
  const userId = context.auth.uid;

  const razorpay = new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });

  const receipt = `vs_${userId}_${Date.now()}`;

  try {
    const order = await razorpay.orders.create({
      amount: amountPaise,
      currency: "INR",
      receipt,
      notes: {
        uid: userId,
        description: description || "VerveStride Lifetime Access",
        source: "vervestride_app",
      },
    });

    await admin.firestore().collection("razorpayOrders").doc(order.id).set({
      uid: userId,
      amount: amount,
      amountPaise: amountPaise,
      currency: "INR",
      status: "created",
      receipt,
      description: description || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      key_id: keyId,
      order_id: order.id,
      amount: amountPaise,
      currency: "INR",
    };
  } catch (error: any) {
    functions.logger.error("Razorpay order creation failed", error);
    return {
      success: false,
      error: error.message || "Unknown error",
      details: JSON.stringify(error),
    };
  }
});

export const verifypayment = functions.https.onCall(async (data, context) => {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in to verify a payment"
    );
  }

  const { keySecret } = getRazorpayKeys();

  const orderId = (data?.razorpay_order_id ?? "").toString();
  const paymentId = (data?.razorpay_payment_id ?? "").toString();
  const signature = (data?.razorpay_signature ?? "").toString();

  if (!orderId || !paymentId || !signature) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing payment verification fields"
    );
  }

  const expected = crypto
    .createHmac("sha256", keySecret)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");

  const ok = (() => {
    try {
      return crypto.timingSafeEqual(
        Buffer.from(signature, "hex"),
        Buffer.from(expected, "hex")
      );
    } catch {
      return false;
    }
  })();

  if (!ok) {
    throw new functions.https.HttpsError("permission-denied", "Bad signature");
  }

  const userId = context.auth.uid;
  const orderRef = admin.firestore().collection("razorpayOrders").doc(orderId);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError("not-found", "Unknown order");
    }
    const orderData = snap.data();
    if (orderData?.uid !== userId) {
      throw new functions.https.HttpsError("permission-denied", "Order not owned by user");
    }

    if (orderData?.status === "paid") {
      return;
    }

    tx.set(
      admin.firestore().collection("Users").doc(userId),
      {
        Lifetime: true,
        adsFree: true,
        paymentId: paymentId,
        orderId: orderId,
        purchaseTime: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.update(orderRef, {
      status: "paid",
      paymentId: paymentId,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

// Stripe: Create Checkout Session for Web Subscriptions
export const createStripeCheckoutSession = functions.https.onCall(async (data, context) => {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be logged in to create a Stripe Checkout session"
    );
  }

  const { planKey } = data;
  if (!planKey || typeof planKey !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid or missing planKey"
    );
  }

  const subscriptionPlan = SUBSCRIPTION_PLANS[planKey];
  const oneTimePlan = ONE_TIME_PLANS[planKey];
  if (!subscriptionPlan && !oneTimePlan) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid or missing planKey"
    );
  }
  const userId = context.auth.uid;

  try {
    const stripe = new Stripe(_getStripeKeys().secretKey);

    const session = subscriptionPlan
      ? await stripe.checkout.sessions.create({
          mode: "subscription",
          payment_method_types: ["card"],
          line_items: [
            {
              price_data: {
                currency: "usd",
                product_data: {
                  name: `${subscriptionPlan.tier.charAt(0).toUpperCase() + subscriptionPlan.tier.slice(1)} ${subscriptionPlan.period.charAt(0).toUpperCase() + subscriptionPlan.period.slice(1)}`,
                  description: `VerveStride ${subscriptionPlan.tier} plan (${subscriptionPlan.period})`,
                },
                unit_amount: Math.round(subscriptionPlan.priceUsd * 100),
                recurring: {
                  interval: subscriptionPlan.interval,
                  interval_count: subscriptionPlan.intervalCount,
                },
              },
              quantity: 1,
            },
          ],
          success_url: `https://vervestride-app.web.app/premium?session_id={CHECKOUT_SESSION_ID}`,
          cancel_url: `https://vervestride-app.web.app/premium?canceled=true`,
          metadata: {
            userId,
            planKey,
            purchaseType: "subscription",
          },
          customer_email: context.auth.token.email || undefined,
        })
      : await stripe.checkout.sessions.create({
          mode: "payment",
          payment_method_types: ["card"],
          line_items: [
            {
              price_data: {
                currency: "usd",
                product_data: {
                  name: oneTimePlan.kind === "remove_ads" ? "Remove Ads (Lifetime)" : "Lifetime",
                  description: oneTimePlan.kind === "remove_ads"
                    ? "One-time purchase to remove ads"
                    : "One-time lifetime access purchase",
                },
                unit_amount: Math.round(oneTimePlan.priceUsd * 100),
              },
              quantity: 1,
            },
          ],
          success_url: `https://vervestride-app.web.app/premium?session_id={CHECKOUT_SESSION_ID}`,
          cancel_url: `https://vervestride-app.web.app/premium?canceled=true`,
          metadata: {
            userId,
            planKey,
            purchaseType: "one_time",
          },
          customer_email: context.auth.token.email || undefined,
        });

    return {
      success: true,
      checkoutUrl: session.url,
      sessionId: session.id,
    };
  } catch (error: any) {
    functions.logger.error("Stripe Checkout session creation failed", error);
    throw new functions.https.HttpsError(
      "internal",
      error.message || "Failed to create Stripe Checkout session"
    );
  }
});

// Stripe Webhook: Handle subscription events and write entitlement to Firestore
export const stripeWebhook = functions.https.onRequest((req, res) => {
  corsHandler(req as any, res as any, async () => {
    if (req.method !== "POST") {
      res.status(405).send("Only POST allowed");
      return;
    }

    const { webhookSecret } = _getStripeKeys();

    const sig = req.headers["stripe-signature"];
    if (!sig || typeof sig !== "string") {
      res.status(400).send("Missing Stripe signature");
      return;
    }

    let event: Stripe.Event;
    try {
      event = Stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err: any) {
      functions.logger.warn(`Stripe webhook signature verification failed: ${err.message}`);
      res.status(400).send(`Webhook signature verification failed: ${err.message}`);
      return;
    }

    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const userId = session.metadata?.userId;
      const planKey = session.metadata?.planKey;
      const subscriptionId = session.subscription as string | null;

      if (!userId || !planKey) {
        functions.logger.error("Missing metadata in Stripe checkout session", { userId, planKey, subscriptionId });
        res.status(400).send("Invalid session metadata");
        return;
      }

      // Subscription purchase
      if (subscriptionId) {
        const plan = SUBSCRIPTION_PLANS[planKey];
        if (!plan) {
          functions.logger.error(`Unknown planKey (subscription): ${planKey}`);
          res.status(400).send("Unknown plan");
          return;
        }

        try {
          const stripe = new Stripe(_getStripeKeys().secretKey);
          const subscription = await stripe.subscriptions.retrieve(subscriptionId);
          const currentPeriodEnd = new Date((subscription as any).current_period_end * 1000);

          await admin.firestore().collection("Users").doc(userId).set(
            {
              planTier: plan.tier,
              billingPeriod: plan.period,
              subscriptionStatus: "active",
              currentPeriodEnd: admin.firestore.Timestamp.fromDate(currentPeriodEnd),
              provider: "stripe",
              stripeSubscriptionId: subscriptionId,
              tokensPerDay: plan.tokensPerDay ?? null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          functions.logger.info(`Stripe subscription activated for ${userId}: ${planKey} until ${currentPeriodEnd.toISOString()}`);
        } catch (err: any) {
          functions.logger.error("Failed to write Stripe subscription to Firestore", err);
          res.status(500).send("Failed to write subscription");
          return;
        }
      } else {
        // One-time purchase
        const plan = ONE_TIME_PLANS[planKey];
        if (!plan) {
          functions.logger.error(`Unknown planKey (one-time): ${planKey}`);
          res.status(400).send("Unknown plan");
          return;
        }

        try {
          const update: Record<string, unknown> = {
            provider: "stripe",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          if (plan.kind === "remove_ads") {
            update["adFree"] = true;
          } else if (plan.kind === "lifetime") {
            update["planTier"] = "lifetime";
            update["lifetimeAccess"] = true;
            update["tokensPerDay"] = plan.tokensPerDay ?? 100000;
          }

          await admin.firestore().collection("Users").doc(userId).set(update, { merge: true });
          functions.logger.info(`Stripe one-time purchase recorded for ${userId}: ${planKey}`);
        } catch (err: any) {
          functions.logger.error("Failed to write Stripe one-time purchase to Firestore", err);
          res.status(500).send("Failed to write purchase");
          return;
        }
      }
    } else if (event.type === "invoice.payment_succeeded") {
      const invoice = event.data.object as Stripe.Invoice;
      const subscriptionId = (invoice as any).subscription as string;
      if (!subscriptionId) return;

      try {
        const stripe = new Stripe(_getStripeKeys().secretKey);
        const subscription = await stripe.subscriptions.retrieve(subscriptionId);
        const currentPeriodEnd = new Date((subscription as any).current_period_end * 1000);

        // Find user by stripeSubscriptionId (rare but needed for renewals)
        const usersSnap = await admin
          .firestore()
          .collection("Users")
          .where("stripeSubscriptionId", "==", subscriptionId)
          .limit(1)
          .get();

        if (!usersSnap.empty) {
          const doc = usersSnap.docs[0];
          await doc.ref.update({
            subscriptionStatus: "active",
            currentPeriodEnd: admin.firestore.Timestamp.fromDate(currentPeriodEnd),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          functions.logger.info(`Stripe subscription renewed for ${doc.id} until ${currentPeriodEnd.toISOString()}`);
        }
      } catch (err: any) {
        functions.logger.error("Failed to handle Stripe invoice.payment_succeeded", err);
      }
    } else if (event.type === "customer.subscription.deleted") {
      const subscription = event.data.object as Stripe.Subscription;
      const subscriptionId = subscription.id;

      const usersSnap = await admin
        .firestore()
        .collection("Users")
        .where("stripeSubscriptionId", "==", subscriptionId)
        .limit(1)
        .get();

      if (!usersSnap.empty) {
        const doc = usersSnap.docs[0];
        await doc.ref.update({
          subscriptionStatus: "canceled",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        functions.logger.info(`Stripe subscription canceled for ${doc.id}`);
      }
    }

    res.status(200).send("OK");
  });
});


// ── Stripe: Create PaymentIntent for Flutter Payment Sheet ────────────────
// Called by StripePaymentService in the Flutter app.
// Returns { clientSecret } which the Payment Sheet uses to complete payment.
export const createPaymentIntent = functions.https.onRequest((req, res) => {
  corsHandler(req as any, res as any, async () => {
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    if (req.method !== "POST") { res.status(405).send("Only POST allowed"); return; }

    try {
      // Verify Firebase Auth token
      await _verifyFirebaseAuth(req);

      const { amount, currency, plan_key, email } = req.body ?? {};

      if (typeof amount !== "number" || amount <= 0) {
        res.status(400).json({ error: "Invalid amount" });
        return;
      }
      if (!currency || typeof currency !== "string") {
        res.status(400).json({ error: "Invalid currency" });
        return;
      }

      const stripe = new Stripe(_getStripeKeys().secretKey);

      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount), // already in cents from Flutter
        currency: currency.toLowerCase(),
        automatic_payment_methods: { enabled: true },
        metadata: {
          plan_key: plan_key ?? "",
          ...(email ? { email } : {}),
        },
      });

      functions.logger.info(`PaymentIntent created: ${paymentIntent.id} for plan ${plan_key}`);
      res.status(200).json({ clientSecret: paymentIntent.client_secret });
    } catch (err: any) {
      functions.logger.error("createPaymentIntent error", err);
      const status = err?.code === "unauthenticated" ? 401 : 500;
      res.status(status).json({ error: err?.message ?? "Unknown error" });
    }
  });
});


// ============================================================================
// FITNESS LOGIC FUNCTIONS (Server-side calculations)
// ============================================================================

import * as fitnessLogic from "./fitness-logic";

export const calculateDailyCalories = fitnessLogic.calculateDailyCalories;
export const calculateWorkoutCalories = fitnessLogic.calculateWorkoutCalories;
export const validateAndSaveActivity = fitnessLogic.validateAndSaveActivity;
export const getUserStatistics = fitnessLogic.getUserStatistics;

// ============================================================================
// SUBSCRIPTION LOGIC FUNCTIONS (Server-side validation)
// ============================================================================

import * as subscriptionLogic from "./subscription-logic";

export const verifySubscription = subscriptionLogic.verifySubscription;
export const checkFeatureAccess = subscriptionLogic.checkFeatureAccess;
export const trackAIUsage = subscriptionLogic.trackAIUsage;
export const getAIUsageStats = subscriptionLogic.getAIUsageStats;
export const cleanupExpiredSubscriptions =
  subscriptionLogic.cleanupExpiredSubscriptions;
