function errorHandler(err, req, res, next) {
  if (res.headersSent) {
    return next(err);
  }

  console.error(err);
  return res.status(err.status || 500).json({
    error: err.publicMessage || "Internal server error"
  });
}

module.exports = errorHandler;
