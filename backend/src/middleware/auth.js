const jwt = require("jsonwebtoken");
const { jwtSecret } = require("../config/env");

function requireAuth(req, res, next) {
  const header = req.get("Authorization") || "";
  const [scheme, token] = header.split(" ");

  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ error: "Missing bearer token" });
  }

  try {
    req.user = jwt.verify(token, jwtSecret);
    return next();
  } catch {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
}

module.exports = requireAuth;
