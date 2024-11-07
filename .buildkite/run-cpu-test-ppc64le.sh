#!/bin/bash

# This script build the CPU docker image and run the offline inference inside the container.
# It serves a sanity check for compilation and basic model usage.
set -ex

# Setup cleanup
remove_docker_container() { docker rm -f cpu-test || true; docker system prune -f; }
trap remove_docker_container EXIT
remove_docker_container

# Try building the docker image
docker build -t cpu-test -f Dockerfile.ppc64le .

# Run the image, setting --shm-size=4g for tensor parallel.
source /etc/environment
#docker run -itd --entrypoint /bin/bash -v ~/.cache/huggingface:/root/.cache/huggingface --privileged=true --network host -e HF_TOKEN --env VLLM_CPU_KVCACHE_SPACE=4 --shm-size=4g --name cpu-test cpu-test
docker run -itd --entrypoint /bin/bash -v ~/.cache/huggingface:/root/.cache/huggingface --privileged=true --network host -e HF_TOKEN="$HF_TOKEN" --name cpu-test cpu-test

# Run basic model test
docker exec cpu-test bash -c "
<<<<<<< HEAD
  pip install pytest matplotlib einops transformers_stream_generator datamodel_code_generator
  pytest -v -s tests/models/decoder_only/language \
    --ignore=tests/models/test_fp8.py \
    --ignore=tests/models/decoder_only/language/test_jamba.py \
    --ignore=tests/models/decoder_only/language/test_danube3_4b.py" # Mamba and Danube3-4B on CPU is not supported

# Run compressed-tensor test
#docker exec cpu-test bash -c "
#  pytest -s -v \
#  tests/quantization/test_compressed_tensors.py::test_compressed_tensors_w8a8_static_setup \
#  tests/quantization/test_compressed_tensors.py::test_compressed_tensors_w8a8_dynanmic_per_token"
=======
  pip install pytest matplotlib einops transformers_stream_generator
  pytest -v -s tests/models -m \"not vlm\" \
    --ignore=tests/models/test_embedding.py \
    --ignore=tests/models/test_oot_registration.py \
    --ignore=tests/models/test_registry.py \
    --ignore=tests/models/test_jamba.py \
    --ignore=tests/models/test_mamba.py \
    --ignore=tests/models/test_danube3_4b.py" # Mamba kernels and Danube3-4B on CPU is not supported
>>>>>>> 7342a7d7... [Model] Support Mamba (#6484)

# online inference
docker exec cpu-test bash -c "
  python3 -m vllm.entrypoints.openai.api_server --model facebook/opt-125m & 
  timeout 600 bash -c 'until curl localhost:8000/v1/models; do sleep 1; done' || exit 1
  python3 benchmarks/benchmark_serving.py \
    --backend vllm \
    --dataset-name random \
    --model facebook/opt-125m \
    --num-prompts 20 \
    --endpoint /v1/completions \
    --tokenizer facebook/opt-125m"
