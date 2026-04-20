const express = require('express');
const cors = require('cors');

const { bootstrapDatabase } = require('./utils/bootstrap');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const userRoutes = require('./routes/userRoutes');
const materialRoutes = require('./routes/materialRoutes');
const recordRoutes = require('./routes/recordRoutes');
const excelRoutes = require('./routes/excelRoutes');

app.use('/user', userRoutes);
app.use('/material', materialRoutes);
app.use('/record', recordRoutes);
app.use('/excel', excelRoutes);

app.get('/', (req, res) => {
  res.json({
    message: '库存管理系统 API',
    version: '1.0.0',
    endpoints: {
      auth: '/user/login',
      materials: '/material',
      records: '/record',
      excel: '/excel',
    },
  });
});

async function startServer() {
  try {
    await bootstrapDatabase();
    app.listen(3000, () => {
      console.log('Server running on http://localhost:3000');
    });
  } catch (error) {
    console.error('服务器启动失败:', error);
    process.exit(1);
  }
}

startServer();

module.exports = app;
