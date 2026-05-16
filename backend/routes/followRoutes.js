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
  toggleFollow,
  getFollowers,
  getFollowing,
  checkFollowStatus,
  getUserStats,
} = require("../controllers/followController");

// ✅ Toggle follow/unfollow
router.post(
  "/toggle",
  verifyToken,
  apiLimiter,
  toggleFollow,
);

// ✅ Get followers list
router.get(
  "/:userId/followers",
  verifyToken,
  apiLimiter,
  getFollowers,
);

// ✅ Get following list
router.get(
  "/:userId/following",
  verifyToken,
  apiLimiter,
  getFollowing,
);

// ✅ Check follow status
router.get(
  "/:targetUserId/status",
  verifyToken,
  checkFollowStatus,
);

// ✅ Get user stats
router.get(
  "/:userId/stats",
  verifyToken,
  getUserStats,
);

module.exports = router;