const express = require("express");
const answerController = require("../controllers/answerController");
const friendController = require("../controllers/friendController");
const requireAuth = require("../middleware/auth");

const router = express.Router();

router.use(requireAuth);

router.post("/sync", answerController.sync);
router.get("/friends", friendController.getFriends);
router.post("/friend/link", friendController.linkFriend);
router.get("/friend/:name/answers", answerController.getFriendAnswers);

module.exports = router;
