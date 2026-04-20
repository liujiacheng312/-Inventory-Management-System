const express = require('express');

const db = require('../config/db');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');
const { hasAdminAccess } = require('../utils/roles');

const router = express.Router();

router.get('/', authMiddleware, async (req, res) => {
  try {
    let records;

    if (hasAdminAccess(req.user.role)) {
      [records] = await db.execute(`
        SELECT r.*, u.username, m.name, m.brand, m.spec
        FROM records r
        JOIN users u ON r.user_id = u.id
        JOIN materials m ON r.material_id = m.id
        ORDER BY r.created_at DESC
      `);
    } else {
      [records] = await db.execute(
        `
        SELECT r.*, m.name, m.brand, m.spec
        FROM records r
        JOIN materials m ON r.material_id = m.id
        WHERE r.user_id = ?
        ORDER BY r.created_at DESC
      `,
        [req.user.id]
      );
    }

    res.json({ success: true, data: records });
  } catch (error) {
    console.error('获取记录错误:', error);
    res.status(500).json({ success: false, message: '获取记录失败' });
  }
});

router.get('/pending', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const [records] = await db.execute(`
      SELECT r.*, u.username, m.name, m.brand, m.spec
      FROM records r
      JOIN users u ON r.user_id = u.id
      JOIN materials m ON r.material_id = m.id
      WHERE r.status = 'pending'
      ORDER BY r.created_at DESC
    `);

    res.json({ success: true, data: records });
  } catch (error) {
    console.error('获取待审批记录错误:', error);
    res.status(500).json({ success: false, message: '获取记录失败' });
  }
});

router.post('/approve/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;

    const [records] = await db.execute(
      'SELECT * FROM records WHERE id = ? AND status = ?',
      [id, 'pending']
    );

    if (records.length === 0) {
      return res
        .status(404)
        .json({ success: false, message: '记录不存在或已处理' });
    }

    const record = records[0];

    if (record.type === 'out') {
      const [materials] = await db.execute(
        'SELECT * FROM materials WHERE id = ?',
        [record.material_id]
      );

      if (materials[0].quantity < record.count) {
        await db.execute('UPDATE records SET status = ? WHERE id = ?', [
          'rejected',
          id,
        ]);
        return res.status(400).json({
          success: false,
          message: '库存不足，申请已拒绝',
        });
      }

      await db.execute('UPDATE materials SET quantity = quantity - ? WHERE id = ?', [
        record.count,
        record.material_id,
      ]);

      await db.execute(
        'INSERT INTO user_borrowed (user_id, material_id, count) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE count = count + ?',
        [record.user_id, record.material_id, record.count, record.count]
      );
    } else if (record.type === 'in') {
      const [borrowed] = await db.execute(
        'SELECT count FROM user_borrowed WHERE user_id = ? AND material_id = ?',
        [record.user_id, record.material_id]
      );

      const returnCount =
        borrowed.length > 0 ? Math.min(record.count, borrowed[0].count) : 0;

      await db.execute('UPDATE materials SET quantity = quantity + ? WHERE id = ?', [
        returnCount,
        record.material_id,
      ]);

      if (returnCount > 0) {
        await db.execute(
          'UPDATE user_borrowed SET count = count - ? WHERE user_id = ? AND material_id = ?',
          [returnCount, record.user_id, record.material_id]
        );
      }
    }

    await db.execute('UPDATE records SET status = ? WHERE id = ?', [
      'approved',
      id,
    ]);

    res.json({ success: true, message: '审批成功' });
  } catch (error) {
    console.error('审批错误:', error);
    res.status(500).json({ success: false, message: '审批失败' });
  }
});

router.post('/reject/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const { id } = req.params;
    await db.execute('UPDATE records SET status = ? WHERE id = ?', ['rejected', id]);
    res.json({ success: true, message: '已拒绝申请' });
  } catch (error) {
    console.error('拒绝错误:', error);
    res.status(500).json({ success: false, message: '操作失败' });
  }
});

module.exports = router;
