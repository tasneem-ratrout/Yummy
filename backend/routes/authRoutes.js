const express = require("express");
const router = express.Router();
const verifyToken = require("../middleware/authMiddleware");
const { authLimiter, resetCodeLimiter } = require("../middleware/rateLimitMiddleware");

const {
  register,
  login,
  updateUserName,
  sendResetCode,
  verifyResetCode,
  resetPassword,
  getMe,
} = require("../controllers/authController");

// Authentication endpoints with rate limiting
router.post("/register", authLimiter, register);
router.post("/login", authLimiter, login);
router.get("/me", verifyToken, getMe);
router.patch("/update-name", verifyToken, updateUserName);

// Password reset with strict rate limiting
router.post("/forgot-password/send-code", resetCodeLimiter, sendResetCode);
router.post("/forgot-password/verify-code", resetCodeLimiter, verifyResetCode);
router.post("/forgot-password/reset", resetCodeLimiter, resetPassword);

module.exports = router;
