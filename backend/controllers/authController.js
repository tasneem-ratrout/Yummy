const bcrypt = require("bcryptjs");
const jwt    = require("jsonwebtoken");
const User   = require("../models/User");
const Chef   = require("../models/Chef");
const register = async (req, res) => {
  try {
    const { name, email, password, role } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        message: "Name, email and password are required"
      });
    }

    const existingUser = await User.findOne({
      email: email.toLowerCase().trim()
    });

    if (existingUser) {
      return res.status(400).json({
        message: "Email already exists"
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await User.create({
      name,
      email: email.toLowerCase().trim(), // 🔥 مهم
      password: hashedPassword,
      role: role || "user",
    });

    if (role === "chef") {
      await Chef.create({
        userId: user._id
      });
    }

    res.status(201).json({
      success: true,
      message: "Account created successfully",
      userId: user._id,
      role: user.role,
    });

  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message
    });
  }
};
const login = async (req, res) => {

  try {

    const {
      email,
      password,
    } = req.body;

    // ✅ FIX EMAIL
    const cleanEmail =
        email
            .toLowerCase()
            .trim();

    const user =
        await User.findOne({

      email: cleanEmail,
    });

    // ✅ USER NOT FOUND
    if (!user) {

      return res.status(400).json({

        success: false,

        message:
            "User not found",
      });
    }

    // ✅ BANNED CHECK
    if (user.isBanned) {

      return res.status(403).json({

        success: false,

        message:
            "User is banned",
      });
    }

    // ✅ PASSWORD CHECK
    const isMatch =
        await bcrypt.compare(

      password.trim(),

      user.password,
    );

    if (!isMatch) {

      return res.status(400).json({

        success: false,

        message:
            "Wrong email or password",
      });
    }

    // ✅ GET CHEF ID
    let chefId = null;

    if (user.role === "chef") {

      const chef =
          await Chef.findOne({

        userId:
            user._id,
      });

      if (chef) {

        chefId =
            chef._id;
      }
    }

    // ✅ TOKEN
    const token =
        jwt.sign(

      {

        userId:
            user._id,

        name:
            user.name,

        role:
            user.role,
      },

      process.env.JWT_SECRET,

      {
        expiresIn: "7d",
      }
    );

    // ✅ SUCCESS
    res.status(200).json({

      success: true,

      token,

      userId:
          user._id,

      chefId,

      name:
          user.name,

      email:
          user.email,

      role:
          user.role,
    });

  } catch (error) {

    console.log(
      "LOGIN ERROR =>",
      error,
    );

    res.status(500).json({

      success: false,

      message:
          "Server error",

      error:
          error.message,
    });
  }
};
const updateUserName = async (req, res) => {
  try {
    const { userId, name } = req.body;

    if (!userId || !name)
      return res.status(400).json({ message: "userId and name are required" });

    const user = await User.findByIdAndUpdate(
      userId,
      { name: name.trim() },
      { new: true }
    );

    if (!user)
      return res.status(404).json({ message: "User not found" });

    res.status(200).json({ message: "Name updated successfully", user });
  } catch (error) {
    res.status(500).json({ message: "Server error", error: error.message });
  }
};

module.exports = { register, login, updateUserName };