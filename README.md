# Inventory Management System

一个面向内网场景的库存管理系统，采用 Flutter 前端、Node.js/Express 后端和 MySQL 数据库。

## 功能概览

- 用户登录与注册
- 库存查询、编辑、删除
- 领用 / 归还申请
- 待审批处理
- Excel 导入 / 导出
- 管理员与超级管理员角色区分
- Windows 客户端与 Android APK 构建

## 技术栈

- Flutter
- Node.js / Express
- MySQL
- JWT
- xlsx / multer

## 快速开始

### 1. 初始化数据库

```bash
mysql -u root -p < database/init.sql
```

### 2. 启动后端

```bash
cd server
npm install
npm start
```

默认监听：

```text
http://0.0.0.0:3000
```

### 3. 启动前端

```bash
cd client/my_app
flutter pub get
flutter run -d windows
```

如果前端要访问局域网中的后端，请传入内网地址：

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

## Android APK

```bash
cd client/my_app
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.100:3000
```

产物位置：

```text
client/my_app/build/app/outputs/flutter-apk/app-release.apk
```

说明：

- 当前 Android 版本已允许明文 `http`，适合内网测试
- `release` 目前仍使用调试签名，适合测试，不适合正式上架

## 默认账号

| 角色 | 用户名 | 密码 |
| --- | --- | --- |
| 超级管理员 | `admin` | `admin123` |
| 普通用户 | `user1` | `admin123` |

## 文档

- [部署说明](./docs/部署说明.md)
- [开发文档](./docs/开发文档.md)
- [接口文档](./docs/接口文档.md)
- [数据库设计](./docs/数据库设计.md)
