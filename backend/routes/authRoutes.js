const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
    // ═══════════════════════════════
    // 👤 BASIC INFO
    // ═══════════════════════════════
    name: {
      type: String,
      default: "",
      trim: true,
    },

    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,

      match: [
        /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
        "Please provide a valid email address",
      ],
    },

    password: {
      type: String,
      required: true,
    },

    // ═══════════════════════════════
    // 🎭 ROLE
    // ═══════════════════════════════
    role: {
      type: String,
      enum: ["user", "chef", "admin"],
      default: "user",
    },

    // ═══════════════════════════════
    // 🚫 BAN
    // ═══════════════════════════════
    isBanned: {
      type: Boolean,
      default: false,
    },

    // ═══════════════════════════════
    // 🔐 RESET PASSWORD
    // ═══════════════════════════════
    reset_code: {
      type: String,
      default: null,
    },

    reset_code_expires: {
      type: Date,
      default: null,
    },

    reset_code_verified: {
      type: Boolean,
      default: false,
    },

    // ═══════════════════════════════
    // 👥 FOLLOW SYSTEM
    // ═══════════════════════════════
    followers: {
      type: [mongoose.Schema.Types.ObjectId],

      ref: "User",

      default: [],
    },

    following: {
      type: [mongoose.Schema.Types.ObjectId],

      ref: "User",

      default: [],
    },

    // ═══════════════════════════════
    // 🔔 FCM TOKENS
    // ═══════════════════════════════
    fcmTokens: {
      type: [String],

      default: [],
    },
  },

  {
    timestamps: true,
  },
);

// ═══════════════════════════════
// 🔥 AUTO HASH PASSWORD
// ═══════════════════════════════
userSchema.pre(
  "save",

  async function (next) {
    try {
      // ✅ IF PASSWORD NOT MODIFIED
      if (!this.isModified("password")) {
        return next();
      }

      // ✅ PREVENT DOUBLE HASH
      if (
        this.password.startsWith("$2a$") ||
        this.password.startsWith("$2b$")
      ) {
        return next();
      }

      // ✅ HASH PASSWORD
      const salt =
        await bcrypt.genSalt(10);

      this.password =
        await bcrypt.hash(
          this.password,
          salt,
        );

      next();
    } catch (error) {
      next(error);
    }
  },
);

module.exports = mongoose.model(
  "User",
  userSchema,
);