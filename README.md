# VPS-SH

Debian 12+ / Ubuntu 22.04+ 系统运维与 Docker 应用管理工具。专为高效率人机协同与 AI 自动化设计。

```bash
curl -fsSL https://raw.githubusercontent.com/666OS/vps-sh/main/vps.sh | bash
```
> 首次运行自动注册全局命令 `vs`，后续直接输入 `vs` 呼出控制台。

---

## AI 协同 (AI-Native)

* **诊断快照 (`vs ai`)**：生成包含系统运行状态与可用修复指令的高密度纯文本（~250 Token），可直接复制发给大模型（ChatGPT / Claude / DeepSeek）以获取准确的官方指令建议。
* **Agent 自动化 (`vs ai --json`)**：输出单行结构化 JSON，供自主智能体（Cursor、Antigravity、Claude Code 等）极速读取机器状态，配合内置安全护栏执行非交互闭环运维。
* **语义指令标准**：根目录提供标准 [llms.txt](llms.txt)，供大模型直接理解完整的 CLI 指令集与安全规范。

---

## 模块

* **系统**：Swap 弹性伸缩、系统时区、主机名持久化、内核与 BBR 调优、组件更新。
* **网络**：公共 DNS 切换、IPv4/IPv6 出站优先级、回程路由诊断。
* **安全**：SSH 密钥加固与端口配置、Root/密码锁、Fail2ban 防爆破、iptables 防火墙。
* **运维**：端口监听审查、磁盘大文件扫描、系统日志与缓存清理、定时任务。
* **应用**：Compose 模板拉取部署、状态监控、数据隔离挂载 (`/opt/vps-sh/apps/<name>/data`)。
* **容器**：Docker 与 Compose 环境安装、镜像加速源配置、容器管理与无损清理。

---

## CLI

```bash
vs ai                     # 导出系统诊断快照与可用指令
vs ai --json              # 导出结构化机器状态 JSON
vs sys_swap 2048          # 配置 2GB Swap
vs sys_tune               # 开启 BBR 与性能调优
vs net_dns_foreign        # 配置国外双栈 DNS
vs sec_port 2222          # 修改 SSH 端口
vs sec_lock_pwd           # 禁用密码登录 (仅限密钥)
vs fw_open 80 443 8080    # 放行指定端口
vs fw_ddos on             # 开启防 DDoS 限流
vs docker_install         # 安装 Docker & Compose
vs docker_mirror_fast     # 切换镜像加速
vs app_install hello-world 8080 # 部署应用 (指定端口)
vs app_update hello-world       # 更新应用
vs rm                     # 卸载工具
```

---

## 应用源与本地扩展

* **应用模板**：由 [`666OS/vps-apps`](https://github.com/666OS/vps-apps) 提供 Docker Compose 模板，控制台选择 `[5] 应用市场` 即可拉取部署。
* **本地热插拔**：在服务器 `/opt/vps-sh/apps/<name>/` 放置 `compose.yaml`，引擎自动识别并纳管启动、停止、重启与日志。
* **自定义应用源**：支持通过环境变量或配置切换自建市场源：
  ```bash
  export VPS_APP_FEED="https://raw.githubusercontent.com/<user>/vps-apps/main"
  ```

---

## 协议

[GPL-3.0](LICENSE)
