#!/bin/bash
echo "===== CHECK ====="
echo "CONTAINER_ID=$CONTAINER_ID"
echo "VAST_CONTAINERLABEL=$VAST_CONTAINERLABEL"
env | grep -E 'VAST|CONTAINER'
echo "================="
set -eo pipefail

. /venv/main/bin/activate
pip install diffusers transformers redis upstash_redis boto3 requests

# 读取实例 ID（用于追踪）
INSTANCE_ID=$(cat ~/.vast_containerlabel 2>/dev/null || echo "unknown")

# 下载 gpu_server 脚本
curl -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3.raw" \
     -L \
     -o /workspace/gpu_server_autodl_r2.py \
     "https://api.github.com/repos/ljkrock/vastsh/contents/gpu_server_autodl_r2.py"

# 下载模型（只下载一次，后续worker加载时命中HuggingFace缓存）
/venv/main/bin/python -c "
from diffusers import ZImagePipeline
import torch
ZImagePipeline.from_pretrained('Tongyi-MAI/Z-Image-Turbo', torch_dtype=torch.bfloat16, low_cpu_mem_usage=False)
print('Model download done.')
"


# 为每张卡启动一个 worker
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)

for i in $(seq 0 $((GPU_COUNT - 1))); do
  echo "[program:gpu-worker-$i]
command=/venv/main/bin/python /workspace/gpu_server_autodl_r2.py --gpu $i --pop-direction l --instance-id $INSTANCE_ID
autostart=true
autorestart=true" > /etc/supervisor/conf.d/gpu-worker-$i.conf
done

supervisorctl reload
