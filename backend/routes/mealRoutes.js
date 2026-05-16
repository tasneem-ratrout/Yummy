const express = require("express");

const router = express.Router();

// ✅ FIX IMPORT
const {
  verifyToken,
} = require("../middleware/authMiddleware");

const {
  apiLimiter,
} = require("../middleware/rateLimitMiddleware");

const {
  addMealsBatch,
  getDailySummary,
  getPeriodSummary,
  analyzeQuickAddMeal,
  getPreviousMeals,
  updateDailyWater,
} = require("../controllers/mealController");

// ✅ ADD MEALS
router.post(
  "/batch",
  verifyToken,
  apiLimiter,
  addMealsBatch,
);

// ✅ DAILY SUMMARY
router.get(
  "/summary",
  verifyToken,
  apiLimiter,
  getDailySummary,
);

// ✅ PERIOD SUMMARY
router.get(
  "/summary/period",
  verifyToken,
  apiLimiter,
  getPeriodSummary,
);

// ✅ QUICK ADD ANALYZE
router.post(
  "/quick-add/analyze",
  verifyToken,
  apiLimiter,
  analyzeQuickAddMeal,
);

// ✅ PREVIOUS MEALS
router.get(
  "/previous",
  verifyToken,
  apiLimiter,
  getPreviousMeals,
);

// ✅ SAVED FOODS
router.get(
  "/saved-foods",
  verifyToken,
  apiLimiter,
  getPreviousMeals,
);

// ✅ UPDATE WATER
router.patch(
  "/water",
  verifyToken,
  apiLimiter,
  updateDailyWater,
);

module.exports = router;