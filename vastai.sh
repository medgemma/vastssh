#!/bin/bash
set -eo pipefail

# 1. 安装 pip 包
. /venv/main/bin/activate
pip install diffusers transformers redis upstash_redis boto3 requests

# # 2. 下载 HuggingFace 模型（启动时一次性）
# python -c "from diffusers import ... ; model.save_pretrained('/workspace/model')"
# 用 GitHub token 下载私有仓库文件
curl -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3.raw" \
     -L \
     -o /workspace/gpu_server_autodl_r2.py \
     "https://api.github.com/repos/ljkrock/vastsh/contents/gpu_server_autodl_r2.py"
     
# 3. 将你的长期运行服务注册到 supervisor
echo "[program:gpu-worker]
command=/venv/main/bin/python /workspace/gpu_server_autodl_r2.py
autostart=true
autorestart=true" > /etc/supervisor/conf.d/gpu-worker.conf

supervisorctl reload