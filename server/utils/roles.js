const ROLES = {
  SUPER_ADMIN: 'super_admin',
  ADMIN: 'admin',
  USER: 'user',
};

function hasAdminAccess(role) {
  return role === ROLES.ADMIN || role === ROLES.SUPER_ADMIN;
}

function isSuperAdmin(role) {
  return role === ROLES.SUPER_ADMIN;
}

module.exports = {
  ROLES,
  hasAdminAccess,
  isSuperAdmin,
};
