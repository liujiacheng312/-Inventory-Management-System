const jwt = require('jsonwebtoken');

const { hasAdminAccess, isSuperAdmin } = require('../utils/roles');

const JWT_SECRET = 'inventory-system-secret-key-2024';

const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: '未提供认证令牌' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: '令牌无效或已过期' });
  }
};

const adminMiddleware = (req, res, next) => {
  if (!hasAdminAccess(req.user.role)) {
    return res.status(403).json({ success: false, message: '需要管理员权限' });
  }

  next();
};

const superAdminMiddleware = (req, res, next) => {
  if (!isSuperAdmin(req.user.role)) {
    return res.status(403).json({ success: false, message: '需要超级管理员权限' });
  }

  next();
};

module.exports = {
  authMiddleware,
  adminMiddleware,
  superAdminMiddleware,
  JWT_SECRET,
};
