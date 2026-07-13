#!/bin/bash
set -eo pipefail

. /venv/main/bin/activate
pip install diffusers transformers redis upstash_redis boto3 requests

# 下载 gpu_server 脚本
curl -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3.raw" \
     -L \
     -o /workspace/gpu_server_autodl_r2.py \
     "https://api.github.com/repos/ljkrock/vastsh/contents/gpu_server_autodl_r2.py"

# 1. 先下载模型（顺序执行，只下载一次）
/venv/main/bin/python -c "
from diffusers import ZImagePipeline
import torch
pipe = ZImagePipeline.from_pretrained('Tongyi-MAI/Z-Image-Turbo', torch_dtype=torch.bfloat16, low_cpu_mem_usage=False)
pipe.save_pretrained('/workspace/models/zimage')
print('Model download done.')
"

# 2. 模型下载完后，为每张卡启动一个 worker
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

for i in $(seq 0 $((GPU_COUNT - 1))); do
  echo "[program:gpu-worker-$i]
command=/venv/main/bin/python /workspace/gpu_server_autodl_r2.py
environment=GPU_INDEX=\"$i\"
autostart=true
autorestart=true" > /etc/supervisor/conf.d/gpu-worker-$i.conf
done

supervisorctl reload