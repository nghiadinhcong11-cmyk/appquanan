const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { pool } = require('../db');
const { auth } = require('../middleware/auth');

const router = express.Router();

function getSecrets() {
  const jwtSecret = process.env.JWT_SECRET;
  const refreshSecret = process.env.JWT_REFRESH_SECRET;
  if (!jwtSecret || !refreshSecret) {
    return null;
  }
  return { jwtSecret, refreshSecret };
}

function signAccess(user, secret) {
  return jwt.sign({ sub: user.id, username: user.username, systemRole: user.system_role }, secret, { expiresIn: '12h' });
}
function signRefresh(user, refreshSecret) {
  return jwt.sign({ sub: user.id, username: user.username }, refreshSecret, { expiresIn: '14d' });
}
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function ensureDeps(res) {
  if (!pool) {
    res.status(503).json({ error: 'Database is unavailable' });
    return null;
  }
  const secrets = getSecrets();
  if (!secrets) {
    res.status(500).json({ error: 'JWT env is not configured' });
    return null;
  }
  return secrets;
}

router.post('/register', async (req, res) => {
  const secrets = ensureDeps(res);
  if (!secrets) return;

  try {
    const { displayName, username, email, password } = req.body;
    const normalizedEmail = (email || username || '').trim().toLowerCase();
    if (!displayName || !normalizedEmail || !password) return res.status(400).json({ error: 'Missing fields' });

    const existed = await pool.query('SELECT id FROM users WHERE lower(username)=$1 OR lower(email)=$1', [normalizedEmail]);
    if (existed.rowCount) return res.status(409).json({ error: 'Email đã tồn tại' });

    const passwordHash = await bcrypt.hash(password, 10);
    const inserted = await pool.query(
      'INSERT INTO users(username, email, password_hash, display_name) VALUES($1,$2,$3,$4) RETURNING id::text, username, email, display_name, system_role',
      [normalizedEmail, normalizedEmail, passwordHash, displayName]
    );
    const user = inserted.rows[0];

    const accessToken = signAccess(user, secrets.jwtSecret);
    const refreshToken = signRefresh(user, secrets.refreshSecret);
    await pool.query(
      `INSERT INTO refresh_tokens(user_id, token_hash, expires_at)
       VALUES($1, $2, now() + interval '14 days')`,
      [user.id, hashToken(refreshToken)]
    );

    res.json({
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.display_name,
        systemRole: user.system_role
      },
      token: accessToken,
      refreshToken
    });
  } catch (e) {
    console.error('[auth/register] error:', e);
    res.status(500).json({ error: e.message });
  }
});

router.post('/login', async (req, res) => {
  const secrets = ensureDeps(res);
  if (!secrets) return;

  try {
    const { username, email, password } = req.body;
    const identity = (email || username || '').trim().toLowerCase();
    const q = await pool.query(
      'SELECT id::text, username, email, display_name, password_hash, system_role FROM users WHERE lower(username)=$1 OR lower(email)=$1',
      [identity],
    );
    if (!q.rowCount) return res.status(401).json({ error: 'Sai email hoặc mật khẩu' });

    const user = q.rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Sai email hoặc mật khẩu' });

    const accessToken = signAccess(user, secrets.jwtSecret);
    const refreshToken = signRefresh(user, secrets.refreshSecret);
    await pool.query(
      `INSERT INTO refresh_tokens(user_id, token_hash, expires_at)
       VALUES($1, $2, now() + interval '14 days')`,
      [user.id, hashToken(refreshToken)]
    );

    res.json({
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.display_name,
        systemRole: user.system_role
      },
      token: accessToken,
      refreshToken
    });
  } catch (e) {
    console.error('[auth/login] error:', e);
    res.status(500).json({ error: e.message });
  }
});

router.post('/refresh', async (req, res) => {
  const secrets = ensureDeps(res);
  if (!secrets) return;

  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'Missing refresh token' });

    const payload = jwt.verify(refreshToken, secrets.refreshSecret);
    const tokenHash = hashToken(refreshToken);

    const tokenRow = await pool.query(
      'SELECT id, user_id FROM refresh_tokens WHERE token_hash=$1 AND revoked_at IS NULL AND expires_at > now() LIMIT 1',
      [tokenHash]
    );
    if (!tokenRow.rowCount) return res.status(401).json({ error: 'Invalid refresh token' });

    const userQ = await pool.query('SELECT id::text, username, email, display_name, system_role FROM users WHERE id=$1', [payload.sub]);
    if (!userQ.rowCount) return res.status(401).json({ error: 'User not found' });

    const user = userQ.rows[0];
    const accessToken = signAccess(user, secrets.jwtSecret);
    res.json({
      token: accessToken,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.display_name,
        systemRole: user.system_role
      }
    });
  } catch (_e) {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});

router.get('/me', auth, async (req, res) => {
  try {
    const q = await pool.query(
      'SELECT id::text, username, email, display_name as "displayName", system_role as "systemRole" FROM users WHERE id=$1',
      [req.user.sub]
    );
    if (!q.rowCount) return res.status(404).json({ error: 'User not found' });
    res.json(q.rows[0]);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/logout', auth, async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });

  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await pool.query('UPDATE refresh_tokens SET revoked_at=now() WHERE token_hash=$1', [hashToken(refreshToken)]);
    }
    res.json({ ok: true });
  } catch (e) {
    console.error('[auth/logout] error:', e);
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
