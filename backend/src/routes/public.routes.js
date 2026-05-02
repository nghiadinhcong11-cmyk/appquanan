const express = require('express');
const { pool } = require('../db');

const router = express.Router();

router.get('/restaurants', async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });

  try {
    const search = (req.query.search || '').toString().trim().toLowerCase();
    const params = [];
    let where = '';
    if (search) {
      params.push(`%${search}%`);
      where = `WHERE lower(name) LIKE $${params.length}`;
    }

    const rows = await pool.query(
      `SELECT id::text, name, created_at
       FROM restaurants
       ${where}
       ORDER BY name ASC
       LIMIT 50`,
      params,
    );

    res.json({ restaurants: rows.rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/menu', async (req, res) => {
  if (!pool) return res.status(503).json({ error: 'Database is unavailable' });

  try {
    const restaurantId = req.query.restaurantId?.toString();
    if (!restaurantId) {
      return res.status(400).json({ error: 'Missing restaurantId' });
    }

    const keyword = (req.query.keyword || '').toString().trim().toLowerCase();
    const params = [restaurantId];
    let keywordClause = '';
    if (keyword) {
      params.push(`%${keyword}%`);
      keywordClause = ` AND lower(m.name) LIKE $${params.length}`;
    }

    const rows = await pool.query(
      `SELECT m.id::text id, m.name, m.price, COALESCE(m.description, '') description,
              COALESCE(m.image_url, '') image_url
       FROM menus m
       WHERE m.restaurant_id = $1
       ${keywordClause}
       ORDER BY m.name ASC`,
      params,
    );

    res.json({
      items: rows.rows.map((r) => ({
        id: r.id,
        name: r.name,
        price: Number(r.price),
        description: r.description,
        imageUrl: r.image_url,
        createdBy: 'public',
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
