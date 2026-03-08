const express = require("express");
const router = express.Router();
const {
  register,
  login,
  updateUserName,
} = require("../controllers/authController");

router.post("/register", register);
router.post("/login", login);
router.patch("/update-name", updateUserName);

module.exports = router;