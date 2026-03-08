const UserProfile = require("../models/UserProfile");
const User = require("../models/User");

const createOrUpdateProfile = async (req, res) => {
  try {
    const user_id = req.user.userId;

    const {
      name,
      goal,
      gender,
      date_of_birth,
      height_value,
      height_unit,
      weight_value,
      weight_unit,
      activity_level,
      allergies,
      medical_conditions,
    } = req.body;

    if (!user_id) {
      return res.status(400).json({
        message: "user_id is required",
      });
    }

    if (!name || !name.trim()) {
      return res.status(400).json({
        message: "name is required",
      });
    }

    const updatedUser = await User.findByIdAndUpdate(
      user_id,
      { name: name.trim() },
      { returnDocument: "after" }
    );

    if (!updatedUser) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const profile = await UserProfile.findOneAndUpdate(
      { user_id },
      {
        user_id,
        goal,
        gender,
        date_of_birth,
        height: {
          value: height_value,
          unit: height_unit,
        },
        weight: {
          value: weight_value,
          unit: weight_unit,
        },
        activity_level,
        allergies,
        medical_conditions,
      },
      { returnDocument: "after", upsert: true }
    );

    res.status(201).json({
      message: "Profile and name saved successfully",
      user: updatedUser,
      profile,
    });
  } catch (error) {
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

module.exports = { createOrUpdateProfile };