/**
 * Fitness Logic Functions
 * 
 * Server-side calculations for accurate fitness tracking
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

// Calorie calculation using Mifflin-St Jeor Equation (most accurate)
interface CalorieCalculationParams {
  weightKg: number;
  heightCm: number;
  age: number;
  gender: "male" | "female" | "other";
  activityLevel: "sedentary" | "light" | "moderate" | "active" | "very_active";
}

interface WorkoutCalorieParams {
  weightKg: number;
  durationMinutes: number;
  activityType: "cardio" | "strength" | "yoga" | "hiit" | "walking" | "running" | "cycling";
  intensity: "low" | "moderate" | "high";
  movementData?: {
    totalMovement: number;
    avgConfidence: number;
  };
}

/**
 * Calculate Basal Metabolic Rate (BMR) and Total Daily Energy Expenditure (TDEE)
 */
export const calculateDailyCalories = functions.https.onCall(
  async (data: CalorieCalculationParams, context) => {
    // Verify authentication
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const { weightKg, heightCm, age, gender, activityLevel } = data;

    // Validate inputs
    if (!weightKg || !heightCm || !age || !gender) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required parameters"
      );
    }

    // Mifflin-St Jeor Equation (most accurate)
    let bmr: number;
    if (gender === "male") {
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else if (gender === "female") {
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    } else {
      // Average for other genders
      bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 78;
    }

    // Activity multipliers
    const activityMultipliers = {
      sedentary: 1.2, // Little or no exercise
      light: 1.375, // Light exercise 1-3 days/week
      moderate: 1.55, // Moderate exercise 3-5 days/week
      active: 1.725, // Hard exercise 6-7 days/week
      very_active: 1.9, // Very hard exercise & physical job
    };

    const multiplier = activityMultipliers[activityLevel] || 1.55;
    const tdee = Math.round(bmr * multiplier);

    // Calculate macros (balanced diet)
    const protein = Math.round((tdee * 0.3) / 4); // 30% protein, 4 cal/g
    const carbs = Math.round((tdee * 0.4) / 4); // 40% carbs, 4 cal/g
    const fats = Math.round((tdee * 0.3) / 9); // 30% fats, 9 cal/g

    // Save to user profile
    await admin.firestore().collection("Users").doc(context.auth.uid).set(
      {
        bmr: Math.round(bmr),
        tdee,
        recommendedCalories: tdee,
        recommendedProtein: protein,
        recommendedCarbs: carbs,
        recommendedFats: fats,
        lastCalculated: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      bmr: Math.round(bmr),
      tdee,
      recommendedCalories: tdee,
      macros: {
        protein,
        carbs,
        fats,
      },
      formula: "Mifflin-St Jeor Equation",
    };
  }
);

/**
 * Calculate workout calories burned (more accurate with movement data)
 */
export const calculateWorkoutCalories = functions.https.onCall(
  async (data: WorkoutCalorieParams, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const { weightKg, durationMinutes, activityType, intensity, movementData } =
      data;

    if (!weightKg || !durationMinutes || !activityType) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required parameters"
      );
    }

    // MET (Metabolic Equivalent of Task) values
    const metValues: Record<string, Record<string, number>> = {
      cardio: { low: 3.5, moderate: 5.0, high: 7.0 },
      strength: { low: 3.0, moderate: 5.0, high: 6.0 },
      yoga: { low: 2.5, moderate: 3.0, high: 4.0 },
      hiit: { low: 6.0, moderate: 8.0, high: 10.0 },
      walking: { low: 2.5, moderate: 3.5, high: 4.5 },
      running: { low: 6.0, moderate: 8.0, high: 11.0 },
      cycling: { low: 4.0, moderate: 6.8, high: 10.0 },
    };

    const met = metValues[activityType]?.[intensity] || 5.0;

    // Base calculation: Calories = MET × weight(kg) × duration(hours)
    const baseCalories = met * weightKg * (durationMinutes / 60);

    // Adjust based on movement data if available
    let adjustedCalories = baseCalories;
    if (movementData) {
      const { totalMovement, avgConfidence } = movementData;

      // Movement factor (0.8 to 1.2)
      const movementFactor = 0.8 + (totalMovement / 100) * 0.4;

      // Confidence factor (0.9 to 1.1)
      const confidenceFactor = 0.9 + avgConfidence * 0.2;

      adjustedCalories = baseCalories * movementFactor * confidenceFactor;
    }

    const finalCalories = Math.round(adjustedCalories);

    // Log activity to Firestore
    await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .collection("activities")
      .add({
        type: "workout",
        activityType,
        intensity,
        durationMinutes,
        caloriesBurned: finalCalories,
        met,
        movementData: movementData || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        calculatedBy: "server",
      });

    return {
      success: true,
      caloriesBurned: finalCalories,
      met,
      formula: "MET-based calculation",
      adjustedByMovement: !!movementData,
    };
  }
);

/**
 * Validate and save activity (prevents cheating/manipulation)
 */
