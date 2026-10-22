#!/usr/bin/env bash
# Converts Whisper-Hindi2Hinglish-Swift (Hugging Face) to whisper.cpp ggml
# files: f16, q5_1 and q8_0, written to models/.
set -euo pipefail

WHISPER_CPP_TAG="v1.9.5"
HF_REPO="Oriserve/Whisper-Hindi2Hinglish-Swift"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/tools"
CACHE="$TOOLS/.cache"
VENV="$TOOLS/.venv"
OUT="$ROOT/models"
mkdir -p "$CACHE" "$OUT"

if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --upgrade pip
  "$VENV/bin/pip" install -q torch --index-url https://download.pytorch.org/whl/cpu
  "$VENV/bin/pip" install -q transformers numpy huggingface_hub cmake
fi
PY="$VENV/bin/python"

HF_DIR="$CACHE/swift-hf"
if [ ! -f "$HF_DIR/model.safetensors" ]; then
  "$PY" - "$HF_REPO" "$HF_DIR" <<'EOF'
import sys
from huggingface_hub import snapshot_download
snapshot_download(sys.argv[1], local_dir=sys.argv[2], allow_patterns=[
    "*.json", "*.txt", "model.safetensors"])
EOF
fi

if [ ! -d "$CACHE/whisper.cpp" ]; then
  git clone -q --depth 1 --branch "$WHISPER_CPP_TAG" \
    https://github.com/ggml-org/whisper.cpp "$CACHE/whisper.cpp"
fi
if [ ! -d "$CACHE/whisper" ]; then
  git clone -q --depth 1 https://github.com/openai/whisper "$CACHE/whisper"
fi

if [ ! -f "$OUT/ggml-swift-f16.bin" ]; then
  "$PY" "$CACHE/whisper.cpp/models/convert-h5-to-ggml.py" \
    "$HF_DIR" "$CACHE/whisper" "$CACHE"
  mv "$CACHE/ggml-model.bin" "$OUT/ggml-swift-f16.bin"
fi

BUILD="$CACHE/whisper.cpp/build"
if [ ! -x "$BUILD/bin/whisper-quantize" ]; then
  "$VENV/bin/cmake" -S "$CACHE/whisper.cpp" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_SDL2=OFF
  "$VENV/bin/cmake" --build "$BUILD" -j"$(nproc)" --target whisper-cli whisper-quantize
fi

for q in q5_1 q8_0; do
  [ -f "$OUT/ggml-swift-$q.bin" ] ||
    "$BUILD/bin/whisper-quantize" "$OUT/ggml-swift-f16.bin" "$OUT/ggml-swift-$q.bin" "$q"
done

ls -la "$OUT"/ggml-swift-*.bin
