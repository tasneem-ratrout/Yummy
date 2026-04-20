const MealEntry = require("../models/MealEntry");
const DailyWaterEntry = require("../models/DailyWaterEntry");
const { analyzeQuickAddText } = require("../services/quickAddNutritionService");

const allowedMealTypes = new Set(["breakfast", "lunch", "snack", "dinner"]);

const toDateKey = (value) => {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return null;
  return trimmed;
};

const dateFromDateKey = (dateKey) => {
  const [year, month, day] = dateKey.split("-").map((part) => Number(part));
  return new Date(Date.UTC(year, month - 1, day));
};

const numberOrZero = (value) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return 0;
  return parsed;
};

const addMealsBatch = async (req, res) => {
  try {
    const userId = req.user.userId;
    const mealType = (req.body.mealType || "").toString().trim().toLowerCase();
    const dateKey = toDateKey(req.body.dateKey);
    const meals = Array.isArray(req.body.meals) ? req.body.meals : [];

    if (!allowedMealTypes.has(mealType)) {
      return res.status(400).json({ message: "Invalid meal type" });
    }

    if (!dateKey) {
      return res.status(400).json({ message: "dateKey must be in YYYY-MM-DD format" });
    }

    if (meals.length === 0) {
      return res.status(400).json({ message: "No meals to save" });
    }

    const dayDate = dateFromDateKey(dateKey);

    const docs = meals
      .map((meal) => {
        const mealName = (meal.mealName || "").toString().trim();
        if (!mealName) return null;

        return {
          user: userId,
          date: dayDate,
          date_key: dateKey,
          meal_type: mealType,
          meal_name: mealName,
          calories: numberOrZero(meal.calories),
          protein: numberOrZero(meal.protein),
          carbs: numberOrZero(meal.carbs),
          fat: numberOrZero(meal.fat),
          grams: numberOrZero(meal.grams),
        };
      })
      .filter(Boolean);

    if (docs.length === 0) {
      return res.status(400).json({ message: "Meals payload is invalid" });
    }

    await MealEntry.insertMany(docs);

    return res.status(201).json({
      message: "Meals saved successfully",
      savedCount: docs.length,
    });
  } catch (error) {
    console.error("Error saving meals:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const getDailySummary = async (req, res) => {
  try {
    const userId = req.user.userId;
    const requestedDateKey = toDateKey(req.query.dateKey);

    if (!requestedDateKey) {
      return res.status(400).json({ message: "dateKey must be in YYYY-MM-DD format" });
    }

    const entries = await MealEntry.find({
      user: userId,
      date_key: requestedDateKey,
    })
      .sort({ createdAt: 1 })
      .lean();

    const waterEntry = await DailyWaterEntry.findOne({
      user: userId,
      date_key: requestedDateKey,
    }).lean();

    const summary = {
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
    };

    const mealConsumedCalories = {
      breakfast: 0,
      lunch: 0,
      snack: 0,
      dinner: 0,
    };

    const mealNamesMap = {
      breakfast: [],
      lunch: [],
      snack: [],
      dinner: [],
    };

    for (const entry of entries) {
      summary.calories += numberOrZero(entry.calories);
      summary.protein += numberOrZero(entry.protein);
      summary.carbs += numberOrZero(entry.carbs);
      summary.fat += numberOrZero(entry.fat);

      if (mealConsumedCalories[entry.meal_type] != null) {
        mealConsumedCalories[entry.meal_type] += numberOrZero(entry.calories);
      }

      if (mealNamesMap[entry.meal_type] != null && entry.meal_name) {
        mealNamesMap[entry.meal_type].push(entry.meal_name);
      }
    }

    const mealNames = {
      breakfast: mealNamesMap.breakfast.join("\n"),
      lunch: mealNamesMap.lunch.join("\n"),
      snack: mealNamesMap.snack.join("\n"),
      dinner: mealNamesMap.dinner.join("\n"),
    };

    return res.status(200).json({
      dateKey: requestedDateKey,
      summary,
      mealConsumedCalories,
      mealNames,
      water: {
        consumedWaterMl: waterEntry ? numberOrZero(waterEntry.consumed_water_ml) : 0,
        dailyWaterGoalMl: waterEntry ? numberOrZero(waterEntry.daily_water_goal_ml) : null,
        lastDrinkTime: waterEntry?.last_drink_time || null,
      },
      entries,
    });
  } catch (error) {
    console.error("Error loading daily summary:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const updateDailyWater = async (req, res) => {
  try {
    const userId = req.user.userId;
    const dateKey = toDateKey(req.body.dateKey);
    const consumedWaterMl = numberOrZero(req.body.consumedWaterMl);
    const rawDailyWaterGoalMl = req.body.dailyWaterGoalMl;
    const lastDrinkTimeRaw = req.body.lastDrinkTime;

    if (!dateKey) {
      return res.status(400).json({ message: "dateKey must be in YYYY-MM-DD format" });
    }

    const dayDate = dateFromDateKey(dateKey);
    const parsedLastDrinkTime = lastDrinkTimeRaw ? new Date(lastDrinkTimeRaw) : null;
    const lastDrinkTime =
      parsedLastDrinkTime && !Number.isNaN(parsedLastDrinkTime.getTime())
        ? parsedLastDrinkTime
        : null;

    const existingEntry = await DailyWaterEntry.findOne({
      user: userId,
      date_key: dateKey,
    }).lean();

    const dailyWaterGoalMl = rawDailyWaterGoalMl == null
      ? numberOrZero(existingEntry?.daily_water_goal_ml || 3500)
      : numberOrZero(rawDailyWaterGoalMl) || numberOrZero(existingEntry?.daily_water_goal_ml || 3500);

    const waterEntry = await DailyWaterEntry.findOneAndUpdate(
      { user: userId, date_key: dateKey },
      {
        $set: {
          date: dayDate,
          consumed_water_ml: consumedWaterMl,
          daily_water_goal_ml: dailyWaterGoalMl,
          last_drink_time: lastDrinkTime,
        },
      },
      {
        new: true,
        upsert: true,
        setDefaultsOnInsert: true,
      }
    ).lean();

    return res.status(200).json({
      message: "Water updated successfully",
      water: {
        consumedWaterMl: numberOrZero(waterEntry.consumed_water_ml),
        dailyWaterGoalMl: numberOrZero(waterEntry.daily_water_goal_ml),
        lastDrinkTime: waterEntry.last_drink_time || null,
      },
    });
  } catch (error) {
    console.error("Error updating daily water:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

const analyzeQuickAddMeal = async (req, res) => {
  try {
    const text = (req.body.text || "").toString().trim();
    const mealType = (req.body.mealType || "snack").toString().trim().toLowerCase();

    if (!text) {
      return res.status(400).json({ message: "text is required" });
    }

    const analysis = await analyzeQuickAddText(text, mealType);

    if (!analysis.items.length) {
      return res.status(400).json({ message: "Could not analyze foods from the text" });
    }

    return res.status(200).json({
      ...analysis,
      message: "Quick add analyzed successfully",
    });
  } catch (error) {
    console.error("Error analyzing quick add meal:", error.message);
    return res.status(500).json({ message: error.message || "Server error" });
  }
};

const getPreviousMeals = async (req, res) => {
  try {
    const userId = req.user.userId;
    const rawLimit = Number.parseInt(req.query.limit, 10);
    const limit = Number.isFinite(rawLimit) && rawLimit > 0 ? Math.min(rawLimit, 100) : 50;

    // Convert userId to ObjectId for MongoDB
    const mongoose = require('mongoose');
    const userObjectId = mongoose.Types.ObjectId.isValid(userId) ? new mongoose.Types.ObjectId(userId) : userId;

    const previousMeals = await MealEntry.aggregate([
      { $match: { user: userObjectId } },
      { $sort: { createdAt: -1 } },
      {
        $group: {
          _id: "$meal_name",
          meal_name: { $first: "$meal_name" },
          meal_type: { $first: "$meal_type" },
          calories: { $first: "$calories" },
          protein: { $first: "$protein" },
          carbs: { $first: "$carbs" },
          fat: { $first: "$fat" },
          grams: { $first: "$grams" },
          lastUsed: { $first: "$createdAt" },
          count: { $sum: 1 },
        },
      },
      { $sort: { lastUsed: -1 } },
      { $limit: limit },
    ]).allowDiskUse(true);

    console.log(`[Previous Meals] User: ${userObjectId} | Found: ${previousMeals.length} unique meals`);

    return res.status(200).json({
      previousMeals: previousMeals.map((meal) => ({
        id: meal._id,
        mealName: meal.meal_name,
        mealType: meal.meal_type,
        calories: numberOrZero(meal.calories),
        protein: numberOrZero(meal.protein),
        carbs: numberOrZero(meal.carbs),
        fat: numberOrZero(meal.fat),
        grams: numberOrZero(meal.grams),
        timesUsed: meal.count,
        lastUsed: meal.lastUsed,
      })),
    });
  } catch (error) {
    console.error("Error loading previous meals:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
};

module.exports = {
  addMealsBatch,
  getDailySummary,
  analyzeQuickAddMeal,
  getPreviousMeals,
  updateDailyWater,
};
