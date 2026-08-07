#!/usr/bin/env bash
#
# SmartTable 本地一键启动脚本（无需 Docker）
#
# 启动：
#   ./start-local.sh
# 停止：按 Ctrl+C（会自动结束后端与前端的进程）
#
# 说明：
#   - 后端：smarttable-backend/venv/bin/python run.py  (http://localhost:5000)
#   - 前端：smart-table pnpm run dev                  (http://localhost:3000)
#   - 浏览器访问前端 http://localhost:3000 即可使用
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/smarttable-backend"
FRONTEND_DIR="$ROOT_DIR/smart-table"
BACKEND_LOG="$BACKEND_DIR/logs/backend.log"

BACKEND_PID=""
FRONTEND_PID=""

cleanup() {
  echo
  echo "▶ 正在停止服务..."
  [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" 2>/dev/null || true
  [[ -n "$FRONTEND_PID" ]] && kill "$FRONTEND_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  echo "✅ 已停止"
}
trap cleanup EXIT INT TERM

# ---- 后端 ----
if [[ ! -x "$BACKEND_DIR/venv/bin/python" ]]; then
  echo "❌ 未找到后端虚拟环境: $BACKEND_DIR/venv/bin/python"
  echo "   请先创建 venv 并安装依赖："
  echo "     cd $BACKEND_DIR"
  echo "     python -m venv venv"
  echo "     source venv/bin/activate"
  echo "     pip install -r requirements-local.txt"
  exit 1
fi

mkdir -p "$(dirname "$BACKEND_LOG")"
echo "▶ 启动后端  (http://localhost:5000)  [日志: $BACKEND_LOG]"
"$BACKEND_DIR/venv/bin/python" "$BACKEND_DIR/run.py" > "$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!

# ---- 前端 ----
if ! command -v pnpm >/dev/null 2>&1; then
  echo "❌ 未找到 pnpm，请先安装：npm i -g pnpm"
  exit 1
fi
if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
  echo "▶ 首次运行，安装前端依赖 (pnpm install) ..."
  (cd "$FRONTEND_DIR" && pnpm install)
fi

echo "▶ 启动前端  (http://localhost:3000)"
(cd "$FRONTEND_DIR" && pnpm run dev) &
FRONTEND_PID=$!

echo
echo "✅ 服务启动中..."
echo "   前端 UI:  http://localhost:3000   (请用浏览器打开这个)"
echo "   后端 API: http://localhost:5000/api"
echo "   API 文档: http://localhost:5000/apidocs"
echo "   后端日志: tail -f $BACKEND_LOG"
echo "   按 Ctrl+C 停止全部服务"
echo

# 以前端进程为主，前端退出时脚本随之退出并由 trap 清理后端
wait "$FRONTEND_PID"
