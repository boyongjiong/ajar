<div align="center">
  <img src="assets/logo.svg" alt="Ajar Logo" width="48" height="80" />
  <h1>Ajar</h1>
  <p><strong>macOS 菜单栏本地端口管理器 &amp; 命令行工具</strong></p>
  <p><em>看清每个本地端口属于哪个项目、是做什么用的，然后安全地关掉不再需要的服务。</em></p>

  <p>
    <a href="https://boyongjiong.github.io/ajar/"><img src="https://img.shields.io/badge/website-ajar-211811?style=flat-square" alt="Website" /></a>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-555555?style=flat-square" alt="macOS 14+" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-555555?style=flat-square" alt="License: MIT" /></a>
  </p>

  <p><a href="README.md">English</a> · <strong>中文</strong></p>

  <br />
  <picture>
    <source srcset="assets/preview-zh-dark.png" media="(prefers-color-scheme: dark)">
    <img src="assets/preview-zh.png" alt="Ajar 菜单栏面板：可关闭的端口排在前面，系统服务与 app 折叠收起" width="375" />
  </picture>
  <br /><br />
</div>

并行让多个 coding agent 干活时，开发服务器、测试服务和构建守护进程会不断在不同端口上启动，忙完一天总有几个还开着。`lsof`、`kill-port` 只能告诉你“端口被占用”，说不清它属于哪个项目、是做什么的。

**Ajar** 安静地待在菜单栏里，列出所有正在监听的端口、背后的进程和项目，以及每个端口的用途。把那些虚掩着的门，轻轻关上。

