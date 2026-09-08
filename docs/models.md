# Model installation and configuration

The package contains integration code, not pretrained models. Install upstream
repositories at a fixed revision and obtain weights under their respective
licenses. Fill in `paths` in a JSON config; unconfigured paths fail explicitly.
`*_py` defaults to the current Python except when configured. It is usually
necessary to set it for each external environment. The bundled ESM and
TemBERTure runners are selected automatically, or overridden via `*_run`.

| Model | Upstream | Required path keys | Output |
|---|---|---|---|
| NetSolP | https://github.com/teevee112/NetSolP-1.0 | `netsolp_py`, `netsolp` (PredictionServer/predict.py), `netsolp_models` (PredictionServer/models) | predicted_solubility |
| RP3Net | https://github.com/RP3Net/RP3Net | `rp3net_py`, `rp3_repo`, `rp3_src` (repo/src), `rp3_ckpt` (weights/rp3net_v0.1_d.ckpt) | score |
| TemBERTure | https://github.com/ibmm-unibe-ch/TemBERTure | `temberture_py`, `temberture_models` (directory containing temBERTure_TM and temBERTure_CLS) | ensemble Tm, classification |
| TemStaPro | https://github.com/ievapudz/TemStaPro | `temstapro_py`, `temstapro` (entry script), `temstapro_dir` (repo), `prottrans` (local ProtTrans model) | t40/t55/t65 predictions |
| ESMC | https://github.com/evolutionaryscale/esm | `esmc_py` (ESM SDK environment) | masked pseudo-perplexity |
| ESM3 | https://github.com/evolutionaryscale/esm | `esm3_py` (ESM SDK environment) | masked pseudo-perplexity |
| GATSol | https://github.com/binbinbinv/GATSol | `gatsol_py`, `gatsol_repo`, `gatsol_ckpt` | Solubility_hat |
| Pro4S | https://github.com/TEKHOO/Pro4S | `pro4s_py`, `pro4s_root`, `masif_py` | Prediction |
| EvoEF2 | https://github.com/tommyhuangthu/EvoEF2 | `evoef2` (compiled executable) | ComputeStability Total |

## Modern inference environment

`conda env create -f envs/models.yml` provides a starting dependency recipe for
the modern PyTorch adapters, based on the original installation versions. It
is **not a verified fresh installation of all models**. Install each upstream
repository's remaining dependencies, then run its own smoke test before using
the adapter. The release controller environment and exact tested scope are
recorded separately in `validation.md`.

RP3Net is invoked with `python -m RP3Net.rp3_main` and its `src` directory is
added to PYTHONPATH. To use the same repository layout:

```bash
git clone https://github.com/RP3Net/RP3Net external/RP3Net
conda run -n screen-models pip install -e external/RP3Net
```

Its current upstream dependency pins may differ from the starting recipe; use
the upstream pins in an isolated environment when necessary. Set `rp3net_py`
to that interpreter. NetSolP uses the upstream `PredictionServer/predict.py` contract. A local
`predict_v2.py` with the same CLI is also supported; no private wrapper is required.

For GATSol/Pro4S install the PyG compiled wheels matching your Torch/CUDA ABI
if required by your upstream checkout, e.g. for Torch 2.5 and CUDA 11.8:

```bash
python -m pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cu118
python -m pip install torch-scatter torch-sparse \
  -f https://data.pyg.org/whl/torch-2.5.0+cu118.html
```

Do not mix wheels targeting another Torch/CUDA ABI. GATSol expects its published
`Predict/tools` layout and official checkpoint. The adapter translates legacy
GAT projection keys only when source/destination tensors are identical.
Supported checkpoint archives contain regular files/directories only.

## Separate environments

- **TemBERTure:** follow the upstream installation for `temBERTure`, including
  its adapter-transformers stack. Obtain three Tm replicas plus the classification
  model. The integration passes these paths to the bundled ensemble runner.
- **TemStaPro:** follow upstream installation and download its ProtTrans encoder
  and classifier weights; set all four keys in the table.
- **ESM:** install the upstream `esm` SDK in a separate compatible environment.
  ESM3 model access may require accepting upstream terms. Download the full
  `esm3-sm-open-v1` snapshot, not only one tensor. ESMC supports 300m/600m weights.
  Configure `env.esmc.HF_HUB_CACHE` and `env.esm3.HF_HUB_CACHE` if the caches differ
  from `$HF_HOME/hub` (default `~/.cache/huggingface/hub`). ESM3 is local-only;
  ESMC may download with `--allow-model-download`.
- **Pro4S/MaSIF:** Pro4S inference uses modern PyTorch, but the bundled MaSIF
  preprocessing uses a separate legacy Python/TensorFlow/PyMesh installation.
  Use the upstream supported legacy environment/container. There is no claimed
  one-command fresh MaSIF installation in this release. Also supply MSMS,
  PDB2PQR, APBS and multivalue. Explicit options are `--masif-python`,
  `--msms-bin`, `--pdb2pqr-bin`, `--apbs-bin`, `--multivalue-bin`. Additional
  shared libraries can be specified with `env.pro4s.LD_LIBRARY_PATH`.
  Pro4S requires its finetune checkpoint, structural features and ESM2-3B weights.

Model subprocesses may be expensive. Run a single public structure first,
inspect per-model status/raw values, then scale to a batch. Do not treat a
successful package install or `doctor` as proof of successful model inference.

## Configuration example: EvoEF2 + RP3Net

```json
{
  "paths": {
    "evoef2": "external/EvoEF2/EvoEF2",
    "rp3net_py": "~/miniconda3/envs/screen-models/bin/python",
    "rp3_repo": "external/RP3Net",
    "rp3_src": "external/RP3Net/src",
    "rp3_ckpt": "external/RP3Net/weights/rp3net_v0.1_d.ckpt"
  },
  "env": {
    "rp3net": {"HF_HOME": "~/.cache/huggingface"}
  }
}
```

## Third-party attribution

Cite the upstream model publications linked from their repositories. This
project does not relicense or redistribute their code, model weights, compiled
binaries or databases. Private workspace patches are applied at runtime by the
GATSol/Pro4S adapters. The bundled 1UBQ structure is public wwPDB data; see
https://www.wwpdb.org/about/usage-policies for the data usage policy.
