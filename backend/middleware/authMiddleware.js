const jwt = require("jsonwebtoken");
const User = require("../models/User");

// ✅ VERIFY TOKEN
const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    // ✅ CHECK TOKEN EXISTS
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "No token provided",
      });
    }

    // ✅ EXTRACT TOKEN
    const token = authHeader.split(" ")[1];

    // ✅ VERIFY TOKEN
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET,
    );

    // ✅ GET USER FROM DATABASE
    const user = await User.findById(
      decoded.userId,
    ).select("name role email");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User not found",
      });
    }

    // ✅ SAVE USER IN REQUEST
    req.user = {
      id: user._id,
      userId: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
    };

    next();

  } catch (error) {

    console.log(
      "VERIFY TOKEN ERROR =>",
      error,
    );

    return res.status(401).json({
      success: false,
      message: "Invalid or expired token",
    });
  }
};

// ✅ ADMIN ONLY
const adminOnly = (req, res, next) => {

  try {

    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    if (req.user.role !== "admin") {
      return res.status(403).json({
        success: false,
        message: "Admin access only",
      });
    }

    next();

  } catch (error) {

    console.log(
      "ADMIN MIDDLEWARE ERROR =>",
      error,
    );

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

module.exports = {
  verifyToken,
  adminOnly,
};