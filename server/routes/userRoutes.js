const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const db = require('../config/db');
const {
  authMiddleware,
  superAdminMiddleware,
  JWT_SECRET,
} = require('../middleware/auth');
const { ROLES } = require('../utils/roles');

const router = express.Router();

const JWT_EXPIRE = '24h';

function buildAuthPayload(user) {
  const token = jwt.sign(
    { id: user.id, username: user.username, role: user.role },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRE }
  );

  return {
    token,
    user: {
      id: user.id,
      username: user.username,
      role: user.role,
    },
  };
}

router.post('/register', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: '请输入用户名和密码',
      });
    }

    const trimmedUsername = String(username).trim();

    if (trimmedUsername.length < 3 || trimmedUsername.length > 20) {
      return res.status(400).json({
        success: false,
        message: '用户名长度需在 3 到 20 个字符之间',
      });
    }

    if (String(password).length < 6) {
      return res.status(400).json({
        success: false,
        message: '密码长度至少 6 位',
      });
    }

    const [existingUsers] = await db.execute(
      'SELECT id FROM users WHERE username = ?',
      [trimmedUsername]
    );

    if (existingUsers.length > 0) {
      return res.status(409).json({
        success: false,
        message: '用户名已存在',
      });
    }

    const hashedPassword = await bcrypt.hash(String(password), 10);
    const [result] = await db.execute(
      'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
      [trimmedUsername, hashedPassword, ROLES.USER]
    );

    const [users] = await db.execute(
      'SELECT id, username, role FROM users WHERE id = ?',
      [result.insertId]
    );

    res.status(201).json({
      success: true,
      message: '注册成功',
      data: buildAuthPayload(users[0]),
    });
  } catch (error) {
    console.error('注册错误:', error);
    res.status(500).json({
      success: false,
      message: '服务器内部错误',
    });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: '请输入用户名和密码',
      });
    }

    const [users] = await db.execute('SELECT * FROM users WHERE username = ?', [
      String(username).trim(),
    ]);

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: '用户名或密码错误',
      });
    }

    const user = users[0];
    const isValidPassword = await bcrypt.compare(String(password), user.password);

    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        message: '用户名或密码错误',
      });
    }

    res.json({
      success: true,
      data: buildAuthPayload(user),
    });
  } catch (error) {
    console.error('登录错误:', error);
    res.status(500).json({
      success: false,
      message: '服务器内部错误',
    });
  }
});

router.get('/list', authMiddleware, superAdminMiddleware, async (req, res) => {
  try {
    const [users] = await db.execute(
      `SELECT id, username, role, created_at
       FROM users
       ORDER BY
         CASE role
           WHEN ? THEN 0
           WHEN ? THEN 1
           ELSE 2
         END,
         created_at ASC,
         id ASC`,
      [ROLES.SUPER_ADMIN, ROLES.ADMIN]
    );

    res.json({ success: true, data: users });
  } catch (error) {
    console.error('获取用户列表错误:', error);
    res.status(500).json({
      success: false,
      message: '获取用户列表失败',
    });
  }
});

router.patch(
  '/:id/role',
  authMiddleware,
  superAdminMiddleware,
  async (req, res) => {
    try {
      const userId = Number.parseInt(req.params.id, 10);
      const { role } = req.body;

      if (!Number.isInteger(userId)) {
        return res.status(400).json({
          success: false,
          message: '无效的用户编号',
        });
      }

      if (![ROLES.USER, ROLES.ADMIN].includes(role)) {
        return res.status(400).json({
          success: false,
          message: '只允许设置为普通用户或管理员',
        });
      }

      if (userId === req.user.id) {
        return res.status(400).json({
          success: false,
          message: '不能修改自己的角色',
        });
      }

      const [users] = await db.execute(
        'SELECT id, username, role FROM users WHERE id = ?',
        [userId]
      );

      if (users.length === 0) {
        return res.status(404).json({
          success: false,
          message: '用户不存在',
        });
      }

      const targetUser = users[0];

      if (targetUser.role === ROLES.SUPER_ADMIN) {
        return res.status(403).json({
          success: false,
          message: '不能修改超级管理员角色',
        });
      }

      await db.execute('UPDATE users SET role = ? WHERE id = ?', [role, userId]);

      res.json({
        success: true,
        message: role === ROLES.ADMIN ? '已提升为管理员' : '已调整为普通用户',
        data: {
          ...targetUser,
          role,
        },
      });
    } catch (error) {
      console.error('更新用户角色错误:', error);
      res.status(500).json({
        success: false,
        message: '更新用户角色失败',
      });
    }
  }
);

module.exports = router;
