const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const http = require('http');

const connectDB = require('./config/db');

dotenv.config();

connectDB();

const app = express();

const server = http.createServer(app);

const socket = require('./socket');

socket.init(server);
app.set('io', socket.getIO());
app.use(cors());
app.use(express.json());

// ✅ Static uploads
app.use('/uploads', express.static('uploads'));

// ✅ Test route
app.get('/test', (req, res) => {
  res.json({ message: 'Test route working!' });
});

// ✅ Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/users', require('./routes/userRoutes'));
app.use('/api/chefs', require('./routes/chefRoutes'));
app.use('/api/user-profile', require('./routes/userProfileRoutes'));
app.use('/api/banners', require('./routes/bannerRoutes'));
app.use('/api/reviews', require('./routes/reviewRoutes'));
app.use('/api/recipes', require('./routes/recipeRoutes'));
app.use('/api/orders', require('./routes/orderRoutes'));
app.use(
  '/api/review-recipe',
  require('./routes/reviewRecipeRoutes'),
);
// ✅ Home route
app.get('/', (req, res) => {
  res.send('Yummy backend is running');
});

// ✅ Error handler
app.use((err, req, res, next) => {

  console.error(err.stack);

  res.status(500).json({
    success: false,
    message: 'Something went wrong on the server!',
  });

});

const PORT = process.env.PORT || 5000;

server.listen(PORT, '0.0.0.0', () => {

  console.log(`🔥 Server running on port ${PORT}`);

});