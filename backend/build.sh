#!/usr/bin/env bash
set -o errexit

echo "📦 Preparing Python 3.12 build environment..."
pip install --upgrade pip setuptools wheel

# Install uv if available or use pip
if ! command -v uv >/dev/null 2>&1; then
  echo "⚡ Installing uv package manager..."
  curl -LsSf https://astral.sh/uv/install.sh | sh || true
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

if command -v uv >/dev/null 2>&1; then
  echo "⚡ Installing dependencies with uv..."
  uv pip install --system -r requirements.txt || pip install -r requirements.txt
else
  echo "📦 Installing dependencies with pip..."
  pip install -r requirements.txt
fi

echo "✅ Build completed successfully!"
