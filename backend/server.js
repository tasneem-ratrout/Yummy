const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");
const helmet = require("helmet");
const http = require("http");
const path = require("path");

const connectDB = require("./config/db");

dotenv.config();

connectDB();

const app = express();
const server = http.createServer(app);

// ✅ SOCKET.IO
const socket = require("./socket");

socket.init(server);

app.set("io", socket.getIO());

// ✅ REQUEST LOGGER
app.use((req, res, next) => {
  console.log("🔥 REQUEST:", req.method, req.originalUrl);
  next();
});

// ✅ SECURITY
app.use(helmet());

// ✅ HTTPS REDIRECT IN PRODUCTION
app.use((req, res, next) => {
  if (
    process.env.NODE_ENV === "production" &&
    req.header("x-forwarded-proto") !== "https"
  ) {
    return res.redirect(`https://${req.header("host")}${req.url}`);
  }

  next();
});

// ✅ ALLOWED ORIGINS
const allowedOrigins = [
  "http://localhost:3000",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
  "http://192.168.1.50:8080",

  // Firebase Hosting
  "https://yummy-d1eb2.web.app",
  "https://yummy-d1eb2.firebaseapp.com",
];

// ✅ CORS
app.use(
  cors({
    origin: function (origin, callback) {
      // ✅ Allow mobile apps / Postman
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }

      console.log("❌ CORS blocked origin:", origin);

      return callback(
        new Error(`CORS blocked this origin: ${origin}`)
      );
    },

    credentials: true,

    optionsSuccessStatus: 200,

    methods: [
      "GET",
      "POST",
      "PUT",
      "PATCH",
      "DELETE",
      "OPTIONS",
    ],

    allowedHeaders: [
      "Content-Type",
      "Authorization",
    ],
  })
);

// ✅ BODY PARSER
app.use(express.json());

app.use(
  express.urlencoded({
    extended: true,
  })
);

// ✅ STATIC UPLOADS
app.use(
  "/uploads",
  express.static(
    path.join(__dirname, "uploads")
  )
);

// ✅ HOME ROUTE
app.get("/", (req, res) => {
  res.send("Yummy backend is running");
});

// ✅ TEST ROUTE
app.get("/test", (req, res) => {
  res.json({
    message: "Test route working!",
  });
});

// ═══════════════════════════════════════
// ✅ ROUTES
// ═══════════════════════════════════════

app.use(
  "/api/auth",
  require("./routes/authRoutes")
);

app.use(
  "/api/users",
  require("./routes/userRoutes")
);

app.use(
  "/api/chefs",
  require("./routes/chefRoutes")
);

app.use(
  "/api/user-profile",
  require("./routes/userProfileRoutes")
);

app.use(
  "/api/follow",
  require("./routes/followRoutes")
);

app.use(
  "/api/notifications",
  require("./routes/notificationRoutes")
);

app.use(
  "/api/banners",
  require("./routes/bannerRoutes")
);

app.use(
  "/api/reviews",
  require("./routes/reviewRoutes")
);

app.use(
  "/api/recipes",
  require("./routes/recipeRoutes")
);

app.use(
  "/api/orders",
  require("./routes/orderRoutes")
);

app.use(
  "/api/review-recipe",
  require("./routes/reviewRecipeRoutes")
);

// ✅ MEALS LOGGER
app.use("/api/meals", (req, res, next) => {
  console.log(
    `🍽️ MEALS ${req.method} ${req.originalUrl}`
  );

  next();
});

app.use(
  "/api/meals",
  require("./routes/mealRoutes")
);

// ✅ POSTS LOGGER
app.use("/api/posts", (req, res, next) => {
  console.log(
    `📮 POSTS ${req.method} ${req.originalUrl}`
  );

  next();
});

app.use(
  "/api/posts",
  require("./routes/postRoutes")
);

// ═══════════════════════════════════════
// ✅ 404 HANDLER
// ═══════════════════════════════════════

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});

// ═══════════════════════════════════════
// ✅ GLOBAL ERROR HANDLER
// ═══════════════════════════════════════

app.use((err, req, res, next) => {
  console.error("❌ ERROR:", err.message);

  const message =
    process.env.NODE_ENV === "production"
      ? "An error occurred. Please try again later."
      : err.message;

  res.status(err.status || 500).json({
    success: false,
    message,
  });
});

// ═══════════════════════════════════════
// ✅ START SERVER
// ═══════════════════════════════════════

const PORT = process.env.PORT || 5000;

server.listen(PORT, "0.0.0.0", () => {
  console.log(
    `🔥 Server running on port ${PORT}`
  );
});