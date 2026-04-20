const express = require("express");
const router = express.Router();

const verifyToken = require("../middleware/authMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");
const { addMealsBatch, getDailySummary, getPreviousMeals, updateDailyWater } = require("../controllers/mealController");

router.post("/batch", verifyToken, apiLimiter, addMealsBatch);
router.get("/summary", verifyToken, apiLimiter, getDailySummary);
router.get("/previous", verifyToken, apiLimiter, getPreviousMeals);
router.get("/saved-foods", verifyToken, apiLimiter, getPreviousMeals);
router.patch("/water", verifyToken, apiLimiter, updateDailyWater);

module.exports = router;
