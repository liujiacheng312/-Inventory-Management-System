const express = require('express');
const router = express.Router();
const db = require('../config/db');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

router.get('/', authMiddleware, async (req, res) => {
  try {
    const [materials] = await db.execute(
      `SELECT m.id, m.name, m.brand, m.model, m.spec, m.quantity, m.remark,
              COALESCE(ub.count, 0) AS borrowed_count
       FROM materials m
       LEFT JOIN user_borrowed ub ON m.id = ub.material_id AND ub.user_id = ?
       ORDER BY LEFT(m.name, 1), m.name, m.brand, m.model, m.spec`,
      [req.user.id]
    );
    res.json({ success: true, data: materials });
  } catch (error) {
    console.error('获取库存错误:', error);
    res.status(500).json({ success: false, message: '获取库存失败' });
  }
});

router.post('/add', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { name, brand, model, spec, quantity, remark } = req.body;

    if (!name || !brand || !model || !spec || quantity === undefined) {
      return res.status(400).json({ success: false, message: '请填写完整信息' });
    }

    const [existing] = await db.execute(
      'SELECT id FROM materials WHERE name = ? AND brand = ? AND model = ? AND spec = ?',
      [name, brand, model, spec]
    );

    if (existing.length > 0) {
      await db.execute(
        'UPDATE materials SET quantity = quantity + ?, remark = ? WHERE id = ?',
        [quantity, remark || '', existing[0].id]
      );

      await db.execute(
        'INSERT INTO records (user_id, material_id, count, type, status) VALUES (?, ?, ?, ?, ?)',
        [req.user.id, existing[0].id, quantity, 'in', 'approved']
      );

      return res.json({ success: true, message: '库存已更新（累加）' });
    }

    const [result] = await db.execute(
      'INSERT INTO materials (name, brand, model, spec, quantity, remark) VALUES (?, ?, ?, ?, ?, ?)',
      [name, brand, model, spec, quantity, remark || '']
    );

    await db.execute(
      'INSERT INTO records (user_id, material_id, count, type, status) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, result.insertId, quantity, 'in', 'approved']
    );

    res.json({ success: true, message: '添加成功' });
  } catch (error) {
    console.error('添加库存错误:', error);
    res.status(500).json({ success: false, message: '添加失败' });
  }
});

router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, brand, model, spec, quantity, remark } = req.body;

    await db.execute(
      'UPDATE materials SET name = ?, brand = ?, model = ?, spec = ?, quantity = ?, remark = ? WHERE id = ?',
      [name, brand, model, spec, quantity, remark || '', id]
    );

    res.json({ success: true, message: '更新成功' });
  } catch (error) {
    console.error('更新库存错误:', error);
    res.status(500).json({ success: false, message: '更新失败' });
  }
});

router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    await db.execute('DELETE FROM materials WHERE id = ?', [id]);
    res.json({ success: true, message: '删除成功' });
  } catch (error) {
    console.error('删除库存错误:', error);
    res.status(500).json({ success: false, message: '删除失败' });
  }
});

router.post('/take', authMiddleware, async (req, res) => {
  try {
    const { material_id, count } = req.body;

    if (!material_id || !count || count <= 0) {
      return res.status(400).json({ success: false, message: '请提供有效的物料和数量' });
    }

    const [materials] = await db.execute(
      'SELECT * FROM materials WHERE id = ?',
      [material_id]
    );

    if (materials.length === 0) {
      return res.status(404).json({ success: false, message: '物料不存在' });
    }

    const isAdmin = req.user.role === 'admin' || req.user.role === 'super_admin';
    const status = isAdmin ? 'approved' : 'pending';

    if (isAdmin && materials[0].quantity < count) {
      return res.status(400).json({ success: false, message: '库存不足' });
    }

    if (isAdmin) {
      await db.execute(
        'UPDATE materials SET quantity = quantity - ? WHERE id = ?',
        [count, material_id]
      );

      await db.execute(
        'INSERT INTO user_borrowed (user_id, material_id, count) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE count = count + ?',
        [req.user.id, material_id, count, count]
      );
    }

    await db.execute(
      'INSERT INTO records (user_id, material_id, count, type, status) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, material_id, count, 'out', status]
    );

    res.json({
      success: true,
      message: isAdmin ? '领取成功，库存已自动减少' : '申请已提交，等待管理员审批',
    });
  } catch (error) {
    console.error('领取错误:', error);
    res.status(500).json({ success: false, message: '领取失败' });
  }
});

router.post('/return', authMiddleware, async (req, res) => {
  try {
    const { material_id, count } = req.body;

    if (!material_id || !count || count <= 0) {
      return res.status(400).json({ success: false, message: '请提供有效的物料和数量' });
    }

    const [materials] = await db.execute(
      'SELECT * FROM materials WHERE id = ?',
      [material_id]
    );

    if (materials.length === 0) {
      return res.status(404).json({ success: false, message: '物料不存在' });
    }

    const [borrowed] = await db.execute(
      'SELECT count FROM user_borrowed WHERE user_id = ? AND material_id = ?',
      [req.user.id, material_id]
    );

    if (borrowed.length === 0 || borrowed[0].count <= 0) {
      return res.status(400).json({ success: false, message: '没有可归还的物品' });
    }

    const returnCount = Math.min(count, borrowed[0].count);

    const isAdmin = req.user.role === 'admin' || req.user.role === 'super_admin';
    const status = isAdmin ? 'approved' : 'pending';

    if (isAdmin) {
      await db.execute(
        'UPDATE materials SET quantity = quantity + ? WHERE id = ?',
        [returnCount, material_id]
      );

      await db.execute(
        'UPDATE user_borrowed SET count = count - ? WHERE user_id = ? AND material_id = ?',
        [returnCount, req.user.id, material_id]
      );
    }

    await db.execute(
      'INSERT INTO records (user_id, material_id, count, type, status) VALUES (?, ?, ?, ?, ?)',
      [req.user.id, material_id, returnCount, 'in', status]
    );

    res.json({
      success: true,
      message: isAdmin ? `归还成功，已归还 ${returnCount} 件，库存已自动增加` : '归还申请已提交，等待管理员审批',
    });
  } catch (error) {
    console.error('归还错误:', error);
    res.status(500).json({ success: false, message: '归还失败' });
  }
});

router.get('/borrowed', authMiddleware, async (req, res) => {
  try {
    const [borrowed] = await db.execute(
      `SELECT ub.material_id, ub.count, m.name, m.brand, m.model, m.spec
       FROM user_borrowed ub
       JOIN materials m ON ub.material_id = m.id
       WHERE ub.user_id = ? AND ub.count > 0`,
      [req.user.id]
    );

    res.json({ success: true, data: borrowed });
  } catch (error) {
    console.error('获取借用记录错误:', error);
    res.status(500).json({ success: false, message: '获取借用记录失败' });
  }
});

module.exports = router;