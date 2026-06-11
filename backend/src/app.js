const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const { corsOrigin } = require("./config/env");
const authRoutes = require("./routes/authRoutes");
const apiRoutes = require("./routes/apiRoutes");
const errorHandler = require("./middleware/errorHandler");

const app = express();

app.use(helmet());
app.use(cors({ origin: corsOrigin === "*" ? true : corsOrigin }));
app.use(express.json({ limit: "1mb" }));

app.get("/health", (req, res) => {
  res.json({ ok: true });
});

// Compatibility with the current iOS APIService base URL:
// https://host/api/daily_reflect
app.use("/api/daily_reflect", authRoutes);
app.use("/api/daily_reflect", apiRoutes);

app.use(authRoutes);
app.use(apiRoutes);
app.use(errorHandler);

module.exports = app;
