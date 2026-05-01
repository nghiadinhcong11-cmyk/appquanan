const express = require('express');
const { pool } = require('../db');
const { auth, permitSystemRoles } = require('../middleware/auth');
const { getOrCreateRestaurant, hasRestaurantRole } = require('./helpers');

const router = express.Router();

// Trang chủ mặc định - Đặt ở đây là đúng
router.get('/', (_req, res) => res.send('Backend của Quán Ăn đã sẵn sàng!'));

router.get('/health', (_req, res) => res.json({ ok: true }));

router.get('/bootstrap', async (_req, res) => {
  try {
    const accounts = await pool.query('SELECT username, display_name FROM users ORDER BY created_at DESC');
    const ownerApplications = await pool.query(`
      SELECT oa.id::text id, u.username, oa.restaurant_name, oa.proof, oa.status
      FROM owner_applications oa JOIN users u ON u.id = oa.user_id
      ORDER BY oa.created_at DESC`);
    const staffRoleRequests = await pool.query(`
      SELECT er.id::text id, u.username, r.name restaurant_name, er.requested_role, COALESCE(er.note,'') note, er.status
      FROM employee_requests er
      JOIN users u ON u.id = er.user_id
      JOIN restaurants r ON r.id = er.restaurant_id
      ORDER BY er.created_at DESC`);
    const roleAssignments = await pool.query(`
      SELECT u.username, r.name restaurant_name, ra.role
      FROM role_assignments ra
      JOIN users u ON u.id=ra.user_id
      JOIN restaurants r ON r.id=ra.restaurant_id`);

    res.json({
      accounts: accounts.rows.map(a => ({ username: a.username, password: '', displayName: a.display_name })),
      ownerApplications: ownerApplications.rows.map(o => ({ id: o.id, username: o.username, restaurantName: o.restaurant_name, proof: o.proof, status: o.status })),
      staffRoleRequests: staffRoleRequests.rows.map(r => ({ id: r.id, username: r.username, restaurantName: r.restaurant_name, requestedRole: r.requested_role, note: r.note, status: r.status })),
      roleAssignments: roleAssignments.rows.map(r => ({ username: r.username, restaurantName: r.restaurant_name, role: r.role })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/owner-applications', auth, async (req, res) => {
  try {
    const { restaurantName, proof } = req.body;
    const pending = await pool.query('SELECT id FROM owner_applications WHERE user_id=$1 AND status=$2', [req.user.sub, 'pending']);
    if (pending.rowCount) return res.status(409).json({ error: 'Bạn đã có yêu cầu chủ quán đang chờ duyệt' });
    const inserted = await pool.query('INSERT INTO owner_applications(user_id, restaurant_name, proof, status) VALUES($1,$2,$3,$4) RETURNING id::text id', [req.user.sub, restaurantName, proof, 'pending']);
    res.json({ id: inserted.rows[0].id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/owner-applications/:id/approve', auth, permitSystemRoles(['admin']), async (req, res) => {
  try {
    const q = await pool.query('SELECT user_id, restaurant_name FROM owner_applications WHERE id=$1', [req.params.id]);
    if (!q.rowCount) return res.status(404).json({ error: 'Not found' });
    const app = q.rows[0];
    const restaurant = await getOrCreateRestaurant(pool, app.restaurant_name);

    await pool.query('UPDATE owner_applications SET status=$1, reviewed_by=$2, reviewed_at=now() WHERE id=$3', ['approved', req.user.sub, req.params.id]);
    await pool.query(
      `INSERT INTO role_assignments(user_id, restaurant_id, role)
       VALUES($1,$2,$3)
       ON CONFLICT (user_id, restaurant_id) DO UPDATE SET role=EXCLUDED.role`,
      [app.user_id, restaurant.id, 'owner']
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/staff-requests', auth, async (req, res) => {
  try {
    const { restaurantName, requestedRole, note } = req.body;
    const restaurantQ = await pool.query('SELECT id FROM restaurants WHERE lower(name)=lower($1) LIMIT 1', [restaurantName]);
    if (!restaurantQ.rowCount) return res.status(404).json({ error: 'Cơ sở chưa tồn tại' });

    const restaurantId = restaurantQ.rows[0].id;
    const inserted = await pool.query(
      'INSERT INTO employee_requests(user_id, restaurant_id, requested_role, note, status) VALUES($1,$2,$3,$4,$5) RETURNING id::text id',
      [req.user.sub, restaurantId, requestedRole, note || '', 'pending']
    );
    res.json({ id: inserted.rows[0].id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/staff-requests/:id/approve', auth, async (req, res) => {
  try {
    const q = await pool.query('SELECT * FROM employee_requests WHERE id=$1', [req.params.id]);
    if (!q.rowCount) return res.status(404).json({ error: 'Request not found' });
    const r = q.rows[0];

    const allowed = req.user.systemRole === 'admin' || await hasRestaurantRole(pool, req.user.sub, r.restaurant_id, ['owner']);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    await pool.query('UPDATE employee_requests SET status=$1, reviewed_by=$2, reviewed_at=now() WHERE id=$3', ['approved', req.user.sub, req.params.id]);
    await pool.query(
      `INSERT INTO role_assignments(user_id, restaurant_id, role)
       VALUES($1,$2,$3)
       ON CONFLICT (user_id, restaurant_id) DO UPDATE SET role=EXCLUDED.role`,
      [r.user_id, r.restaurant_id, r.requested_role]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/menu', auth, async (req, res) => {
  try {
    const restaurantName = String(req.query.restaurantName || '');
    const rows = await pool.query(
      `SELECT m.id::text id, m.name, m.price, u.username created_by
       FROM menus m
       JOIN restaurants r ON r.id = m.restaurant_id
       JOIN users u ON u.id = m.created_by
       WHERE lower(r.name)=lower($1)
       ORDER BY m.created_at DESC`,
      [restaurantName]
    );
    res.json({ items: rows.rows.map(r => ({ id: r.id, name: r.name, price: Number(r.price), createdBy: r.created_by })) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/menu', auth, async (req, res) => {
  try {
    const { restaurantName, name, price } = req.body;
    const restaurantQ = await pool.query('SELECT id FROM restaurants WHERE lower(name)=lower($1) LIMIT 1', [restaurantName]);
    if (!restaurantQ.rowCount) return res.status(404).json({ error: 'Restaurant not found' });
    const restaurantId = restaurantQ.rows[0].id;

    const allowed = req.user.systemRole === 'admin' || await hasRestaurantRole(pool, req.user.sub, restaurantId, ['owner', 'manager']);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    await pool.query('INSERT INTO menus(restaurant_id, name, price, created_by) VALUES($1,$2,$3,$4)', [restaurantId, name, price, req.user.sub]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/bills', auth, async (req, res) => {
  try {
    const restaurantName = String(req.query.restaurantName || '');
    const rows = await pool.query(
      `SELECT o.id::text id, o.table_name, o.total, o.item_count, o.created_at
       FROM orders o JOIN restaurants r ON r.id=o.restaurant_id
       WHERE lower(r.name)=lower($1)
       ORDER BY o.created_at DESC`,
      [restaurantName]
    );
    res.json({ bills: rows.rows.map(b => ({ id: b.id, tableName: b.table_name, total: Number(b.total), itemCount: b.item_count, createdAt: b.created_at })) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/bills', auth, async (req, res) => {
  try {
    const { restaurantName, tableName, total, itemCount } = req.body;
    const restaurantQ = await pool.query('SELECT id FROM restaurants WHERE lower(name)=lower($1) LIMIT 1', [restaurantName]);
    if (!restaurantQ.rowCount) return res.status(404).json({ error: 'Restaurant not found' });
    const restaurantId = restaurantQ.rows[0].id;

    const allowed = req.user.systemRole === 'admin' || await hasRestaurantRole(pool, req.user.sub, restaurantId, ['owner', 'manager', 'staff']);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    await pool.query('INSERT INTO orders(restaurant_id, table_name, total, item_count, created_by) VALUES($1,$2,$3,$4,$5)', [restaurantId, tableName, total, itemCount, req.user.sub]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/stats/today', auth, async (req, res) => {
  try {
    const restaurantName = String(req.query.restaurantName || '');
    const rows = await pool.query(
      `SELECT COUNT(*)::int AS c, COALESCE(SUM(o.total),0)::numeric AS s
       FROM orders o JOIN restaurants r ON r.id=o.restaurant_id
       WHERE lower(r.name)=lower($1)
       AND o.created_at::date = CURRENT_DATE`,
      [restaurantName]
    );
    const row = rows.rows[0] || { c: 0, s: 0 };
    res.json({ billCount: row.c || 0, revenue: Number(row.s || 0) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
