/**
 * Subscription Logic Functions
 * 
 * Server-side subscription validation and enforcement
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

type SubscriptionTier = "free" | "pro" | "elite" | "lifetime";

interface SubscriptionData {
  tier: SubscriptionTier;
  startDate: Date;
  endDate?: Date;
  isActive: boolean;
  features: string[];
}

/**
 * Verify user subscription status (server-side truth)
 */
export const verifySubscription = functions.https.onCall(
  async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const userDoc = await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .get();

    if (!userDoc.exists) {
      return {
        tier: "free",
        isActive: false,
        features: [],
      };
    }

    const userData = userDoc.data();
    const now = new Date();

    // Check lifetime subscription
    if (userData?.Lifetime === true) {
      return {
        tier: "lifetime",
        isActive: true,
        features: [
          "ai_chat",
          "ai_meal_analysis",
          "ai_workout_coaching",
          "ai_voice_commands",
          "ai_insights",
          "custom_reminders",
          "advanced_analytics",
          "export_data",
          "no_ads",
        ],
        expiresAt: null,
      };
    }

    // Check Pro/Elite subscription
    const subscriptionTier = userData?.subscriptionTier as SubscriptionTier;
    const subscriptionEnd = userData?.subscriptionEnd?.toDate();

    if (subscriptionTier && subscriptionEnd && subscriptionEnd > now) {
      const features =
        subscriptionTier === "elite"
          ? [
              "ai_chat",
              "ai_meal_analysis",
              "ai_workout_coaching",
              "ai_voice_commands",
              "ai_insights",
              "custom_reminders",
              "advanced_analytics",
              "export_data",
            ]
          : subscriptionTier === "pro"
          ? [
              "ai_chat",
              "ai_meal_analysis",
              "ai_workout_coaching",
              "custom_reminders",
            ]
          : [];

      return {
        tier: subscriptionTier,
        isActive: true,
        features,
        expiresAt: subscriptionEnd.toISOString(),
      };
    }

    // Free tier
    return {
      tier: "free",
      isActive: false,
      features: [],
    };
  }
);

/**
 * Check if user can access a specific feature
 */
export const checkFeatureAccess = functions.https.onCall(
  async (data: { feature: string }, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const { feature } = data;

    if (!feature) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Feature name is required"
      );
    }

    // Get subscription status
    const subscription = await verifySubscription.run(
      {},
      { auth: context.auth, rawRequest: context.rawRequest } as any
    );

    const hasAccess = subscription.features.includes(feature);

    // Log access attempt for analytics
    await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .collection("featureAccess")
      .add({
        feature,
        hasAccess,
        tier: subscription.tier,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      hasAccess,
      tier: subscription.tier,
      feature,
      upgradeRequired: !hasAccess,
    };
  }
);

/**
 * Track AI usage (token counting)
 */
export const trackAIUsage = functions.https.onCall(
  async (
    data: {
      feature: string;
      tokensUsed: number;
      model: string;
    },
    context
  ) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const { feature, tokensUsed, model } = data;

    // Get subscription
    const subscription = await verifySubscription.run(
      {},
      { auth: context.auth, rawRequest: context.rawRequest } as any
    );

    // Token limits per tier
    const tokenLimits: Record<SubscriptionTier, number> = {
      free: 0,
      pro: 100000, // 100k tokens/day
      elite: 500000, // 500k tokens/day
      lifetime: 100000, // 100k tokens/day
    };

    const dailyLimit = tokenLimits[subscription.tier as SubscriptionTier] || 0;

    // Get today's usage
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const usageSnapshot = await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .collection("aiUsage")
      .where("date", "==", today)
      .limit(1)
      .get();

    let currentUsage = 0;
    let usageDocRef;

    if (usageSnapshot.empty) {
      // Create new usage document
      usageDocRef = await admin
        .firestore()
        .collection("Users")
        .doc(context.auth.uid)
        .collection("aiUsage")
        .add({
          date: today,
          tokensUsed: tokensUsed,
          requests: 1,
          features: { [feature]: tokensUsed },
          models: { [model]: tokensUsed },
        });
    } else {
      // Update existing usage
      const usageDoc = usageSnapshot.docs[0];
      currentUsage = usageDoc.data().tokensUsed || 0;
      usageDocRef = usageDoc.ref;

      await usageDocRef.update({
        tokensUsed: admin.firestore.FieldValue.increment(tokensUsed),
        requests: admin.firestore.FieldValue.increment(1),
        [`features.${feature}`]:
          admin.firestore.FieldValue.increment(tokensUsed),
        [`models.${model}`]: admin.firestore.FieldValue.increment(tokensUsed),
      });
    }

    const newUsage = currentUsage + tokensUsed;
    const limitExceeded = newUsage > dailyLimit;

    return {
      success: true,
      tokensUsed: newUsage,
      dailyLimit,
      remaining: Math.max(0, dailyLimit - newUsage),
      limitExceeded,
      tier: subscription.tier,
    };
  }
);

/**
 * Get AI usage statistics
 */
export const getAIUsageStats = functions.https.onCall(
  async (data: { days?: number }, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const days = data.days || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    startDate.setHours(0, 0, 0, 0);

    const usageSnapshot = await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .collection("aiUsage")
      .where("date", ">=", startDate)
      .orderBy("date", "desc")
      .get();

    const stats = {
      totalTokens: 0,
      totalRequests: 0,
      byFeature: {} as Record<string, number>,
      byModel: {} as Record<string, number>,
      byDay: [] as Array<{ date: string; tokens: number; requests: number }>,
    };

    usageSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      stats.totalTokens += data.tokensUsed || 0;
      stats.totalRequests += data.requests || 0;

      // Aggregate by feature
      if (data.features) {
        Object.entries(data.features).forEach(([feature, tokens]) => {
          stats.byFeature[feature] =
            (stats.byFeature[feature] || 0) + (tokens as number);
        });
      }

      // Aggregate by model
      if (data.models) {
        Object.entries(data.models).forEach(([model, tokens]) => {
          stats.byModel[model] =
            (stats.byModel[model] || 0) + (tokens as number);
        });
      }

      // Daily breakdown
      stats.byDay.push({
        date: data.date.toDate().toISOString().split("T")[0],
        tokens: data.tokensUsed || 0,
        requests: data.requests || 0,
      });
    });

    return {
      success: true,
      stats,
      period: {
        days,
        start: startDate.toISOString(),
        end: new Date().toISOString(),
      },
    };
  }
);

/**
 * Scheduled function to clean up expired subscriptions
 */
export const cleanupExpiredSubscriptions = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const now = new Date();

    const expiredSnapshot = await admin
      .firestore()
      .collection("Users")
      .where("subscriptionEnd", "<", now)
      .where("subscriptionTier", "in", ["pro", "elite"])
      .get();

    const batch = admin.firestore().batch();

    expiredSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        subscriptionTier: "free",
        subscriptionEnd: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    functions.logger.info(
      `Cleaned up ${expiredSnapshot.size} expired subscriptions`
    );

    return null;
  });
