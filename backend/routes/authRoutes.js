const express = require('express');
const router = express.Router();

const { login, register } = require('../controllers/authController');
const { verifyToken } = require('../middleware/authMiddleware');

router.post('/register', register);
router.post('/login', login);

// 📁 routes/authRoutes.js (أضف هذا الـ route)
router.get('/me', verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user.id || req.user.userId).select('-password');
    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        profileImage: user.profileImage,
      }
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;