# Release validation — v0.1.0

Validated on 2026-09-08, Linux x86_64. The dedicated `protein-screen` conda
controller environment uses Python 3.11.16, gemmi 0.7.5, h5py 3.16.0,
numpy 2.4.6 and openpyxl 3.1.5. Exact conda and pip runtime versions are
recorded in `envs/conda-linux-64.lock` and `envs/controller-pip.txt`.

## Automated checks

All 14 unittest cases pass in the new controller environment. They cover
FASTA validation/normalization, exact structure matching and sequence identity,
configuration paths, missing/partial results, subprocess failure and timeout,
checkpoint archive traversal and symlink rejection, ranking direction/ties,
missing values and weight validation. A fake external executable tests the
adapter contract; that test is not evidence of model inference.

`pip check` reports no broken requirements. The public synthetic ranking
example produces three ranked records. A private 40-record regression fixture
matches the original implementation on all 15 derived ranking fields. The
private fixture and experimental data are not distributed.

## Model inference scope

Real inference uses the public 76-residue 1UBQ FASTA/PDB fixture and existing,
separate model installations. Model weights and their environments are not
included in the controller installation. The initial CPU integration run
confirmed NetSolP (default ESM1b ensemble; score 0.81280947) and EvoEF2
(single-chain ComputeStability; total -337.41). Its controller was an existing
Python 3.10 environment during preparation of the new conda environment.
RP3Net exceeded that run's 180-second per-stage window.

The release does not claim fresh installation or inference validation of all
nine models. TemBERTure, TemStaPro, ESMC, ESM3, GATSol and Pro4S adapters have
not been exercised with real weights as part of this release. In particular,
GATSol/Pro4S need CUDA and Pro4S also needs a separate legacy MaSIF environment.
`envs/models.yml` is an unverified starting recipe, not a nine-model lockfile.
A successful `doctor` only establishes that configured paths exist.

Scores are computational model outputs, not experimental validation. The
single-record composite percentile is 0.5 by construction.

## Dedicated environment and built-wheel verification

The final CPU rerun in the dedicated Python 3.11.16 controller environment
completed with exit 0 for all three selected models:

| Model | Configuration | Result |
|---|---|---|
| NetSolP | Distilled, CPU | 0.8273101 |
| RP3Net | rp3net_v0.1_d checkpoint, CPU | 0.9142354726791382 |
| EvoEF2 | single matching chain, CPU | -337.41 |

The rerun used two CPU threads and a 600-second per-stage timeout. RP3Net
completed within this window; the earlier 180-second timeout was not counted
as a pass. See `examples/1ubq_results.csv` for the public result summary.

The wheel and source distribution were built with `python -m build`. The
wheel was installed into a separate target directory; import location was
verified, and both the ranking example and real EvoEF2 inference passed using
the installed wheel. No private configuration, weights or experimental records
are included in either distribution.
