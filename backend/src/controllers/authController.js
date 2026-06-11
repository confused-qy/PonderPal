const authService = require("../services/authService");

async function register(req, res, next) {
  try {
    const result = await authService.register(req.body.username, req.body.password);
    return res.status(201).json({ ok: true, user: result.user });
  } catch (err) {
    return next(err);
  }
}

async function login(req, res, next) {
  try {
    const result = await authService.login(req.body.username, req.body.password);
    return res.json(result);
  } catch (err) {
    return next(err);
  }
}

module.exports = {
  register,
  login
};
