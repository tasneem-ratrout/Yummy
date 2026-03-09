const express = require("express");
const router = express.Router();

const {
  register,
  login,
  updateUserName,
  sendResetCode,
  verifyResetCode,
  resetPassword,
} = require("../controllers/authController");

router.post("/register", register);
router.post("/login", login);
router.patch("/update-name", updateUserName);

router.post("/forgot-password/send-code", sendResetCode);
router.post("/forgot-password/verify-code", verifyResetCode);
router.post("/forgot-password/reset", resetPassword);

module.exports = router;