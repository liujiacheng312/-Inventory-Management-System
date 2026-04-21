const express = require('express');
const cors = require('cors');
const os = require('os');

const { bootstrapDatabase } = require('./utils/bootstrap');

const app = express();
const HOST = process.env.HOST || '0.0.0.0';
const PORT = Number(process.env.PORT) || 3000;

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

function getLanAddresses() {
  const networkInterfaces = os.networkInterfaces();
  const addresses = [];

  Object.values(networkInterfaces).forEach((items = []) => {
    items.forEach((item) => {
      if (item.family === 'IPv4' && !item.internal) {
        addresses.push(item.address);
      }
    });
  });

  return [...new Set(addresses)];
}

async function startServer() {
  try {
    await bootstrapDatabase();
    app.listen(PORT, HOST, () => {
      console.log(`Server running on http://${HOST}:${PORT}`);

      const lanAddresses = getLanAddresses();
      if (HOST === '0.0.0.0' && lanAddresses.length > 0) {
        lanAddresses.forEach((address) => {
          console.log(`LAN access: http://${address}:${PORT}`);
        });
      }
    });
  } catch (error) {
    console.error('服务器启动失败:', error);
    process.exit(1);
  }
}

startServer();

module.exports = app;
