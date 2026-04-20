const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const XLSX = require('xlsx');
const jwt = require('jsonwebtoken');

const db = require('../config/db');
const { authMiddleware, JWT_SECRET } = require('../middleware/auth');
const { hasAdminAccess } = require('../utils/roles');

const router = express.Router();

const uploadDir = path.resolve(__dirname, '..', 'uploads');
const exportDir = path.resolve(__dirname, '..', 'exports');

fs.mkdirSync(uploadDir, { recursive: true });
fs.mkdirSync(exportDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const isExcelFile =
      file.mimetype ===
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      file.originalname.toLowerCase().endsWith('.xlsx');

    if (isExcelFile) {
      cb(null, true);
      return;
    }

    cb(new Error('仅支持 .xlsx 文件'));
  },
});

const uploadSingleExcel = (req, res, next) => {
  upload.single('file')(req, res, (error) => {
    if (error) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }

    next();
  });
};

const getCellValue = (row, keys) => {
  for (const key of keys) {
    if (row[key] !== undefined && row[key] !== null && row[key] !== '') {
      return row[key];
    }
  }

  return undefined;
};

router.post('/import', authMiddleware, uploadSingleExcel, async (req, res) => {
  try {
    if (!hasAdminAccess(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: '需要管理员权限',
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: '请上传 .xlsx 文件',
      });
    }

    const workbook = XLSX.readFile(req.file.path);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const data = XLSX.utils.sheet_to_json(worksheet);

    let successCount = 0;
    let updateCount = 0;

    for (const row of data) {
      const name = getCellValue(row, ['物料名称', '物品', 'name', 'Name']);
      const brand = getCellValue(row, ['品牌', 'brand', 'Brand']);
      const model = getCellValue(row, ['型号', 'model', 'Model']) || '';
      const spec = getCellValue(row, ['规格', 'spec', 'Spec', 'specification']);
      const quantityValue = getCellValue(row, [
        '数量',
        '库存数量',
        'quantity',
        'Quantity',
      ]);
      const remark = getCellValue(row, ['备注', 'remark', 'Remark']) || '';
      const quantity = Number.parseInt(quantityValue, 10) || 0;

      if (!name || !brand || !spec) {
        continue;
      }

      const [existing] = await db.execute(
        'SELECT id FROM materials WHERE name = ? AND brand = ? AND model = ? AND spec = ?',
        [name, brand, model, spec]
      );

      if (existing.length > 0) {
        await db.execute(
          'UPDATE materials SET quantity = quantity + ?, remark = ? WHERE id = ?',
          [quantity, remark, existing[0].id]
        );

        await db.execute(
          'INSERT INTO records (user_id, material_id, count, type, status) VALUES (?, ?, ?, ?, ?)',
          [req.user.id, existing[0].id, quantity, 'in', 'approved']
        );

        updateCount++;
      } else {
        const [result] = await db.execute(
          'INSERT INTO materials (name, brand, model, spec, quantity, remark) VALUES (?, ?, ?, ?, ?, ?)',
          [name, brand, model, spec, quantity, remark]
        );

        await db.execute(
          'INSERT INTO records (user_id, material_id, count, type, status) VALUES (?, ?, ?, ?, ?)',
          [req.user.id, result.insertId, quantity, 'in', 'approved']
        );

        successCount++;
      }
    }

    fs.unlinkSync(req.file.path);

    res.json({
      success: true,
      data: {
        successCount,
        updateCount,
        total: data.length,
      },
      message: `导入完成：新增 ${successCount} 条，更新 ${updateCount} 条。`,
    });
  } catch (error) {
    console.error('导入 Excel 错误:', error);

    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }

    res.status(500).json({
      success: false,
      message: `导入失败：${error.message}`,
    });
  }
});

router.get('/export', async (req, res) => {
  try {
    const token = req.query.token || req.headers.authorization?.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: '缺少认证令牌',
      });
    }

    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (error) {
      return res.status(401).json({
        success: false,
        message: '令牌无效或已过期',
      });
    }

    if (!hasAdminAccess(decoded.role)) {
      return res.status(403).json({
        success: false,
        message: '需要管理员权限',
      });
    }

    const [materials] = await db.execute(
      'SELECT name AS material_name, brand AS brand, model AS model, spec AS spec, quantity AS quantity, remark AS remark FROM materials ORDER BY name, brand, model, spec'
    );

    const exportData = materials.map((material, index) => ({
      序号: index + 1,
      物料名称: material.material_name,
      品牌: material.brand,
      型号: material.model,
      规格: material.spec,
      数量: material.quantity,
      备注: material.remark || '',
    }));

    const worksheet = XLSX.utils.json_to_sheet(exportData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, '库存数据');

    const filePath = path.join(exportDir, `inventory_export_${Date.now()}.xlsx`);
    XLSX.writeFile(workbook, filePath);

    await db.execute(
      'INSERT INTO records (user_id, material_id, count, type, status) VALUES (?, NULL, ?, ?, ?)',
      [decoded.id, materials.length, 'export', 'approved']
    );

    res.download(filePath, '库存数据.xlsx', (error) => {
      if (error) {
        console.error('下载错误:', error);
      }

      setTimeout(() => {
        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
        }
      }, 60000);
    });
  } catch (error) {
    console.error('导出 Excel 错误:', error);
    res.status(500).json({
      success: false,
      message: '导出失败',
    });
  }
});

module.exports = router;
