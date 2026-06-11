const usersDb = require("../db/users");
const answersDb = require("../db/answers");

function assertSameUser(reqUser, username) {
  if (reqUser.username !== username) {
    const err = new Error("Token user does not match request username");
    err.status = 403;
    err.publicMessage = "Forbidden";
    throw err;
  }
}

async function syncAnswers(reqUser, username, answers) {
  assertSameUser(reqUser, username);

  const user = await usersDb.findUserByUsername(username);
  if (!user) {
    const err = new Error("User not found");
    err.status = 404;
    err.publicMessage = "User not found";
    throw err;
  }

  await answersDb.upsertAnswers(user.id, answers);
  return { ok: true };
}

async function getVisibleAnswers(username) {
  const user = await usersDb.findUserByUsername(username);
  if (!user) {
    const err = new Error("User not found");
    err.status = 404;
    err.publicMessage = "User not found";
    throw err;
  }

  return answersDb.findVisibleAnswersByUserId(user.id);
}

module.exports = {
  syncAnswers,
  getVisibleAnswers
};
