const express = require("express");

const router = express.Router();

const upload = require("../middleware/uploadMiddleware");

// ✅ FIX IMPORT
const {
  verifyToken,
} = require("../middleware/authMiddleware");

const postController = require("../controllers/postController");

// ✅ GET POSTS
router.get(
  "/",
  verifyToken,
  postController.getPosts,
);

// ✅ CREATE POST
router.post(
  "/",
  verifyToken,
  upload.single("image"),
  postController.createPost,
);

// ✅ TOGGLE LIKE
router.post(
  "/:postId/like",
  verifyToken,
  postController.toggleLike,
);

// ✅ ADD COMMENT
router.post(
  "/:postId/comment",
  verifyToken,
  postController.addComment,
);

// ✅ DELETE POST
router.delete(
  "/:postId",
  verifyToken,
  postController.deletePost,
);

module.exports = router;