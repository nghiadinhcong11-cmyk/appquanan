const jwt = require('jsonwebtoken');

function getJwtSecret() {
  return process.env.JWT_SECRET;
}

function auth(req, res, next) {
  const secret = getJwtSecret();
  if (!secret) return res.status(500).json({ error: 'Server auth is not configured' });

  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
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

module.exports = { auth, permitSystemRoles };
