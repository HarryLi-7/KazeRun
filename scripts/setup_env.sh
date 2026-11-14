#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> 正在为 KazeRun 创建 Python 虚拟环境 (bridge/.venv)..."
if [ ! -d "bridge/.venv" ]; then
    python3 -m venv bridge/.venv
fi

echo "==> 安装 / 更新 Python 依赖..."
./bridge/.venv/bin/pip install --upgrade pip
./bridge/.venv/bin/pip install -r bridge/requirements.txt

echo "==> Python 桥接环境就绪！可运行 ./scripts/build_app.sh 打包应用。"
