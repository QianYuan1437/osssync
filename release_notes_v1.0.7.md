## 🎨 UI 优化 / UI Improvements

### 下拉框样式优化 / Dropdown Style Improvements
- ✅ 同步日志页面任务筛选下拉框优化 / Optimized task filter dropdown in sync logs page
  - 修复点击后圆角矩形残留问题 / Fixed rounded rectangle artifact after clicking
  - 改用 PopupMenuButton 实现更流畅的交互 / Switched to PopupMenuButton for smoother interaction
  - 优化字体大小和垂直对齐 / Optimized font size and vertical alignment
  - 高度调整为32px，与筛选芯片保持一致 / Height adjusted to 32px to match filter chips

- ✅ 所有下拉选择框支持自适应宽度 / All dropdown fields support adaptive width
  - 同步任务页面：账户选择、存储桶选择、同步间隔 / Sync task page: account, bucket, interval selectors
  - 账号管理页面：地域(Region)选择 / Account management page: region selector
  - 添加 menuMaxHeight 限制，超出时可滚动 / Added menuMaxHeight limit with scrolling support

- ✅ 保持圆角边框设计 / Maintained rounded border design
  - 所有下拉框统一使用8px圆角 / All dropdowns use 8px border radius
  - 提升界面视觉一致性 / Enhanced visual consistency

## 🐛 问题修复 / Bug Fixes
- 修复同步日志下拉框点击残留问题 / Fixed dropdown click artifact issue
- 修复下拉框宽度超出容器问题 / Fixed dropdown width overflow issue

## ✨ 技术改进 / Technical Improvements
- 使用 PopupMenuButton 替代 DropdownButton 实现更好的交互体验 / Used PopupMenuButton instead of DropdownButton for better UX
- 优化下拉菜单布局和样式控制 / Optimized dropdown menu layout and style control
- 添加 isExpanded 和 menuMaxHeight 属性提升用户体验 / Added isExpanded and menuMaxHeight properties for better UX

---
## 📦 下载 / Download

**下载安装包 / Download Installers:**
- MSIX 安装包（推荐用于 Windows 10/11）/ MSIX Installer (Recommended for Windows 10/11)
- EXE 安装包（传统安装方式）/ EXE Installer (Traditional setup)
