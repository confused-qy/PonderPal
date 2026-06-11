const answerService = require("../services/answerService");

async function sync(req, res, next) {
  try {
    const result = await answerService.syncAnswers(
      req.user,
      req.body.username,
      req.body.answers || {}
    );
    return res.json(result);
  } catch (err) {
    return next(err);
  }
}

async function getFriendAnswers(req, res, next) {
  try {
    const answers = await answerService.getVisibleAnswers(req.params.name);
    return res.json({ answers });
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  sync,
  getFriendAnswers
};
