const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const connectDB = require("./config/db");
const verifyToken = require("./middleware/authMiddleware");

dotenv.config();
connectDB();

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Yummy backend is running");
});

app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/user-profile", require("./routes/userProfileRoutes"));

app.get("/api/auth/me", verifyToken, (req, res) => {
  res.status(200).json({
    message: "Authorized",
    user: req.user,
  });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});