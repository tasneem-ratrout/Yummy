
const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const helmet = require("helmet");
const connectDB = require("./config/db");
const path = require("path");

dotenv.config();
connectDB();

const app = express();

app.use(helmet());

// Redirect to HTTPS in production
app.use((req, res, next) => {
  if (process.env.NODE_ENV === "production" && req.header("x-forwarded-proto") !== "https") {
    return res.redirect(`https://${req.header("host")}${req.url}`);
  }
  next();
});

app.use(cors({
  origin: process.env.FRONTEND_URL || "http://localhost:3000",
  credentials: true,
  optionsSuccessStatus: 200,
  methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"]
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Serve uploaded profile images
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.get("/", (req, res) => {
  res.send("Yummy backend is running");
});

app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/user-profile", require("./routes/userProfileRoutes"));
app.use("/api/follow", require("./routes/followRoutes"));
app.use("/api/meals", (req, res, next) => {
  console.log(`MEALS ${req.method} ${req.originalUrl}`);
  next();
});
app.use("/api/meals", require("./routes/mealRoutes"));
app.use("/api/posts", (req, res, next) => {
  console.log(`📮 POSTS ${req.method} ${req.originalUrl}`);
  next();
});
app.use("/api/posts", require("./routes/postRoutes"));

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ message: "Route not found" });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error("Error:", err.message);
  
  // Don't expose internal error details in production
  const message = process.env.NODE_ENV === "production" 
    ? "An error occurred. Please try again later."
    : err.message;
    
  res.status(err.status || 500).json({ message });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
