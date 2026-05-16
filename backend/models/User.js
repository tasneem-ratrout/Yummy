const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
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

    role: {
      type: String,
      enum: ["user", "chef", "admin"],
      default: "user",
    },

    isBanned: {
      type: Boolean,
      default: false,
    },

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

    fcmTokens: {
      type: [String],
      default: [],
    },
  },
  { timestamps: true }
);

// ✅ HASH PASSWORD ONLY IF MODIFIED
userSchema.pre("save", async function (next) {
  try {
    if (!this.isModified("password")) {
      return next();
    }

    const salt = await bcrypt.genSalt(10);

    this.password = await bcrypt.hash(
      this.password,
      salt
    );

    next();
  } catch (e) {
    next(e);
  }
});

// ✅ IMPORTANT FIX
module.exports =
  mongoose.models.User ||
  mongoose.model("User", userSchema);