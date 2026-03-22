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

    // Validate height value - must be between 50cm and 300cm
    if (height_value !== undefined && height_value !== null) {
      const heightNum = Number(height_value);
      if (isNaN(heightNum) || heightNum < 50 || heightNum > 300) {
        return res.status(400).json({
          message: "Height must be between 50 and 300 cm",
        });
      }
    }

    // Validate weight value - must be between 10kg and 600kg
    if (weight_value !== undefined && weight_value !== null) {
      const weightNum = Number(weight_value);
      if (isNaN(weightNum) || weightNum < 10 || weightNum > 600) {
        return res.status(400).json({
          message: "Weight must be between 10 and 600 kg",
        });
      }
    }

    const updatedUser = await User.findByIdAndUpdate(
      user_id,
      { name: name.trim() },
      { new: true }
    );

    if (!updatedUser) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const existingProfile = await UserProfile.findOne({ user_id });

    let imagePath = existingProfile?.image || "";

    if (req.file) {
      imagePath = `/uploads/${req.file.filename}`;
    }

    const profile = await UserProfile.findOneAndUpdate(
      { user_id },
      {
        user_id,
        goal: goal || "",
        gender: gender || "",
        date_of_birth: date_of_birth || null,
        height: {
          value: height_value || 0,
          unit: height_unit || "cm",
        },
        weight: {
          value: weight_value || 0,
          unit: weight_unit || "kg",
        },
        activity_level: activity_level || "",
        allergies: Array.isArray(allergies)
          ? allergies
          : allergies
          ? [allergies]
          : [],
        medical_conditions: Array.isArray(medical_conditions)
          ? medical_conditions
          : medical_conditions
          ? [medical_conditions]
          : [],
        image: imagePath,
      },
      { new: true, upsert: true }
    );

    const baseUrl = `${req.protocol}://${req.get("host")}`;

    res.status(201).json({
      message: "Profile and name saved successfully",
      user: updatedUser,
      profile: {
        ...profile.toObject(),
        image_url: profile.image ? `${baseUrl}${profile.image}` : "",
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

const getMyProfile = async (req, res) => {
  try {
    const user_id = req.user.userId;

    const user = await User.findById(user_id).select("name email");
    const profile = await UserProfile.findOne({ user_id });

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    const baseUrl = `${req.protocol}://${req.get("host")}`;

    res.status(200).json({
      user,
      profile: profile
        ? {
            ...profile.toObject(),
            image_url: profile.image ? `${baseUrl}${profile.image}` : "",
          }
        : null,
    });
  } catch (error) {
    res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

module.exports = { createOrUpdateProfile, getMyProfile };
