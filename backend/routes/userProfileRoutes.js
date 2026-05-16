const express = require("express");

const router = express.Router();

const {
  createOrUpdateProfile,
  getMyProfile,
  updateMyStreak,
  getUsersStreaks,
  searchUsers,
} = require("../controllers/userProfileController");

// ✅ FIX IMPORT
const {
  verifyToken,
} = require("../middleware/authMiddleware");

const upload = require("../middleware/uploadMiddleware");

const {
  apiLimiter,
} = require("../middleware/rateLimitMiddleware");

// ✅ GET MY PROFILE
router.get(
  "/me",
  verifyToken,
  getMyProfile,
);

// ✅ GET USERS STREAKS
router.get(
  "/users-streaks",
  verifyToken,
  apiLimiter,
  getUsersStreaks,
);

// ✅ SEARCH USERS
router.get(
  "/search",
  verifyToken,
  apiLimiter,
  searchUsers,
);

// ✅ CREATE OR UPDATE PROFILE
router.post(
  "/",
  verifyToken,
  apiLimiter,
  upload.single("image"),
  createOrUpdateProfile,
);

// ✅ UPDATE STREAK
router.patch(
  "/streak",
  verifyToken,
  updateMyStreak,
);

module.exports = router;