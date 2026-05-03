const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const { hasRestaurantRole } = require('../routes/helpers');

function getJwtSecret() {
  return process.env.JWT_SECRET;
}

function auth(req, res, next) {
  const secret = getJwtSecret();
  if (!secret) return res.status(500).json({ error: 'Server auth is not configured' });

  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  // LOG FOR TESTING PERMISSIONS
  // console.log(`Auth check for ${req.method} ${req.url}`);

  if (!token) return res.status(401).json({ error: 'Unauthorized' });

  try {
    req.user = jwt.verify(token, secret);
    next();
  } catch (_e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function permitSystemRoles(roles = []) {
  return (req, res, next) => {
    if (!roles.length) return next();
    if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
    if (!roles.includes(req.user.systemRole)) return res.status(403).json({ error: 'Forbidden' });
    next();
  };
}

/**
 * Middleware to check restaurant-specific roles.
 * Requires restaurantId to be present in headers (x-restaurant-id) or req.body/req.query
 */
function permitRestaurantRoles(allowedRoles = []) {
  return async (req, res, next) => {
    const restaurantId = req.headers['x-restaurant-id'] || req.body.restaurantId || req.query.restaurantId;
    if (restaurantId) {
      req.restaurantId = restaurantId.toString();
    }

    if (req.user && req.user.systemRole === 'admin') return next();

    if (!req.restaurantId) {
       return res.status(400).json({ error: 'Missing restaurant context' });
    }

    try {
      const hasRole = await hasRestaurantRole(pool, req.user.sub, req.restaurantId, allowedRoles);
      if (!hasRole) {
        return res.status(403).json({ error: 'Insufficient permissions for this restaurant' });
      }
      next();
    } catch (err) {
      res.status(500).json({ error: 'Authorization check failed' });
    }
  };
}

module.exports = { auth, permitSystemRoles, permitRestaurantRoles };
