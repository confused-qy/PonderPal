const { Pool } = require("pg");
const { databaseUrl } = require("../config/env");

const pool = new Pool({
  connectionString: databaseUrl,
  ssl: process.env.NODE_ENV === "production"
    ? { rejectUnauthorized: false }
    : false
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  pool
};
