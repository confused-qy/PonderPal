const db = require("./pool");

async function upsertAnswers(userId, answers) {
  const entries = Object.entries(answers || {});

  for (const [questionId, answer] of entries) {
    if (!answer || typeof answer.content !== "string") {
      continue;
    }

    await db.query(
      `INSERT INTO answers (user_id, question_id, content, visible, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (user_id, question_id)
       DO UPDATE SET
         content = EXCLUDED.content,
         visible = EXCLUDED.visible,
         updated_at = NOW()`,
      [userId, questionId, answer.content, answer.visible !== false]
    );
  }
}

async function findVisibleAnswersByUserId(userId) {
  const result = await db.query(
    `SELECT question_id, content
     FROM answers
     WHERE user_id = $1 AND visible = TRUE
     ORDER BY updated_at DESC`,
    [userId]
  );

  return result.rows.reduce((acc, row) => {
    acc[row.question_id] = { content: row.content };
    return acc;
  }, {});
}

module.exports = {
  upsertAnswers,
  findVisibleAnswersByUserId
};
