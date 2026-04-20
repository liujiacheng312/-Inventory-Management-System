const db = require('../config/db');
const { ROLES } = require('./roles');

async function bootstrapDatabase() {
  await db.execute(
    `ALTER TABLE users MODIFY COLUMN role VARCHAR(20) NOT NULL DEFAULT '${ROLES.USER}'`
  );

  const [superAdmins] = await db.execute(
    'SELECT id FROM users WHERE role = ? LIMIT 1',
    [ROLES.SUPER_ADMIN]
  );

  if (superAdmins.length > 0) {
    return;
  }

  const [promoteNamedAdmin] = await db.execute(
    'UPDATE users SET role = ? WHERE username = ? AND role = ?',
    [ROLES.SUPER_ADMIN, 'admin', ROLES.ADMIN]
  );

  if (promoteNamedAdmin.affectedRows > 0) {
    return;
  }

  const [existingAdmins] = await db.execute(
    'SELECT id FROM users WHERE role = ? ORDER BY id ASC LIMIT 1',
    [ROLES.ADMIN]
  );

  if (existingAdmins.length > 0) {
    await db.execute('UPDATE users SET role = ? WHERE id = ?', [
      ROLES.SUPER_ADMIN,
      existingAdmins[0].id,
    ]);
  }
}

module.exports = {
  bootstrapDatabase,
};
