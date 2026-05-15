const express     = require('express');
const router      = express.Router();
const { verifyToken } = require('../middleware/authMiddleware'); // ← أضيف {}
const { createOrUpdateProfile } = require('../controllers/userProfileController');

router.post('/', verifyToken, createOrUpdateProfile);

module.exports = router;