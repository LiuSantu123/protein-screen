#!/usr/bin/env bash
# Run from a clone. Requires only bash, curl, sha256sum on Linux x86_64.
set -euo pipefail
SCREEN_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  cat <<'HELP'
Usage: bash install.sh [--prefix DIR] [--conda EXECUTABLE] [installer options]
  --models all|evoef2,netsolp,...  Default: all nine models
  --stage all|sources|envs|weights|config|check  Default: all
  --plan                        Print plan without downloading or writing
  --msms-bin PATH --apbs-bin PATH --multivalue-bin PATH
  --netsolp-models DIR           Official downloaded ONNX/alphabet directory
  --gatsol-checkpoint PATH       Optional already downloaded best_model.tar.gz
  --pro4s-checkpoint PATH        Optional already downloaded finetune.ckpt
Set HF_TOKEN for gated Hugging Face downloads after obtaining upstream access.
See docs/install_zh.md for licenses, disk/network requirements and smoke tests.
HELP
  exit 0
fi
SCREEN_PREFIX=${SCREEN_INSTALL_PREFIX:-$SCREEN_REPO/.local/install}
SCREEN_CONDA=${SCREEN_CONDA_EXE:-}
SCREEN_ARGS=()
SCREEN_PLAN=0
while (( $# )); do
  case "$1" in
    --prefix) SCREEN_PREFIX=$2; shift 2 ;;
    --conda) SCREEN_CONDA=$2; shift 2 ;;
    --plan) SCREEN_PLAN=1; SCREEN_ARGS+=("$1"); shift ;;
    *) SCREEN_ARGS+=("$1"); shift ;;
  esac
done
if (( SCREEN_PLAN )); then
  printf 'Prefix: %s\nConda: %s\nModels/stages: %s\n' "$SCREEN_PREFIX" "${SCREEN_CONDA:-auto-detect or bootstrap Miniforge}" "${SCREEN_ARGS[*]}"
  printf '%s\n' 'Stages: verified sources -> isolated environments -> external weights -> launcher/config -> readiness checks.'
  exit 0
fi
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'This installer supports Linux x86_64 only.' >&2; exit 1; }
mkdir -p -- "$SCREEN_PREFIX"
SCREEN_PREFIX=$(cd -- "$SCREEN_PREFIX" && pwd)
if [[ -z "$SCREEN_CONDA" ]]; then
  SCREEN_CONDA=$(command -v conda || true)
fi
if [[ -z "$SCREEN_CONDA" ]]; then
  SCREEN_CONDA=$SCREEN_PREFIX/miniforge/bin/conda
  if [[ ! -x "$SCREEN_CONDA" ]]; then
    SCREEN_MINIFORGE=26.5.3-0
    # Official 26.5.3-0 release asset; API route avoids github.com redirect timeouts.
    SCREEN_URL=https://api.github.com/repos/conda-forge/miniforge/releases/assets/515673576
    mkdir -p -- "$SCREEN_PREFIX/downloads"
    curl -fL --retry 3 --connect-timeout 30 -H "Accept: application/octet-stream" "$SCREEN_URL" -o "$SCREEN_PREFIX/downloads/Miniforge3-Linux-x86_64.sh"
    SCREEN_MINIFORGE_SHA256=14db468222ad564658656f769506056209b6dc375f5e7dfd31eb5ebbf08fa529
    (cd -- "$SCREEN_PREFIX/downloads" && printf '%s  %s\n' "$SCREEN_MINIFORGE_SHA256" Miniforge3-Linux-x86_64.sh | sha256sum -c -)
    bash "$SCREEN_PREFIX/downloads/Miniforge3-Linux-x86_64.sh" -b -p "$SCREEN_PREFIX/miniforge"
  fi
fi
SCREEN_BASE=$("$SCREEN_CONDA" info --base)
SCREEN_CONDA=$SCREEN_BASE/bin/conda
"$SCREEN_BASE/bin/python" "$SCREEN_REPO/scripts/install.py" --prefix "$SCREEN_PREFIX" --conda "$SCREEN_CONDA" "${SCREEN_ARGS[@]}" 2>&1 | tee -a "$SCREEN_PREFIX/install.log"
