const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const User = require("../models/User");
const Chef = require("../models/Chef");

const UserProfile = require("../models/UserProfile");
const UserFollow = require("../models/UserFollow");

const { sendResetCodeEmail } = require("../services/emailService");
const { addDeviceToken } = require("../services/notificationService");

// ✅ ERROR HANDLER
const handleError = (error, res) => {
  console.error("ERROR =>", error);

  return res.status(500).json({
    success: false,
    message: "Server error",
    error: error.message,
  });
};

// ═══════════════════════════════════════════════
// ✅ REGISTER
// ═══════════════════════════════════════════════
const register = async (req, res) => {
  try {
    const { name, email, password, role } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    // ✅ PASSWORD VALIDATION
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters",
      });
    }

    const cleanEmail = email.toLowerCase().trim();

    const existingUser = await User.findOne({
      email: cleanEmail,
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "Email already exists",
      });
    }

    // ✅ HASH PASSWORD
    const hashedPassword = await bcrypt.hash(
      password.trim(),
      10,
    );

    // ✅ CREATE USER
    const user = await User.create({
      name: name || "",
      email: cleanEmail,
      password: hashedPassword,
      role: role || "user",
    });

    // ✅ CREATE CHEF PROFILE
    if (role === "chef") {
      await Chef.create({
        userId: user._id,
      });
    }

    // ✅ TOKEN
    const token = jwt.sign(
      {
        userId: user._id,
        name: user.name,
        role: user.role,
      },

      process.env.JWT_SECRET,

      {
        expiresIn: "7d",
      },
    );

    res.status(201).json({
      success: true,
      message: "Account created successfully",

      token,

      userId: user._id,

      role: user.role,

      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    handleError(error, res);
  }
};

// ═══════════════════════════════════════════════
// ✅ LOGIN
// ═══════════════════════════════════════════════
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    // ✅ CLEAN EMAIL
    const cleanEmail = email.toLowerCase().trim();

    // ✅ FIND USER
    const user = await User.findOne({
      email: cleanEmail,
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "User not found",
      });
    }

    // ✅ BANNED CHECK
    if (user.isBanned) {
      return res.status(403).json({
        success: false,
        message: "User is banned",
      });
    }

    // ✅ PASSWORD CHECK
    const isMatch = await bcrypt.compare(
      password.trim(),
      user.password,
    );

    console.log("LOGIN PASSWORD =>", password.trim());
    console.log("HASH FROM DB =>", user.password);
    console.log("PASSWORD MATCH =>", isMatch);

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: "Wrong email or password",
      });
    }

    // ✅ GET CHEF ID
    let chefId = null;

    if (user.role === "chef") {
      const chef = await Chef.findOne({
        userId: user._id,
      });

      if (chef) {
        chefId = chef._id;
      }
    }

    // ✅ TOKEN
    const token = jwt.sign(
      {
        userId: user._id,
        name: user.name,
        role: user.role,
      },

      process.env.JWT_SECRET,

      {
        expiresIn: "7d",
      },
    );

    // ✅ SUCCESS
    res.status(200).json({
      success: true,

      message: "Login successful",

      token,

      userId: user._id,

      chefId,

      name: user.name,

      email: user.email,

      role: user.role,

      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    console.log("LOGIN ERROR =>", error);

    handleError(error, res);
  }
};

