const db = require("./pool");

function orderedPair(userA, userB) {
  return userA < userB ? [userA, userB] : [userB, userA];
}

async function createFriendship(userIdA, userIdB) {
  const [userA, userB] = orderedPair(userIdA, userIdB);

  await db.query(
    `INSERT INTO friendships (user_a, user_b)
     VALUES ($1, $2)
     ON CONFLICT (user_a, user_b) DO NOTHING`,
    [userA, userB]
  );
}

async function findFriendUsernames(userId) {
  const result = await db.query(
    `SELECT u.username
     FROM friendships f
     JOIN users u
       ON u.id = CASE
         WHEN f.user_a = $1 THEN f.user_b
         ELSE f.user_a
       END
     WHERE f.user_a = $1 OR f.user_b = $1
     ORDER BY u.username ASC`,
    [userId]
  );

  return result.rows.map((row) => row.username);
}

module.exports = {
  createFriendship,
  findFriendUsernames
};
