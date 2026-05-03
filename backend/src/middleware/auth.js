const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const { hasRestaurantRole } = require('../routes/helpers');

function getJwtSecret() {
  return process.env.JWT_SECRET;
}

function auth(req, res, next) {
  const secret = getJwtSecret();

  if (!secret) {
    console.error('[AUTH ERROR] JWT_SECRET is missing! Check Render Dashboard Environment Variables.');
    return res.status(500).json({ error: 'Cấu hình Server lỗi (Thiếu Secret)' });
  }

  const authHeader = req.headers.authorization || '';

  // Sửa lỗi Case-sensitive: Chấp nhận cả 'Bearer' và 'bearer'
  let token = null;
  if (authHeader.toLowerCase().startsWith('bearer ')) {
    token = authHeader.slice(7);
  }

  if (!token) {
    // Log IP để biết ai đang gọi
    console.warn(`[AUTH WARN] No token provided for ${req.method} ${req.url} from ${req.ip}`);
    return res.status(401).json({ error: 'Unauthorized: No token provided' });
  }

  try {
    const decoded = jwt.verify(token, secret);
    req.user = decoded;
    next();
  } catch (err) {
    console.error(`[AUTH ERROR] Token verification failed: ${err.message}. Token might be from different environment.`);
    return res.status(401).json({ error: 'Unauthorized: Invalid or expired token' });
  }
}

function permitSystemRoles(roles = []) {
  return (req, res, next) => {
    if (!roles.length) return next();
    if (!req.user) return res.status(401).json({ error: 'Unauthorized: User not identified' });

    if (!roles.includes(req.user.systemRole)) {
      return res.status(403).json({ error: 'Forbidden: No system permission' });
    }
    next();
  };
}

function permitRestaurantRoles(allowedRoles = []) {
  return async (req, res, next) => {
    const restaurantId = req.headers['x-restaurant-id'] || req.body.restaurantId || req.query.restaurantId;

    if (restaurantId) {
      req.restaurantId = restaurantId.toString();
    }

    if (req.user && req.user.systemRole === 'admin') return next();

    if (!req.restaurantId) {
       return res.status(400).json({ error: 'Missing restaurant context (x-restaurant-id header)' });
    }

    try {
      const hasRole = await hasRestaurantRole(pool, req.user.sub, req.restaurantId, allowedRoles);
      if (!hasRole) {
        return res.status(403).json({ error: 'Forbidden: No permission for this restaurant' });
      }
      next();
    } catch (err) {
      res.status(500).json({ error: 'Authorization check failed' });
    }
  };
}

module.exports = { auth, permitSystemRoles, permitRestaurantRoles };
