async function getOrCreateRestaurant(pool, restaurantName) {
  const existing = await pool.query('SELECT id, name FROM restaurants WHERE lower(name)=lower($1) LIMIT 1', [restaurantName]);
  if (existing.rowCount) return existing.rows[0];
  const inserted = await pool.query('INSERT INTO restaurants(name) VALUES($1) RETURNING id, name', [restaurantName]);
  return inserted.rows[0];
}

async function hasRestaurantRole(pool, userId, restaurantId, allowedRoles) {
  const q = await pool.query(
    'SELECT role FROM role_assignments WHERE user_id=$1 AND restaurant_id=$2 LIMIT 1',
    [userId, restaurantId]
  );
  if (!q.rowCount) return false;
  return allowedRoles.includes(q.rows[0].role);
}

module.exports = { getOrCreateRestaurant, hasRestaurantRole };
