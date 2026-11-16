#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> [1/3] 检查代码库敏感路径与个人绝对路径..."
# 检查源代码文件（Swift、Python、Shell脚本）是否含有硬编码个人绝对路径
ILLEGAL_PATHS=$(git grep -EI "/Users/" -- 'Sources/' 'bridge/' 'scripts/' ':!scripts/verify_clean.sh' || true)
if [ -n "$ILLEGAL_PATHS" ]; then
    echo "❌ 错误：在代码中检测到硬编码个人绝对路径 (/Users/)："
    echo "$ILLEGAL_PATHS"
    echo "请使用相对路径、Path.home() 或环境变量进行动态推导！"
    exit 1
fi
echo "  ✓ 零硬编码绝对路径通过"

echo "==> [2/3] 检查 Python 桥接层语法完整性..."
python3 -m py_compile bridge/kaze_bridge.py
echo "  ✓ Python 桥接代码编译语法通过"

echo "==> [3/3] 检查关键工程配置完整性..."
test -f "Package.swift" || { echo "❌ 缺少 Package.swift"; exit 1; }
test -f "bridge/requirements.txt" || { echo "❌ 缺少 bridge/requirements.txt"; exit 1; }
test -f "scripts/build_app.sh" || { echo "❌ 缺少 scripts/build_app.sh"; exit 1; }
echo "  ✓ 工程关键配置文件齐全"

echo "🎉 本地代码库质量与隐私巡检全部通过！"