// ═══════════════════════════════════════════════
// ✅ REGISTER DEVICE TOKEN
// ═══════════════════════════════════════════════
const registerDeviceToken = async (req, res) => {
  try {
    const userId = req.user?.userId;

    const { token } = req.body;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    if (!token || !token.trim()) {
      return res.status(400).json({
        success: false,
        message: "Device token is required",
      });
    }

    await addDeviceToken(
      userId,
      token.trim(),
    );

    res.status(200).json({
      success: true,
      message: "Device token saved successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};

// ═══════════════════════════════════════════════
// ✅ UPDATE USER NAME
// ═══════════════════════════════════════════════
const updateUserName = async (req, res) => {
  try {
    const { userId, name } = req.body;

    if (!userId || !name) {
      return res.status(400).json({
        success: false,
        message: "userId and name are required",
      });
    }

    const user = await User.findByIdAndUpdate(
      userId,

      {
        name: name.trim(),
      },

      {
        new: true,
      },
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Name updated successfully",

      user,
    });
  } catch (error) {
    handleError(error, res);
  }
};

// ═══════════════════════════════════════════════
// ✅ SEND RESET CODE
// ═══════════════════════════════════════════════
const sendResetCode = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !email.trim()) {
      return res.status(400).json({
        success: false,
        message: "Email is required",
      });
    }

    const normalizedEmail =
      email.trim().toLowerCase();

    const user = await User.findOne({
      email: normalizedEmail,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const code =
      Math.floor(
        1000 + Math.random() * 9000,
      ).toString();

    const hashedCode = crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");

    user.reset_code = hashedCode;

    user.reset_code_expires =
      new Date(
        Date.now() + 10 * 60 * 1000,
      );

    user.reset_code_verified = false;

    await user.save();

    await sendResetCodeEmail(
      user.email,
      code,
    );

    res.status(200).json({
      success: true,
      message: "Reset code sent successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};

// ═══════════════════════════════════════════════
// ✅ VERIFY RESET CODE
// ═══════════════════════════════════════════════
const verifyResetCode = async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({
        success: false,
        message: "Email and code are required",
      });
    }

    const normalizedEmail =
      email.trim().toLowerCase();

    const user = await User.findOne({
      email: normalizedEmail,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const hashedCode = crypto
      .createHash("sha256")
      .update(code)
      .digest("hex");

    if (
      hashedCode !== user.reset_code
    ) {
      return res.status(400).json({
        success: false,
        message: "Invalid verification code",
      });
    }

    if (
      user.reset_code_expires <
      new Date()
    ) {
      return res.status(400).json({
        success: false,
        message: "Verification code expired",
      });
    }

    user.reset_code_verified = true;

    await user.save();

    res.status(200).json({
      success: true,
      message: "Code verified successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};

// ═══════════════════════════════════════════════
// ✅ RESET PASSWORD
// ═══════════════════════════════════════════════
const resetPassword = async (req, res) => {
  try {
    const { email, newPassword } =
      req.body;

    if (!email || !newPassword) {
      return res.status(400).json({
        success: false,
        message:
          "Email and new password are required",
      });
    }

    const normalizedEmail =
      email.trim().toLowerCase();

    const user = await User.findOne({
      email: normalizedEmail,
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    if (!user.reset_code_verified) {
      return res.status(400).json({
        success: false,
        message:
          "Verification code not confirmed",
      });
    }

    const hashedPassword =
      await bcrypt.hash(
        newPassword.trim(),
        10,
      );

    user.password = hashedPassword;

    user.reset_code = null;
    user.reset_code_expires = null;
    user.reset_code_verified = false;

    await user.save();

    res.status(200).json({
      success: true,
      message:
        "Password reset successfully",
    });
  } catch (error) {
    handleError(error, res);
  }
};

// ═══════════════════════════════════════════════
// ✅ GET ME
// ═══════════════════════════════════════════════
const getMe = async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findById(
      userId,
    ).select("-password -reset_code");

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const profile =
      await UserProfile.findOne({
        user_id: userId,
      });

    const followerCount =
      await UserFollow.countDocuments({
        following_id: userId,
      });

    const followingCount =
      await UserFollow.countDocuments({
        follower_id: userId,
      });

    const baseUrl =
      `${req.protocol}://${req.get("host")}`;

    res.status(200).json({
      success: true,

      message:
        "User fetched successfully",

      user: {
        id: user._id,

        name: user.name,

        email: user.email,

        role: user.role,

        followerCount,

        followingCount,

        profile: profile
          ? {
              ...profile.toObject(),

              image_url:
                profile.image
                  ? `${baseUrl}${profile.image}`
                  : "",
            }
          : null,
      },
    });
  } catch (error) {
    handleError(error, res);
  }
};

module.exports = {
  register,
  login,
  registerDeviceToken,
  updateUserName,
  sendResetCode,
  verifyResetCode,
  resetPassword,
  getMe,
};