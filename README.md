# runpod-wan

RunPod の ComfyUI テンプレートに、MiniMax H3 と Wan Animate 2 を一発で入れるセットアップスクリプトです。

使い方は、RunPod で Pod を立てたあと、Jupyter Lab の Terminal で 1 行貼るだけです。

MiniMax H3（T2V / I2V / R2V）

    curl -sL https://raw.githubusercontent.com/yukigpts/runpod-wan/main/setup_h3.sh | bash

Wan Animate 2（人物置き換え）

    curl -sL https://raw.githubusercontent.com/yukigpts/runpod-wan/main/setup_wan_animate2.sh | bash

両方入れたい場合は、1 本目が終わってから 2 本目を実行してください。

## 前提

- テンプレート: RunPod 公式「ComfyUI - CUDA 13.0」
- GPU: RTX 4090（VRAM 24GB）を想定
- Container Disk: 150GB 以上（両方入れるなら 150GB 必要）
- Network Volume は不要

## やっていること

- ComfyUI 本体を最新版に更新
- 必要なカスタムノード（VideoHelperSuite）を導入（Wan 用）
- モデルファイルを Hugging Face からダウンロードして models/ 配下に配置
- ワークフロー JSON を user/default/workflows/ に配置（Wan 用）
- ComfyUI を再起動

モデルはすべて公開リポジトリ（Comfy-Org、lightx2v）から取得しています。このリポジトリにはモデル本体は含まれていません。

## ファイル

- setup_h3.sh … MiniMax H3 のセットアップ
- setup_wan_animate2.sh … Wan Animate 2 のセットアップ
- wan_animate2.json … Wan Animate 2 のワークフロー（VHS Load Video 差し替え済み、10 秒・720x1280）

## 使い終わったら

Pod は必ず Terminate してください。Stop ではディスク代がかかり続けます。

## 注意

各モデルのライセンスは、それぞれの Hugging Face ページを確認してください。RunPod の料金やテンプレートの仕様は変わることがあります。
