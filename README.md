# OSS Sync - 阿里云 OSS 同步工具

一个基于 Flutter 构建的 Windows 桌面应用，用于将本地文件夹与阿里云 OSS 存储桶进行自动定时同步。

## 功能特性

- **多账户管理** — 支持配置多个阿里云账户（AccessKey ID / Secret）
- **多存储桶配置** — 每个账户可绑定多个 OSS 存储桶，支持全国各地域
- **灵活同步方向** — 支持上传、下载、双向三种同步模式
- **自动定时同步** — 可设置 5 分钟到每天的自动同步间隔
- **增量同步** — 基于 ETag/MD5 对比，只同步变更文件，节省流量
- **系统托盘** — 最小化到系统托盘，后台持续运行
- **同步日志** — 完整记录每次同步的文件数量、耗时和错误信息
- **深色/浅色主题** — 支持主题切换，偏好持久化保存

## 快速开始

### 环境要求

- Flutter SDK >= 3.10.0
- Windows 10/11 (x64)

### 安装依赖

```bash
flutter pub get
```

### 运行

```bash
flutter run -d windows
```

### 构建发布版本

```bash
flutter build windows --release
```

构建产物位于 `build/windows/x64/runner/Release/`。

## 项目结构

```
lib/
├── main.dart              # 入口，初始化窗口/托盘/Provider
├── app.dart               # 路由配置（go_router）
├── models/                # 数据模型
│   ├── account_model.dart # 阿里云账户
│   ├── bucket_config.dart # OSS 存储桶配置
│   ├── sync_task.dart     # 同步任务
│   └── sync_log.dart      # 同步日志
├── services/              # 业务服务
│   ├── storage_service.dart   # 本地持久化（SharedPreferences + SecureStorage）
│   ├── oss_service.dart       # 阿里云 OSS REST API 封装
│   ├── sync_engine.dart       # 同步引擎（差异对比、增量同步）
│   └── scheduler_service.dart # 定时任务调度
├── providers/             # 状态管理（Provider）
│   ├── account_provider.dart  # 账户和存储桶状态
│   ├── sync_provider.dart     # 同步任务和日志状态
│   └── theme_provider.dart    # 主题状态
├── screens/               # 页面
│   ├── home_screen.dart           # 控制台首页
│   ├── accounts_screen.dart       # 账户列表
│   ├── account_edit_screen.dart   # 账户编辑
│   ├── sync_tasks_screen.dart     # 同步任务列表
│   ├── sync_task_edit_screen.dart # 同步任务编辑
│   └── logs_screen.dart           # 同步日志
└── widgets/               # 公共组件
    ├── main_shell.dart    # 主框架（左侧导航栏）
    └── common_widgets.dart # 通用 Widget（PageHeader、EmptyState 等）
```

## 使用说明

### 1. 添加阿里云账户

进入「账户管理」→「新增账户」，填写：
- 账户名称（自定义）
- AccessKey ID
- AccessKey Secret
- 存储桶名称和所在地域

点击「测试连接」验证配置是否正确，然后保存。

### 2. 创建同步任务

进入「同步任务」→「新建任务」，配置：
- 任务名称
- 选择账户和存储桶
- 本地同步文件夹（点击「浏览」选择）
- OSS 路径前缀（可选，留空则同步到根目录）
- 同步方向（上传 / 下载 / 双向）
- 自动同步间隔

### 3. 开始同步

- **手动同步**：在任务卡片上点击「立即同步」
- **自动同步**：启用任务后，按设定间隔自动执行
- **全部同步**：右键系统托盘图标 → 「立即同步全部」

### 4. 查看日志

进入「同步日志」页面，可按日志级别（信息/警告/错误/成功）和任务筛选。

## 数据安全

- AccessKey Secret 使用 `flutter_secure_storage` 加密存储于 Windows Credential Manager
- 所有 OSS 请求使用 HMAC-SHA1 签名，不明文传输密钥

## 依赖说明

| 包 | 用途 |
|---|---|
| `window_manager` | 窗口控制（大小、标题、关闭拦截） |
| `tray_manager` | 系统托盘图标和菜单 |
| `go_router` | 页面路由 |
| `provider` | 状态管理 |
| `shared_preferences` | 本地配置持久化 |
| `flutter_secure_storage` | 密钥加密存储 |
| `http` | OSS REST API 请求 |
| `crypto` | HMAC-SHA1 签名 |
| `file_picker` | 本地文件夹选择 |
| `intl` | 日期格式化 |
