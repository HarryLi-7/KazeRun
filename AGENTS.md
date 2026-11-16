# KazeRun 项目维护与协作规范

本项目是由用户、Antigravity 与 Codex 等多 AI 代理共同协作开发的开源 macOS 原生 Garmin 跑步分析应用。所有参与维护的 AI 与开发者必须严格遵守以下规范：

---

### 1. 开工前对齐准则 (Pre-flight Handshake)
- **读取最新日志**：开始任务前，必须首先阅读 [CHANGELOG.md](CHANGELOG.md) 末尾与本文件，确认上一个改动者、改动模块与当前应用状态，保留已有成果。
- **工作区巡检**：运行 `git status` 确认工作区无未跟踪或未提交的异常脏文件。
- **单写入者原则 (Single Writer)**：同一功能或同一文件避免多代理同时写入竞争，避免代码覆盖。

---

### 2. 隐私与防泄漏安全红线 (Privacy & Security Guardrails)
- **严禁硬编码绝对路径**：代码中严禁写入任何包含个人电脑用户名（如 `/Users/...`）或特定机器专属的本地绝对路径。
- **动态路径推导**：所有运行时路径必须通过 `Path.home()`、`Bundle.main`、`#filePath` 或标准环境变量（如 `KAZERUN_PROJECT_ROOT`、`KAZERUN_DATA_DIR`）进行安全推导。
- **提交前安全检查**：提交前必须运行 `./scripts/verify_clean.sh`，确保通过敏感路径检测与语法检查。

---

### 3. 构建与实机生命周期规范 (Build & Runtime Lifecycle)
- **Release 级编译校验**：改动 Swift 代码后，必须运行 `swift build -c release`，确保无报错、无废弃警告通过。
- **打包更新 App Bundle**：运行 `./scripts/build_app.sh`，重新生成 `dist/KazeRun.app`。
- **平稳重启验证**：按用户授权平稳退出旧实例（`osascript -e 'tell application "KazeRun" to quit'`），休眠 1.5 秒后重新打开项目内 `dist/KazeRun.app` 并核对实际运行 PID。不能确认新版载入时如实说明，严禁盲目并发多开。

---

### 4. Git 提交与变更日志规范 (Commit & Changelog Protocol)
- **原子化提交 (Atomic Commits)**：每批功能完成且实机验证通过后，立即执行一次规范的 Git Commit（采用 Conventional Commits 格式，如 `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`）。
- **实事求是登记日志**：在交付前向 [CHANGELOG.md](CHANGELOG.md) 末尾追加一行：记录实际本地时间（UTC+8）、修改者、具体改动详情和已执行的验证结果（含运行 PID）。严禁推测结果，不得改写或删除历史记录。
