const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { jwtSecret, jwtExpiresIn } = require("../config/env");
const usersDb = require("../db/users");

const SALT_ROUNDS = 12;

function normalizeUsername(username) {
  return String(username || "").trim();
}

function validateCredentials(username, password) {
  if (!normalizeUsername(username) || !String(password || "").trim()) {
    const err = new Error("Username and password are required");
    err.status = 400;
    err.publicMessage = "Username and password are required";
    throw err;
  }
}

function signToken(user) {
  return jwt.sign(
    { sub: user.id, username: user.username },
    jwtSecret,
    { expiresIn: jwtExpiresIn }
  );
}

async function register(username, password) {
  validateCredentials(username, password);
  const normalized = normalizeUsername(username);

  const existing = await usersDb.findUserByUsername(normalized);
  if (existing) {
    const err = new Error("Username already exists");
    err.status = 409;
    err.publicMessage = "Username already exists";
    throw err;
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await usersDb.createUser(normalized, passwordHash);
  return { user };
}

async function login(username, password) {
  validateCredentials(username, password);
  const normalized = normalizeUsername(username);

  const user = await usersDb.findUserByUsername(normalized);
  if (!user) {
    const err = new Error("Invalid username or password");
    err.status = 401;
    err.publicMessage = "Invalid username or password";
    throw err;
  }

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) {
    const err = new Error("Invalid username or password");
    err.status = 401;
    err.publicMessage = "Invalid username or password";
    throw err;
  }

  return {
    token: signToken(user),
    user: {
      id: user.id,
      username: user.username
    }
  };
}

module.exports = {
  register,
  login
};
