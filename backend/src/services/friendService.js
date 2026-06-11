const usersDb = require("../db/users");
const answersDb = require("../db/answers");
const friendshipsDb = require("../db/friendships");

function assertSameUser(reqUser, username) {
  if (reqUser.username !== username) {
    const err = new Error("Token user does not match request username");
    err.status = 403;
    err.publicMessage = "Forbidden";
    throw err;
  }
}

async function getFriends(reqUser, username) {
  assertSameUser(reqUser, username);

  const user = await usersDb.findUserByUsername(username);
  if (!user) {
    const err = new Error("User not found");
    err.status = 404;
    err.publicMessage = "User not found";
    throw err;
  }

  return friendshipsDb.findFriendUsernames(user.id);
}

async function linkFriend(reqUser, me, friend) {
  assertSameUser(reqUser, me);

  if (me === friend) {
    const err = new Error("Cannot add yourself as a friend");
    err.status = 400;
    err.publicMessage = "Cannot add yourself as a friend";
    throw err;
  }

  const meUser = await usersDb.findUserByUsername(me);
  const friendUser = await usersDb.findUserByUsername(friend);

  if (!meUser || !friendUser) {
    const err = new Error("Both users must exist");
    err.status = 404;
    err.publicMessage = "Both users must exist";
    throw err;
  }

  await friendshipsDb.createFriendship(meUser.id, friendUser.id);
  return answersDb.findVisibleAnswersByUserId(friendUser.id);
}

module.exports = {
  getFriends,
  linkFriend
};
