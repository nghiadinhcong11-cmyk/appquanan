const express = require('express');
const { pool } = require('../db');
const { auth, permitSystemRoles, permitRestaurantRoles } = require('../middleware/auth');
const { getOrCreateRestaurant, hasRestaurantRole } = require('./helpers');

const router = express.Router();

// Trang chủ mặc định - Đặt ở đây là đúng
// router.get('/', (_req, res) => res.send('Backend của Quán Ăn đã sẵn sàng!'));

router.get('/health', (_req, res) => res.json({ ok: true }));

router.get('/bootstrap', auth, permitSystemRoles(['admin']), async (_req, res) => {
  try {
    const accounts = await pool.query('SELECT id::text, username, email, display_name, system_role FROM users ORDER BY created_at DESC');
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
      SELECT u.username, r.id::text restaurant_id, r.name restaurant_name, ra.role
      FROM role_assignments ra
      JOIN users u ON u.id=ra.user_id
      JOIN restaurants r ON r.id=ra.restaurant_id`);

    res.json({
      accounts: accounts.rows.map(a => ({
        id: a.id,
        username: a.username,
        email: a.email || a.username,
        password: '',
        displayName: a.display_name,
        systemRole: a.system_role
      })),
      ownerApplications: ownerApplications.rows.map(o => ({ id: o.id, username: o.username, restaurantName: o.restaurant_name, proof: o.proof, status: o.status })),
      staffRoleRequests: staffRoleRequests.rows.map(r => ({ id: r.id, username: r.username, restaurantName: r.restaurant_name, requestedRole: r.requested_role, note: r.note, status: r.status })),
      roleAssignments: roleAssignments.rows.map(r => ({
        username: r.username,
        restaurantId: r.restaurant_id,
        restaurantName: r.restaurant_name,
        role: r.role
      })),
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

router.get('/users', auth, permitSystemRoles(['admin']), async (_req, res) => {
  try {
    const rows = await pool.query(
      'SELECT id::text, username, COALESCE(email, username) as email, display_name, system_role, created_at FROM users ORDER BY created_at DESC',
    );
    res.json({
      users: rows.rows.map((u) => ({
        id: u.id,
        username: u.username,
        email: u.email,
        displayName: u.display_name,
        systemRole: u.system_role,
        createdAt: u.created_at,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/users/me', auth, async (req, res) => {
  try {
    const { displayName, password } = req.body;
    if (!displayName && !password) return res.status(400).json({ error: 'No changes provided' });
    const params = [];
    const sets = [];
    if (displayName) {
      params.push(displayName);
      sets.push(`display_name = $${params.length}`);
    }
    if (password) {
      const bcrypt = require('bcryptjs');
      const hash = await bcrypt.hash(password, 10);
      params.push(hash);
      sets.push(`password_hash = $${params.length}`);
    }
    params.push(req.user.sub);
    const updated = await pool.query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $${params.length}
       RETURNING id::text, username, COALESCE(email, username) as email, display_name, system_role`,
      params,
    );
    res.json({
      user: {
        id: updated.rows[0].id,
        username: updated.rows[0].username,
        email: updated.rows[0].email,
        displayName: updated.rows[0].display_name,
        systemRole: updated.rows[0].system_role,
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/users/me', auth, async (req, res) => {
  try {
    await pool.query('DELETE FROM users WHERE id = $1', [req.user.sub]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/users/:id', auth, permitSystemRoles(['admin']), async (req, res) => {
  try {
    const { displayName, systemRole } = req.body;
    if (!displayName && !systemRole) return res.status(400).json({ error: 'No changes provided' });
    const params = [];
    const sets = [];
    if (displayName) {
      params.push(displayName);
      sets.push(`display_name = $${params.length}`);
    }
    if (systemRole) {
      params.push(systemRole);
      sets.push(`system_role = $${params.length}`);
    }
    params.push(req.params.id);
    const updated = await pool.query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $${params.length}
       RETURNING id::text, username, COALESCE(email, username) as email, display_name, system_role`,
      params,
    );
    if (!updated.rowCount) return res.status(404).json({ error: 'User not found' });
    res.json({
      user: {
        id: updated.rows[0].id,
        username: updated.rows[0].username,
        email: updated.rows[0].email,
        displayName: updated.rows[0].display_name,
        systemRole: updated.rows[0].system_role,
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/users/:id', auth, permitSystemRoles(['admin']), async (req, res) => {
  try {
    if (String(req.user.sub) === String(req.params.id)) return res.status(400).json({ error: 'Cannot delete yourself here' });
    const deleted = await pool.query('DELETE FROM users WHERE id = $1', [req.params.id]);
    if (!deleted.rowCount) return res.status(404).json({ error: 'User not found' });
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

    const allowed = req.user.systemRole === 'admin' || await hasRestaurantRole(pool, req.user.sub, r.restaurant_id, ['owner', 'manager']);
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

router.post('/staff-requests/:id/reject', auth, async (req, res) => {
  try {
    const q = await pool.query('SELECT * FROM employee_requests WHERE id=$1', [req.params.id]);
    if (!q.rowCount) return res.status(404).json({ error: 'Request not found' });
    const r = q.rows[0];

    const allowed = req.user.systemRole === 'admin' || await hasRestaurantRole(pool, req.user.sub, r.restaurant_id, ['owner', 'manager']);
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    await pool.query('UPDATE employee_requests SET status=$1, reviewed_by=$2, reviewed_at=now() WHERE id=$3', ['rejected', req.user.sub, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/menu', auth, permitRestaurantRoles(['owner', 'manager', 'waiter', 'cashier', 'kitchen']), async (req, res) => {
  try {
    const restaurantId = req.restaurantId;

    const rows = await pool.query(
      `SELECT m.id::text id, m.name, m.price, m.description, m.image_url, u.username created_by
       FROM menus m
       LEFT JOIN users u ON u.id = m.created_by
       WHERE m.restaurant_id = $1
       ORDER BY m.created_at DESC`,
      [restaurantId]
    );
    res.json({ items: rows.rows.map(r => ({
      id: r.id,
      name: r.name,
      price: Number(r.price),
      description: r.description || '',
      imageUrl: r.image_url || '',
      createdBy: r.created_by || 'system'
    })) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/menu', auth, permitRestaurantRoles(['owner', 'manager']), async (req, res) => {
  try {
    const { name, price, description, imageUrl } = req.body;
    const restaurantId = req.restaurantId;

    if (!name || price == null) {
      return res.status(400).json({ error: 'Tên và giá món ăn là bắt buộc' });
    }

    const result = await pool.query(
      'INSERT INTO menus(restaurant_id, name, price, description, image_url, created_by) VALUES($1,$2,$3,$4,$5,$6) RETURNING id::text',
      [restaurantId, name, price, description || '', imageUrl || '', req.user.sub]
    );
    res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/bills', auth, permitRestaurantRoles(['owner', 'manager', 'cashier']), async (req, res) => {
  try {
    const restaurantId = req.restaurantId;

    const rows = await pool.query(
      `SELECT o.id::text id, o.table_name, o.total, o.item_count, o.created_at
       FROM orders o
       WHERE o.restaurant_id = $1
       ORDER BY o.created_at DESC`,
      [restaurantId]
    );
    res.json({ bills: rows.rows.map(b => ({ id: b.id, tableName: b.table_name, total: Number(b.total), itemCount: b.item_count, createdAt: b.created_at })) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/bills/:id/items', auth, permitRestaurantRoles(['owner', 'manager', 'cashier', 'waiter']), async (req, res) => {
  try {
    const rows = await pool.query(
      `SELECT m.name as item_name, oi.quantity, m.price, (m.price * oi.quantity) as subtotal
       FROM order_items oi
       JOIN menus m ON m.id = oi.menu_item_id
       WHERE oi.bill_id = $1`,
      [req.params.id]
    );
    res.json({ items: rows.rows.map(r => ({
      name: r.item_name,
      qty: r.quantity,
      price: Number(r.price),
      total: Number(r.subtotal)
    })) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/bills', auth, permitRestaurantRoles(['owner', 'manager', 'cashier', 'waiter']), async (req, res) => {
  const client = await pool.connect();
  try {
    const { tableName, total, itemCount, tableId } = req.body;
    const restaurantId = req.restaurantId;

    await client.query('BEGIN');

    const result = await client.query(
      'INSERT INTO orders(restaurant_id, table_name, total, item_count, created_by) VALUES($1,$2,$3,$4,$5) RETURNING id',
      [restaurantId, tableName, total, itemCount, req.user.sub]
    );
    const billId = result.rows[0].id;

    if (tableId) {
      // Gắn bill_id vào các order_items của bàn này mà chưa có bill và cập nhật trạng thái
      await client.query(
        "UPDATE order_items SET bill_id = $1, status = 'billed' WHERE table_id = $2 AND bill_id IS NULL AND restaurant_id = $3",
        [billId, tableId, restaurantId]
      );
      // Chuyển trạng thái bàn về 'empty' sau khi thanh toán
      await client.query(
        "UPDATE tables SET status = 'empty' WHERE id = $1 AND restaurant_id = $2",
        [tableId, restaurantId]
      );
    }

    await client.query('COMMIT');
    res.json({ ok: true, id: billId });
  } catch (e) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: e.message });
  } finally {
    client.release();
  }
});

router.get('/stats/today', auth, permitRestaurantRoles(['owner', 'manager']), async (req, res) => {
  try {
    const restaurantId = req.restaurantId;

    const statsResult = await pool.query(
      `SELECT COUNT(*)::int AS c, COALESCE(SUM(o.total),0)::numeric AS s
       FROM orders o
       WHERE o.restaurant_id = $1
       AND o.created_at::date = CURRENT_DATE`,
      [restaurantId]
    );

    const hourlyResult = await pool.query(
      `SELECT EXTRACT(HOUR FROM o.created_at) as hour, SUM(o.total) as total
       FROM orders o
       WHERE o.restaurant_id = $1
       AND o.created_at::date = CURRENT_DATE
       GROUP BY hour
       ORDER BY hour ASC`,
      [restaurantId]
    );

    const popularResult = await pool.query(
      `SELECT m.name, SUM(oi.quantity)::int as total_qty
       FROM order_items oi
       JOIN menus m ON m.id = oi.menu_item_id
       WHERE oi.restaurant_id = $1
       AND oi.status != 'cancelled'
       AND oi.created_at::date = CURRENT_DATE
       GROUP BY m.name
       ORDER BY total_qty DESC
       LIMIT 5`,
      [restaurantId]
    );

    const row = statsResult.rows[0] || { c: 0, s: 0 };
    res.json({
      billCount: row.c || 0,
      revenue: Number(row.s || 0),
      hourlyRevenue: hourlyResult.rows.map(r => ({
        hour: Number(r.hour),
        total: Number(r.total)
      })),
      popularItems: popularResult.rows.map(r => ({
        name: r.name,
        quantity: r.total_qty
      }))
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Staff Management Routes
router.get('/restaurants/staff', auth, permitRestaurantRoles(['owner', 'manager']), async (req, res) => {
  try {
    const restaurantId = req.restaurantId;
    const rows = await pool.query(
      `SELECT u.id::text, u.username, u.display_name, ra.role
       FROM role_assignments ra
       JOIN users u ON u.id = ra.user_id
       WHERE ra.restaurant_id = $1`,
      [restaurantId]
    );
    res.json({ staff: rows.rows.map(r => ({
      id: r.id,
      username: r.username,
      displayName: r.display_name,
      currentRestaurantRole: r.role
    })) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/restaurants/staff/update-role', auth, permitRestaurantRoles(['owner']), async (req, res) => {
  try {
    const { userId, role } = req.body;
    const restaurantId = req.restaurantId;
    await pool.query(
      `UPDATE role_assignments SET role = $1
       WHERE restaurant_id = $2 AND user_id = $3`,
      [role, restaurantId, userId]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/restaurants/staff', auth, permitRestaurantRoles(['owner']), async (req, res) => {
  try {
    const { userId } = req.query;
    const restaurantId = req.restaurantId;
    await pool.query(
      `DELETE FROM role_assignments WHERE restaurant_id = $1 AND user_id = $2`,
      [restaurantId, userId]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Table Management Routes
router.get('/restaurants/tables', auth, permitRestaurantRoles(['owner', 'manager', 'waiter', 'cashier', 'kitchen']), async (req, res) => {
  try {
    const restaurantId = req.restaurantId;
    const rows = await pool.query(
      'SELECT id::text, name, status, COALESCE(floor, 1) as floor, COALESCE(is_temporary, false) as "isTemporary" FROM tables WHERE restaurant_id = $1 ORDER BY floor ASC, name ASC',
      [restaurantId]
    );
    res.json({ tables: rows.rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/restaurants/tables', auth, permitRestaurantRoles(['owner', 'manager']), async (req, res) => {
  try {
    const { name, floor, isTemporary } = req.body;
    const restaurantId = req.restaurantId;

    if (!name) {
      return res.status(400).json({ error: 'Tên bàn là bắt buộc' });
    }

    const result = await pool.query(
      'INSERT INTO tables(restaurant_id, name, floor, is_temporary) VALUES($1, $2, $3, $4) ON CONFLICT (restaurant_id, name) DO UPDATE SET floor = EXCLUDED.floor, is_temporary = EXCLUDED.is_temporary RETURNING id::text',
      [restaurantId, name, Number.isFinite(Number(floor)) ? Number(floor) : 1, isTemporary || false]
    );
    res.json({ ok: true, id: result.rows[0].id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/restaurants/tables/:id/status', auth, permitRestaurantRoles(['owner', 'manager', 'waiter', 'cashier']), async (req, res) => {
  try {
    const { status } = req.body;
    const result = await pool.query('UPDATE tables SET status = $1 WHERE id = $2 AND restaurant_id = $3', [status, req.params.id, req.restaurantId]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Table not found in this restaurant' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Orders & Kitchen Management
router.get('/restaurants/order-items', auth, permitRestaurantRoles(['owner', 'manager', 'waiter', 'kitchen', 'cashier']), async (req, res) => {
  try {
    const { status, tableId } = req.query;
    const restaurantId = req.restaurantId;
    let query = `
      SELECT oi.id::text, oi.table_id::text, t.name as table_name, oi.menu_item_id::text, m.name as item_name,
             oi.quantity, oi.note, oi.status, oi.created_at, m.price
      FROM order_items oi
      LEFT JOIN tables t ON t.id = oi.table_id
      LEFT JOIN menus m ON m.id = oi.menu_item_id
      WHERE oi.restaurant_id = $1
    `;
    const params = [restaurantId];
    if (status) {
      query += ' AND oi.status = $' + (params.length + 1);
      params.push(status);
    }
    if (tableId) {
      query += ' AND oi.table_id = $' + (params.length + 1);
      params.push(tableId);
    }
    // Only show items that haven't been billed yet unless specifically requested?
    // Usually for active table view, we want unbilled items.
    if (!req.query.includeBilled || req.query.includeBilled === 'false') {
      query += ' AND oi.bill_id IS NULL';
    }

    query += ' ORDER BY oi.created_at ASC';

    const rows = await pool.query(query, params);
    res.json({ items: rows.rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/restaurants/order-items', auth, permitRestaurantRoles(['owner', 'manager', 'waiter']), async (req, res) => {
  const client = await pool.connect();
  try {
    const { tableId, menuItemId, quantity, note } = req.body;
    const restaurantId = req.restaurantId;

    await client.query('BEGIN');

    const result = await client.query(
      `INSERT INTO order_items
       (restaurant_id, table_id, menu_item_id, quantity, note, created_by, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')
       RETURNING id::text`,
      [restaurantId, tableId, menuItemId, quantity, note || '', req.user.sub]
    );

    if (tableId) {
      await client.query(
        `UPDATE tables
         SET status = 'serving'
         WHERE id = $1
         AND restaurant_id = $2
         AND status = 'empty'`,
        [tableId, restaurantId]
      );
    }

    await client.query('COMMIT');
    res.json({ id: result.rows[0].id });
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('Order Item Error:', e);
    res.status(500).json({ error: e.message });
  } finally {
    client.release();
  }
});

router.patch('/restaurants/order-items/:id/status', auth, permitRestaurantRoles(['owner', 'manager', 'kitchen', 'waiter']), async (req, res) => {
  try {
    const { status } = req.body;
    const result = await pool.query('UPDATE order_items SET status = $1 WHERE id = $2 AND restaurant_id = $3', [status, req.params.id, req.restaurantId]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Order item not found in this restaurant' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
