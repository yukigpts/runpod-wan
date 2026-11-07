#!/bin/bash
# RunPod ComfyUI (runpod/comfyui テンプレ) で MiniMax H3 (T2V / I2V / R2V) を回す一発セットアップ v1
#
# 使い方（RunPod の Jupyter → Terminal で 1 行）:
#   curl -sL https://raw.githubusercontent.com/yukigpts/runpod-wan/main/setup_h3.sh | bash
#
# やること: ComfyUI 更新 → H3 モデル一式を Comfy-Org/MiniMax-H3 から DL → ComfyUI 再起動
# モデル合計 約60GB（fl2va 約20GB / ref2va 約20GB / テキストエンコーダ 約17GB / VAE / LoRA）。
# 75MB/s なら 15 分前後。Container Disk は 150GB 以上にしておく。
#
# ワークフローは ComfyUI 内蔵テンプレ「MiniMax H3」(T2V / I2V / R2V) をそのまま使う。JSON の持ち込み不要。
#
# R2V（キャラ参照）が要らないときは下の WITH_R2V=0 にすると 20GB 減る。
set -e

# ======== 設定 ========
WITH_R2V=1
WITH_TURBO_LORA=1
# ======================

# ---- ComfyUI の場所 ----
if [ -d /workspace/runpod-slim/ComfyUI ]; then
  COMFY=/workspace/runpod-slim/ComfyUI
elif [ -d /workspace/ComfyUI ]; then
  COMFY=/workspace/ComfyUI
else
  COMFY=$(find / -maxdepth 4 -type d -name ComfyUI -path "*workspace*" 2>/dev/null | head -1)
fi
echo "ComfyUI: $COMFY"

# ---- venv の python ----
PY=$(ls -d $COMFY/.venv*/bin/python 2>/dev/null | head -1)
[ -z "$PY" ] && PY=$(which python3)
echo "python: $PY"

# ---- 起動引数を控える ----
ORIG_ARGS=$(ps -eo args | grep "[m]ain.py" | head -1 | sed 's/^[^ ]*python[^ ]* //')
[ -z "$ORIG_ARGS" ] && ORIG_ARGS="main.py --listen 0.0.0.0 --port 8188 --enable-cors-header"
echo "起動引数: $ORIG_ARGS"

# ---- 1. ComfyUI 本体を最新に（H3 はノードが新しいので必須）----
echo "== ComfyUI 更新 =="
cd $COMFY
git fetch -q origin
git reset -q --hard origin/master
$PY -m pip install -q -r requirements.txt 2>&1 | grep -v notice || true

# ---- 2. H3 モデル ----
echo "== H3 モデル DL =="
cd $COMFY/models
mkdir -p diffusion_models text_encoders vae loras
BASE=https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main
dl () {
  # dl <subfolder> <filename> [<full url>]
  local url="${3:-$BASE/$1/$2}"
  if [ -f "$1/$2" ]; then echo "skip $2"; else
    wget -q --show-progress -c -O "$1/$2" "$url"
  fi
}
dl diffusion_models minimax_h3_fl2va_pruned_int8_convrot.safetensors
dl text_encoders    qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors
dl vae              minimax_h3_video_vae_int8_convrot.safetensors
dl vae              minimax_h3_audio_vae_fp32.safetensors
if [ "$WITH_R2V" = "1" ]; then
  dl diffusion_models minimax_h3_ref2va_pruned_int8_convrot.safetensors
fi
if [ "$WITH_TURBO_LORA" = "1" ]; then
  dl loras minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors \
     https://huggingface.co/lightx2v/Minimax-h3-Turbo/resolve/main/minimax_h3_fl2v_turbo_8step_v1.0_comfyui_bf16.safetensors
  [ "$WITH_R2V" = "1" ] && dl loras minimax_h3_ref2v_turbo_4step_v0.1_comfyui_bf16.safetensors
fi

# ---- 3. /workspace に手置きした json があれば workflows に配置（任意）----
mkdir -p $COMFY/user/default/workflows
for f in /workspace/*.json; do
  [ -f "$f" ] && cp -f "$f" $COMFY/user/default/workflows/ && echo "workflow: $(basename $f)"
done

# ---- 4. ComfyUI 再起動 ----
echo "== ComfyUI 再起動 =="
pkill -f "main.py" || true
sleep 3
cd $COMFY
nohup $PY $ORIG_ARGS > /workspace/comfy_restart.log 2>&1 &

# ---- 5. 起動待ち ----
echo -n "起動待ち"
for i in $(seq 1 60); do
  if curl -s -o /dev/null http://127.0.0.1:8188/; then
    echo; echo "== ComfyUI 起動確認 OK。8188 を開いて テンプレート → MiniMax H3 =="; exit 0
  fi
  echo -n "."; sleep 3
done
echo; echo "== 3分待っても応答なし。tail -30 /workspace/comfy_restart.log を確認 =="