export const validateAndSaveActivity = functions.https.onCall(
  async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const {
      type,
      value,
      unit,
      note,
      timestamp,
      metadata,
    }: {
      type: "workout" | "meal" | "water";
      value: number;
      unit: string;
      note?: string;
      timestamp: number;
      metadata?: any;
    } = data;

    // Validation rules
    const validationRules = {
      workout: {
        maxDuration: 480, // 8 hours max
        maxCalories: 2000, // 2000 cal max per workout
      },
      meal: {
        maxCalories: 3000, // 3000 cal max per meal
        maxProtein: 200, // 200g max
      },
      water: {
        maxAmount: 5000, // 5L max per entry
      },
    };

    // Validate based on type
    if (type === "workout") {
      const duration = metadata?.durationMinutes || 0;
      const calories = value;

      if (duration > validationRules.workout.maxDuration) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Workout duration exceeds maximum allowed"
        );
      }

      if (calories > validationRules.workout.maxCalories) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Calories burned exceeds realistic maximum"
        );
      }
    } else if (type === "meal") {
      const calories = value;
      if (calories > validationRules.meal.maxCalories) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Meal calories exceed realistic maximum"
        );
      }
    } else if (type === "water") {
      if (value > validationRules.water.maxAmount) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Water amount exceeds realistic maximum"
        );
      }
    }

    // Check for duplicate entries (prevent spam)
    const recentActivities = await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .collection("activities")
      .where("type", "==", type)
      .where("timestamp", ">=", new Date(timestamp - 60000)) // Within 1 minute
      .limit(1)
      .get();

    if (!recentActivities.empty) {
      throw new functions.https.HttpsError(
        "already-exists",
        "Similar activity already logged recently"
      );
    }

    // Save activity
    const activityRef = await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .collection("activities")
      .add({
        type,
        value,
        unit,
        note: note || "",
        timestamp: new Date(timestamp),
        metadata: metadata || {},
        validated: true,
        validatedBy: "server",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      activityId: activityRef.id,
      validated: true,
    };
  }
);

/**
 * Get user statistics (server-calculated for accuracy)
 */
export const getUserStatistics = functions.https.onCall(
  async (data: { startDate?: string; endDate?: string }, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be logged in"
      );
    }

    const startDate = data.startDate
      ? new Date(data.startDate)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000); // 30 days ago
    const endDate = data.endDate ? new Date(data.endDate) : new Date();

    // Get activities
    const activitiesSnapshot = await admin
      .firestore()
      .collection("Users")
      .doc(context.auth.uid)
      .collection("activities")
      .where("timestamp", ">=", startDate)
      .where("timestamp", "<=", endDate)
      .get();

    const activities = activitiesSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Calculate statistics
    const stats = {
      totalWorkouts: 0,
      totalWorkoutMinutes: 0,
      totalCaloriesBurned: 0,
      totalMeals: 0,
      totalCaloriesConsumed: 0,
      totalWaterMl: 0,
      avgWorkoutDuration: 0,
      avgDailyCalories: 0,
      avgDailyWater: 0,
      mostActiveDay: "",
      streakDays: 0,
    };

    const dailyData: Record<string, any> = {};

    activities.forEach((activity: any) => {
      const date = activity.timestamp.toDate().toISOString().split("T")[0];

      if (!dailyData[date]) {
        dailyData[date] = {
          workouts: 0,
          meals: 0,
          water: 0,
          calories: 0,
        };
      }

      if (activity.type === "workout") {
        stats.totalWorkouts++;
        stats.totalWorkoutMinutes += activity.metadata?.durationMinutes || 0;
        stats.totalCaloriesBurned += activity.value || 0;
        dailyData[date].workouts++;
      } else if (activity.type === "meal") {
        stats.totalMeals++;
        stats.totalCaloriesConsumed += activity.value || 0;
        dailyData[date].meals++;
        dailyData[date].calories += activity.value || 0;
      } else if (activity.type === "water") {
        stats.totalWaterMl += activity.value || 0;
        dailyData[date].water += activity.value || 0;
      }
    });

    // Calculate averages
    const dayCount = Object.keys(dailyData).length || 1;
    stats.avgWorkoutDuration =
      stats.totalWorkouts > 0
        ? Math.round(stats.totalWorkoutMinutes / stats.totalWorkouts)
        : 0;
    stats.avgDailyCalories = Math.round(stats.totalCaloriesConsumed / dayCount);
    stats.avgDailyWater = Math.round(stats.totalWaterMl / dayCount);

    // Find most active day
    let maxActivity = 0;
    Object.entries(dailyData).forEach(([date, data]: [string, any]) => {
      const activityScore = data.workouts * 10 + data.meals + data.water / 100;
      if (activityScore > maxActivity) {
        maxActivity = activityScore;
        stats.mostActiveDay = date;
      }
    });

    // Calculate streak
    const sortedDates = Object.keys(dailyData).sort().reverse();
    let streak = 0;
    let currentDate = new Date();
    for (const date of sortedDates) {
      const activityDate = new Date(date);
      const dayDiff = Math.floor(
        (currentDate.getTime() - activityDate.getTime()) / (1000 * 60 * 60 * 24)
      );
      if (dayDiff === streak) {
        streak++;
      } else {
        break;
      }
    }
    stats.streakDays = streak;

    return {
      success: true,
      stats,
      dailyData,
      period: {
        start: startDate.toISOString(),
        end: endDate.toISOString(),
        days: dayCount,
      },
    };
  }
);
