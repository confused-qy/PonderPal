const friendService = require("../services/friendService");

async function getFriends(req, res, next) {
  try {
    const friends = await friendService.getFriends(req.user, req.query.me);
    return res.json({ friends });
  } catch (err) {
    return next(err);
  }
}

async function linkFriend(req, res, next) {
  try {
    const friendAnswers = await friendService.linkFriend(
      req.user,
      req.body.me,
      req.body.friend
    );
    return res.json({ friend_answers: friendAnswers });
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  getFriends,
  linkFriend
};
