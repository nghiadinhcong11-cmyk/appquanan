async function getOrCreateRestaurant(pool, restaurantName) {
  const query = `
    INSERT INTO restaurants (name)
    VALUES ($1)
    ON CONFLICT (lower(name)) DO UPDATE SET name = EXCLUDED.name
    RETURNING id, name
  `;
  const res = await pool.query(query, [restaurantName]);
  return res.rows[0];
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
