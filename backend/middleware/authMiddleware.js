// 📁 middleware/authMiddleware.js
const jwt = require("jsonwebtoken");
const User = require("../models/User");

const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        message: "No token provided",
      });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // ✅ جلب المستخدم من قاعدة البيانات للحصول على الاسم
    const user = await User.findById(decoded.userId).select('name role');
    
    if (!user) {
      return res.status(401).json({ message: "User not found" });
    }

    req.user = {
      id: decoded.userId,
      userId: decoded.userId,
      name: user.name,
      role: user.role,
    };
    
    next();
  } catch (error) {
    return res.status(401).json({
      message: "Invalid or expired token",
    });
  }
};

const adminOnly = (req, res, next) => {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Admin access only' });
  }
  next();
};

module.exports = { verifyToken, adminOnly };