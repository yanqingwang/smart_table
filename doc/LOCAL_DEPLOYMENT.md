# SmartTable 本地部署手册（无需 Docker）

本手册说明如何在不依赖 Docker / Redis / PostgreSQL 的情况下，在本地完整启动 SmartTable 前后端。适用于开发调试、本地试用。

> 版本：基于 v1.6.3 本地化改造（去除 Redis 硬依赖、pandas 替换为 polars）。
> 对应提交：`4e93f7d`（分支 `local-start-optimizations`）。

---

## 1. 环境要求

| 组件      | 版本要求            | 说明                                  |
| ------- | --------------- | ----------------------------------- |
| Python  | >= 3.11（实测 3.14.6） | 仅后端需要；建议用 venv 隔离                |
| Node.js | >= 18           | 前端构建运行环境                           |
| pnpm    | >= 9            | 前端包管理（`npm i -g pnpm` 安装）          |

> Redis 与 PostgreSQL **不再需要**：默认缓存为 `SimpleCache`，数据库默认 `SQLite`。

---

## 2. 目录结构（关键部分）

```
smart_table/
├── smart-table/            # 前端（Vue 3 + Vite）
├── smarttable-backend/     # 后端（Flask）
│   ├── venv/               # 本地虚拟环境（已 gitignore）
│   ├── requirements-local.txt  # 本地最简依赖清单
│   ├── .env                # 本地环境配置（已生成）
│   └── run.py              # 启动入口
└── doc/
    ├── LOCAL_DEPLOYMENT.md # 本手册
    └── 工作日志.md           # 改造工作记录
```

---

## 3. 后端启动

```bash
cd smarttable-backend

# （若 venv 尚未创建）创建并激活虚拟环境
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# 安装本地依赖（已去除 pandas / psycopg2，改用 polars）
pip install -r requirements-local.txt

# 准备本地环境配置（如不存在）
cp .env.example .env
# 默认即为 SQLite + SimpleCache + 关闭验证码，无需额外修改

# 初始化数据库（Alembic 迁移，首次会建表）
flask db upgrade

# 启动开发服务器（默认端口 5000，不启用实时协作）
python run.py
```

### 关键提示

- **必须使用 venv 内的 Python**。直接用系统 `python` 会报 `ModuleNotFoundError: No module named 'flasgger'` 等缺失模块：
  ```bash
  ./venv/bin/python run.py        # 推荐：显式使用 venv 解释器
  # 或先 source venv/bin/activate 再 python run.py
  ```
- 首次启动会自动创建默认管理员账号（`ldengbin@126.com` / `LDengBin@126.com`）。
- API 文档（Swagger）：`http://localhost:5000/apidocs`
- 健康检查：`http://localhost:5000/api/health`

### 本地相关环境变量（`.env`）

| 变量                    | 默认值        | 说明                              |
| --------------------- | ---------- | ------------------------------- |
| `DATABASE_URL`        | SQLite     | 本地默认即可，无需 PostgreSQL           |
| `CACHE_TYPE`          | `SimpleCache` | 设为 `RedisCache` 才启用 Redis        |
| `LOGIN_CAPTCHA_ENABLED` | `false`（本地） | `true` 开启登录验证码；本地调试建议关闭     |
| `ENABLE_REALTIME`     | `false`    | 设为 `true` 启用 WebSocket 实时协作     |
| `FRONTEND_URL`        | `http://localhost:3000` | 仅开发模式：访问后端根路径 `/` 时重定向到此地址 |

### 访问地址说明

- **前端应用（UI）**：`http://localhost:3000` ← 浏览器应访问这个
- **后端 API 基址**：`http://localhost:5000/api`
- **后端根路径 `/`**：开发模式下会自动 **302 重定向** 到前端 `:3000`（不再返回裸 404）
- **API 文档（Swagger）**：`http://localhost:5000/apidocs`
- **API 文档（自定义页）**：`http://localhost:5000/api/`
- **健康检查**：`http://localhost:5000/api/health`

---

## 4. 前端启动

```bash
cd smart-table

# 安装依赖（仅首次）
pnpm install

# 开发模式（默认端口 3000，自动代理 /api -> http://localhost:5000）
pnpm run dev
```

- 访问地址：`http://localhost:3000`
- Vite 已配置将 `/api` 请求代理到后端 `http://localhost:5000`，因此前端无需单独配置后端地址。
- 构建生产版本：`pnpm run build`；本地预览：`pnpm run preview`

---

## 5. 一键本地启动（速查）

开两个终端：

```bash
# 终端 1 —— 后端 :5000
cd smarttable-backend && ./venv/bin/python run.py

# 终端 2 —— 前端 :3000
cd smart-table && pnpm run dev
```

浏览器打开 `http://localhost:3000`，使用默认账号登录即可。

---

## 6. 常见问题

### Q1: 启动报 `ModuleNotFoundError: No module named 'flasgger'`
说明用的是系统 Python 而非 venv。请先 `source venv/bin/activate`，或改用 `./venv/bin/python run.py`。
（若 venv 未安装依赖，先执行 `pip install -r requirements-local.txt`。）

### Q2: 想用 PostgreSQL / Redis 怎么办？
- 数据库：在 `.env` 设置 `DATABASE_URL=postgresql://user:pass@localhost:5432/smarttable`，并执行 `flask db upgrade`。
- 缓存：设置 `CACHE_TYPE=RedisCache` 与 `REDIS_URL`，并确保本地有 Redis 服务。

### Q3: 导入/导出格式支持哪些？
支持 Excel（`.xlsx`）与 CSV（含 `gbk` 编码回退）。底层已切换为 `polars` + `fastexcel` + `xlsxwriter`。

### Q4: 端口被占用？
- 后端端口在 `run.py` 中配置（默认 5000）。
- 前端端口在 `smart-table/vite.config.ts` 的 `server.port`（默认 3000）。修改后需同步调整 Vite 代理目标。
