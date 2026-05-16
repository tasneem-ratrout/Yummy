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
  getMyNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
} = require("../controllers/notificationController");

// ✅ GET MY NOTIFICATIONS
router.get(
  "/",
  verifyToken,
  apiLimiter,
  getMyNotifications,
);

// ✅ MARK ALL AS READ
router.patch(
  "/read-all",
  verifyToken,
  apiLimiter,
  markAllNotificationsAsRead,
);

// ✅ MARK ONE AS READ
router.patch(
  "/:notificationId/read",
  verifyToken,
  apiLimiter,
  markNotificationAsRead,
);

module.exports = router;