> Ajar fork 自 Songhai Fan 的 [LeftOpen](https://github.com/SonghaiFan/leftopen)，详见[致谢](#致谢)。

## 安装

Ajar 暂未发布安装包，请从源码构建。需要完整的 Xcode（仅有 Command Line Tools 不够），macOS Sonoma (14.0+)，支持 Apple Silicon 与 Intel。

```bash
git clone https://github.com/boyongjiong/ajar.git
cd ajar
python3 Scripts/dev-app.py run        # 构建并运行本地测试版
```

安装自己构建的版本：

```bash
AJAR_OUTPUT_DIR=dist/local zsh Scripts/build-app.sh
cp -R dist/local/Ajar.app /Applications/
ln -sf /Applications/Ajar.app/Contents/MacOS/ajar /opt/homebrew/bin/ajar   # 可选：命令行
```

本地构建使用 ad-hoc 签名，在自己的 Mac 上使用没有问题。如果下载依赖时报 `CERTIFICATE_VERIFY_FAILED`，请运行 python.org 版 Python 自带的 *Install Certificates*，或设置 `SSL_CERT_FILE=/etc/ssl/cert.pem`。

---

## 核心设计

- **知道端口是谁的。** 从进程的工作目录向上找 `.git`、`package.json`、`pyproject.toml`、`Cargo.toml`、`go.mod`，或者解析它所属的 `.app`。全局 npm 包、`python -m` 模块和 Redis / Postgres / Ollama 这类独立服务也按名字识别，很少再看到一个光秃秃的 `node` 或 `python`。
- **真实图标，不预存。** 有 `.app` 就用它的图标；否则用项目或包自己带的（Tauri / Electron app icon、`index.html` 声明的 favicon、`public/` 约定）；否则向本机服务器抓 favicon；再没有才用符号。
- **按来历分组。** 开发服务器（从项目、终端、编辑器或 agent 启动）、后台服务（由 launchd 管理：brew services、登录项）、App 和系统。分组即关闭方式，每组都写明：开发服务器发 SIGTERM，launchd 会重启的服务提示 `brew services stop …`，App 的端口需要退出 App。
- **先轻轻关闭。** 发送 `SIGTERM`，关闭前重新核对进程身份。单独关闭一个进程后等待五秒，如果仍在监听，该进程会显示失败提示；警告会说明两分钟内再次点击或右滑关闭将发送 `SIGKILL`。第二次关闭操作就是明确的强制关闭，原有安全保护和身份核验仍然生效。
- **本机还是局域网。** 区分绑在 `127.0.0.1` 的端口和绑在 `0.0.0.0` / 局域网地址上的端口。
- **隐藏端口。** 在 **设置 → 端口 → 隐藏端口** 中添加端口，或右键选择 **隐藏端口**，即可从列表、搜索、菜单栏计数和变化提示音中排除。输入端口后按回车或逗号添加，也可一次粘贴多个端口。已保存的端口显示为标签，点击 × 后恢复显示。服务仍继续运行。
- **外观。** 在 **设置 → 通用** 中选择跟随系统、浅色或深色，同页提供语言、登录启动与声音设置。**项目** 页显示本地地址服务的健康状态。
- **默认安静。** 原生 SwiftUI `MenuBarExtra`。无 Dock 图标，无遥测；除非启用固定地址，否则没有后台服务。唯一离开这台 Mac 的网络请求是每天向 GitHub 查询一次最新版本，可在设置中关闭。
- **固定项目地址。** 为开发服务器分配稳定的 `https://myapp.localhost`，端口变化后自动跟随，由内置的 [Portless](https://github.com/vercel-labs/portless) 提供。详见[下文](#固定项目地址)。
- **说清每个端口的用途。** 一个进程有多个端口时，分别标出 Spring Actuator、应用服务器、网页（取页面标题）、JSON API，或不说 HTTP 的 TCP 端口；只对本机地址发两个有限制的请求。
- **认出构建守护进程和隧道。** Gradle、Kotlin、Maven 守护进程和 sshuttle 显示为工具本身，而不是启动它们的项目目录；“全部关闭”不会动它们。
- **终端里是同一个引擎。** App 附带 `ajar` 命令行工具，推断和安全规则完全一致。

---

## 固定项目地址

开发服务器的端口会变，地址可以不变。Ajar 内置 [Portless](https://github.com/vercel-labs/portless) 0.15.7 和 Node 24.14.0，无需另外安装。

1. **首次设置：** 开启 **设置 → 项目 → 固定地址**。macOS 会请求授权，用于信任本地 CA、在所选代理端口（默认 443）安装只监听本机的 HTTPS 服务，并管理精确的 `/etc/hosts` 条目。只有设置页的明确操作会请求授权；项目操作和后台扫描都不会。
2. **每个项目：** 照常启动项目，在端口详情点击 **启用固定地址**，即可通过 `https://myapp.localhost` 访问。

工作方式：

- **确认后才转发。** 跟随端口变化前，核对项目目录、可执行文件、工作目录、参数摘要和当前监听进程。归属不明确或无关的监听者、仅 HTTPS 的上游和非 Web 端口不会被转发。开发服务器拒绝新主机名时在详情中显示原因，不修改项目文件。
- **启动已停止的项目。** 已保存但未运行的项目有开发脚本时显示 **启动**，使用 Portless 自身的启动器（分配空闲端口、适配框架参数、区分 worktree）。没有开发脚本的项目可在 `.claude/launch.json` 中声明启动命令（`runtimeExecutable`、`runtimeArgs`、`port`），仅在你点击 **启动** 时通过 `portless run` 运行，不经过 shell。`portless.json` 和 `package.json` 的 `"portless"` 字段由 Portless 自身读取。不从进程参数猜启动命令；两者都没有的项目可右键快捷方式选择 **复制给 AI 的设置提示词**，粘贴给编程 agent 来创建 `.claude/launch.json`。
- **短期租约，而非永久规则。** 扫描到的服务使用短期映射，Ajar 停止扫描后失效，下次打开时恢复。停用地址不会停止项目。HTTPS 服务在退出 App 后仍保留；443 已被占用时显示原因，不抢占。
- **供 Agent 与脚本使用：** `ajar url [名称|端口|路径]` 输出已确认的地址（加 `--json` 获取结构化结果），`ajar --json` 为对应服务增加 `fixedURL`。

已有的 HTTP 地址继续可用，可在同一设置页完成 HTTPS 升级。Portless（Apache-2.0）与 Node 随附各自的许可证。

**固定地址设置：** 在「设置 → 项目」一行开启或关闭固定地址，无需手动配置端口。首次设置优先使用 443；冲突时在同一次授权中尝试 8443–8462，成功后记住端口，打开和复制的地址会自动带上它。不会终止其他占用者；无法安全安装时保留错误和可复制诊断。通过 Ajar 启动的项目运行时不自动迁移端口。关闭固定地址会撤下路由，保留绑定、证书和代理，不关闭项目服务器；通过 Ajar 启动的项目需先停止。

---

## 为什么选择 Ajar？（解决的核心痛点）

- **解决端口被占用问题（`EADDRINUSE` / Port in use）**：开发服务启动失败提示端口 3000、5173 或 8080 被占用时，Ajar 让你在菜单栏或终端快速定位残留进程并一键关闭，无需重启终端或 Mac。
- **定位真实项目，告别模糊的 `node` / `python` PID**：`lsof -i` 和普通端口清理脚本只能提供裸 PID 或进程名。Ajar 自动向上追溯工作目录（识别 `package.json`、`Cargo.toml`、`pyproject.toml`、`go.mod`、`.git` 等），显示真实项目名称与应用图标。
- **发现意外的局域网暴露（LAN Exposure）**：清晰区分仅本机可见（`127.0.0.1`）与暴露在局域网（`0.0.0.0` / 网卡 IP）的服务，防止本地开发或测试数据库在公共 Wi-Fi 中无意公开。
- **先给进程正常退出的机会**：优先发送 `SIGTERM`，让服务运行清理钩子与保存状态；仍未停止时，再次点击或右滑关闭会强制结束，同时重新核验 PID、启动时间和受影响端口。

---

## 命令行

安装后即可在终端直接运行：

```bash
# 查看所有监听端口与归属（或 ajar list）
ajar

# 查看指定端口详情
ajar 3000

# 在默认浏览器打开 http://localhost:3000
ajar open 3000

# 输出项目已确认的固定地址（如 https://myapp.localhost）
ajar url myapp

# 安全关闭指定端口（SIGTERM，先确认）
ajar close 3000

# 结构化 JSON 输出
ajar --json
```

输出示例：
```text
AJAR
26 listening ports · 17 processes · 1 projects · 8 LAN-visible

MY PROJECTS (2)
PORT    PID      OWNER          PROCESS    AGE      SCOPE
5173    76344    visdelta       node       2h       LOCAL
         ↳ ~/Documents/visdelta
5511    4999     visdelta       node       27m      LOCAL
         ↳ ~/Documents/visdelta

APPLICATIONS (16)
PORT    PID      OWNER          PROCESS    AGE      SCOPE
5000    696      ControlCenter  Control    3d       LAN
9222    36824    Google Chrome  Chrome     5h       LOCAL

SERVICES (3)
PORT    PID      OWNER          PROCESS    AGE      SCOPE
11434   911      Ollama         ollama     1d       LOCAL

LOCAL = this Mac only · LAN = may be reachable from your local network
```

---

## 构建与测试

```bash
# 运行测试
swift test

# 构建唯一的本地测试 App（.build/local-app.noindex）
Scripts/build-app.sh

# 构建、运行，退出后自动清理
python3 Scripts/dev-app.py run

# 清理仅构建、尚未运行的测试 App
python3 Scripts/dev-app.py clean
```

本地构建名为 **Ajar Test**，使用独立 bundle ID，不会安装到 `/Applications`。清理只处理脚本管理的输出目录，发现 App 或内置进程仍在运行时会拒绝删除，请先退出测试版。固定地址服务和其他用户数据不会被重置。CI 与正式打包继续显式指定 `AJAR_OUTPUT_DIR`；日常测试请勿再生成多个 `dist/` 版本目录。

---

## 许可证

[MIT License](LICENSE)

## 卸载

完整卸载请使用 **Ajar → 设置 → 关于 → 卸载 Ajar…**。只删除 App 会留下固定地址服务、证书和配置；
如果已删除，请重新构建后使用应用内卸载功能。详见[完整卸载说明](docs/uninstall.md)。

## 从 LeftOpen 迁移

Ajar 使用自己的标识（`io.github.boyongjiong.ajar.*`），可以和 LeftOpen 同时存在，不会碰 LeftOpen
的服务、证书和 `/etc/hosts` 条目。首次启动时，Ajar 会导入 LeftOpen 的偏好设置（语言、外观、隐藏端口、
刷新间隔等）；固定地址需要在 Ajar 中重新设置。要移除 LeftOpen 的后台服务，请在删除前使用 LeftOpen 自己的卸载功能。

## 致谢

Ajar fork 自 [Songhai Fan](https://github.com/SonghaiFan) 创建的 [LeftOpen](https://github.com/SonghaiFan/leftopen)，
沿用其 MIT 许可证。固定地址功能由 [Portless](https://github.com/vercel-labs/portless)（Apache-2.0）提供。
