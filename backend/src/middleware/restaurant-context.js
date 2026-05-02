const { pool } = require('../db');

async function requireRestaurantContext(req, res, next) {
  const restaurantId = req.headers['x-restaurant-id'];
  if (!restaurantId) {
    return res.status(400).json({ error: 'Missing restaurant context' });
  }

  if (!pool) {
    return res.status(503).json({ error: 'Database is unavailable' });
  }

  req.restaurantId = restaurantId.toString();
  next();
}

module.exports = { requireRestaurantContext };
