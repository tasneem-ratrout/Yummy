const express = require("express");
const router = express.Router();
const {
  createOrUpdateProfile,
} = require("../controllers/userProfileController");
const verifyToken = require("../middleware/authMiddleware");

router.post("/", verifyToken, createOrUpdateProfile);

module.exports = router;