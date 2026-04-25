const express = require("express");
const router = express.Router();
const {
  createOrUpdateProfile,
  getMyProfile,
  updateMyStreak,
} = require("../controllers/userProfileController");
const verifyToken = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");
const { apiLimiter } = require("../middleware/rateLimitMiddleware");

router.get("/me", verifyToken, getMyProfile);
router.post("/", verifyToken, apiLimiter, upload.single("image"), createOrUpdateProfile);
router.patch("/streak", verifyToken, updateMyStreak);

module.exports = router;
