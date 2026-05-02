const express = require('express');
const { pool } = require('../db');
const { auth, permitRestaurantRoles } = require('../middleware/auth');
const { requireRestaurantContext } = require('../middleware/restaurant-context');

const router = express.Router();

const MENU_VIEW_ROLES = ['owner', 'manager', 'waiter', 'cashier', 'kitchen'];
const MENU_MANAGE_ROLES = ['owner', 'manager'];

router.use(auth);
router.use(requireRestaurantContext);

router.get('/menu', permitRestaurantRoles(MENU_VIEW_ROLES), async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });

  try {
    const keyword = (req.query.keyword || '').toString().trim().toLowerCase();
    const params = [req.restaurantId];
    let whereKeyword = '';
    if (keyword) {
      params.push(`%${keyword}%`);
      whereKeyword = ` AND lower(m.name) LIKE $${params.length}`;
    }

    const rows = await pool.query(
      `SELECT m.id::text id, m.name, m.price, COALESCE(m.description, '') description,
              COALESCE(m.image_url, '') image_url, COALESCE(u.username, 'system') created_by
       FROM menus m
       LEFT JOIN users u ON u.id = m.created_by
       WHERE m.restaurant_id = $1
       ${whereKeyword}
       ORDER BY m.created_at DESC`,
      params,
    );

    res.json({
      items: rows.rows.map((r) => ({
        id: r.id,
        name: r.name,
        price: Number(r.price),
        description: r.description,
        imageUrl: r.image_url,
        createdBy: r.created_by,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/menu', permitRestaurantRoles(MENU_MANAGE_ROLES), async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });
  try {
    const { name, price, description, imageUrl } = req.body;
    if (!name || price == null) {
      return res.status(400).json({ error: 'Missing fields' });
    }

    const inserted = await pool.query(
      `INSERT INTO menus(restaurant_id, name, price, description, image_url, created_by)
       VALUES($1,$2,$3,$4,$5,$6)
       RETURNING id::text`,
      [req.restaurantId, name, price, description || '', imageUrl || '', req.user.sub],
    );

    res.status(201).json({ id: inserted.rows[0].id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.put('/menu/:id', permitRestaurantRoles(MENU_MANAGE_ROLES), async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });
  try {
    const { name, price, description, imageUrl } = req.body;
    const updated = await pool.query(
      `UPDATE menus
       SET name = COALESCE($1, name),
           price = COALESCE($2, price),
           description = COALESCE($3, description),
           image_url = COALESCE($4, image_url)
       WHERE id = $5 AND restaurant_id = $6`,
      [name, price, description, imageUrl, req.params.id, req.restaurantId],
    );

    if (updated.rowCount === 0) return res.status(404).json({ error: 'Menu item not found' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.delete('/menu/:id', permitRestaurantRoles(MENU_MANAGE_ROLES), async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });
  try {
    const deleted = await pool.query('DELETE FROM menus WHERE id = $1 AND restaurant_id = $2', [req.params.id, req.restaurantId]);
    if (deleted.rowCount === 0) return res.status(404).json({ error: 'Menu item not found' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/tables', permitRestaurantRoles(MENU_VIEW_ROLES), async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });
  try {
    const rows = await pool.query(
      `SELECT id::text, name, floor, status
       FROM tables WHERE restaurant_id = $1
       ORDER BY floor ASC, name ASC`,
      [req.restaurantId],
    );
    res.json({ tables: rows.rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/tables', permitRestaurantRoles(MENU_MANAGE_ROLES), async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });
  try {
    const { name, floor = 1 } = req.body;
    if (!name) return res.status(400).json({ error: 'Missing table name' });

    const upserted = await pool.query(
      `INSERT INTO tables(restaurant_id, name, floor, status)
       VALUES($1, $2, $3, 'empty')
       ON CONFLICT (restaurant_id, name)
       DO UPDATE SET floor = EXCLUDED.floor
       RETURNING id::text`,
      [req.restaurantId, name, floor],
    );
    res.status(201).json({ id: upserted.rows[0].id });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
