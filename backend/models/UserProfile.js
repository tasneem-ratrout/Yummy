const mongoose = require("mongoose");

const userProfileSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    goal: {
      type: String,
      default: "",
    },
    gender: {
      type: String,
      default: "",
    },
    date_of_birth: {
      type: Date,
      default: null,
    },
    height: {
      value: {
        type: Number,
        default: 0,
      },
      unit: {
        type: String,
        default: "cm",
      },
    },
    weight: {
      value: {
        type: Number,
        default: 0,
      },
      unit: {
        type: String,
        default: "kg",
      },
    },
    activity_level: {
      type: String,
      default: "",
    },
    allergies: {
      type: [String],
      default: [],
    },
    medical_conditions: {
      type: [String],
      default: [],
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("UserProfile", userProfileSchema);