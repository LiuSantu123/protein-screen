# Screen 环境合并实验（2026-09-08）

目标是保留全部九个评分模型、原权重和 Pro4S 表面预处理，尽量合并 Python/PyTorch 安装。
**本次实际验证的最少配置为两个 conda 环境。**
独立 `screen-core` 主控启动的九模型统一运行全部成功（9/9，退出码 0）；
主环境 `pip check` 无冲突、14 项 unittest 全通过。输入为公开 1UBQ 单条蛋白。

| 运行部分 | 已验证运行环境 |
|---|---|
| 主控、NetSolP、RP3Net、GATSol、Pro4S 推理、TemBERTure、TemStaPro、ESMC、ESM3 | screen-core：Python 3.10.21、Torch 2.5.1 CUDA 11.8、Transformers 4.46.3、NumPy 1.26.4 |
| Pro4S 的 MaSIF/PyMesh 表面预处理 | 现有 masif：Python 3.7 |
| EvoEF2 | 原生 C++ 可执行程序，由主控调用，不需要第三个 Python 环境 |

## 已解决的兼容性问题

- **TemBERTure**：AdapterHub 官方提交 `702381ed5c581af3c488ce7e8663b3d94f0fac42`
  明确依赖 `transformers~=4.46.3`。其包版本虽为 `adapters 1.0.1`，
  **不能用 PyPI 同版本替代**，后者要求 Transformers 4.45。
  Screen runner 补齐 adapter 目录末尾斜杠，并支持 `TEMBERTURE_BASE_MODEL` 本地权重路径。
- **TemStaPro**：旧代码把 `pytorch_model.bin` 文件传给 `from_pretrained`，
  新 Transformers 要求模型目录。只修改加载入口，保留原编码器、分类器与评分算法。
- **ESM**：采用 SDK `esm==3.1.1`，其要求 `transformers<4.47`；
  3.1.6 在此组合中有 tokenizer 属性冲突。ESMC runner 根据 SDK 接口决定是否传递
  `use_flash_attn`，旧 SDK 使用原生注意力实现。
- **NumPy / 表面文件**：Biotite 0.41.2 配合 NumPy 1.26.4，
  `plyfile` 固定为 1.1；新版 1.1.5 要求 NumPy 2，不能直接共用。
- **命名空间隔离**：ESM SDK 和 fair-esm 都占用 `esm` 包名，不能一起装入默认
  site-packages。SDK 安装到独立目录，仅 ESMC/ESM3 子进程用 `PYTHONPATH` 选择它；
  仍共享同一 Python 和 Torch，但不是完全无隔离的单目录安装。

## 在现有可运行安装上复现

本配方克隆已运行成功的 screening 环境；不修改原环境。
它不是从空白 Linux 系统安装所有第三方模型的完整配方。

```bash
conda create -n screen-core --clone screening
conda activate screen-core
python -m pip install -r envs/minimal-core-requirements.txt
python -m pip install -e .
python -m pip install --no-deps --target "$PWD/.local/esm-sdk-3.1.1" esm==3.1.1
python scripts/prepare_temstapro_compat.py /path/to/TemStaPro "$PWD/.local/temstapro-compat"
python -m pip check
python -m unittest discover -s tests -v
```

克隆后还需核查可执行脚本的 shebang，不能回指源环境；本机历史安装混用了
两个挂载路径，已在新环境中修正残留入口。原 screening 的 NumPy 仍为 2.2.6，未被修改。

`screening` 克隆源需为 Python 3.10.12+（3.10 系列），并已有可运行的
NetSolP/RP3Net/GATSol/Pro4S 依赖。配置中的现代模型 `*_py` 全部设为
`screen-core/bin/python`；`masif_py` 保留旧环境。
`temstapro` 指向生成的新 launcher，`temstapro_dir` 仍指向原完整仓库。
ESMC/ESM3 的 `env.<model>.PYTHONPATH` 指向 SDK 目录；
TemBERTure 的 `PYTHONPATH` 指向上游包含 `temBERTure.py` 的目录，
`TEMBERTURE_BASE_MODEL` 指向完整 ProtBERT-BFD 本地快照。
ESM3 的 `HF_HUB_CACHE` 必须包含完整模型快照，只有结构编码器权重不够。

SDK 使用 `--no-deps` 是有意的：这里只部署 Screen 调用的推理路径。
SDK 元数据还声明 torchvision/torchtext，但这些模块未被所测 ESMC/ESM3 路径导入；
不声称此配置支持 SDK 的所有功能。主环境 `pip check` 也不校验独立 SDK 目录。

## 单环境的剩余障碍

现有 PyMesh Linux 扩展绑定旧 Python ABI。此次检查到的 PyPI pymesh2 0.1.6 wheel
实际包含 macOS Mach-O 二进制；conda-forge 的 pymesh2 Linux 构建只支持 Python 3.6。
这些现成包不能直接并入 Python 3.10。当前 Pro4S 预处理路径未直接导入 TensorFlow，
不能仅因旧环境装有 TF1 就断言必须拆分。
若要进一步压缩为一个环境，需要另外构建现代 Linux/Python 的 PyMesh 并验证完整表面流程；
本实验不证明这样的构建不可能。

本机克隆源已有 DGL GraphBolt 兼容处理；部分可选 PyG 扩展会因 GLIBC 版本被禁用。
因此真实模型推理验收比仅检查包能否安装更重要，不能把克隆成功等同于通用全新安装成功。

## 分模型兼容性预验证

以下使用公开 1UBQ（76 aa），f101 GPU，基于原现代解释器加独立依赖目录，
不是最终克隆环境验收。TemBERTure/TemStaPro 使用上述加载修复。

| 模型 | 兼容组合结果 | 原环境参考 |
|---|---|---|
| TemBERTure | Tm 52.0801，分类 0.0189 | 导出精度下一致 |
| TemStaPro | t40 0.5527，t55 0.05549，t65 0.0112 | 导出精度下一致 |
| ESMC 300m | pseudo-perplexity 1.040203 | 1.040203 |
| ESM3 small | pseudo-perplexity 1.021596 | SDK 3.3.0：1.021286 |
| GATSol | 1.1502755 | 本轮未做独立环境数值对照 |
| Pro4S | 0.8713930249214172，完整表面流程通过 | 本轮未做独立环境数值对照 |

ESM3 的 SDK/Torch 组合改变后存在约 0.0304% 数值差异，不宣称逐位一致；
单条公开蛋白验证不能替代批量排序稳定性或生物学准确性验证。

## 独立两环境最终验收

现代模型和主控全部使用 `screen-core/bin/python`，仅 MaSIF 使用旧 `masif`。

| 指标 | 1UBQ 实测值 |
|---|---|
| `netsolp_score`（ESM1b ensemble） | 0.8128094235944641 |
| `rp3net_score` | 0.9142355918884277 |
| `temberture_tm` | 52.0801 |
| `temberture_class_score` | 0.0189 |
| `temstapro_t40_raw` | 0.5527 |
| `temstapro_t55_raw` | 0.05549 |
| `temstapro_t65_raw` | 0.0112 |
| `esmc_perplexity` | 1.040203 |
| `esm3_perplexity` | 1.021596 |
| `gatsol_score` | 1.1502755 |
| `pro4s_score` | 0.8713943958282471 |
| `evoef2_energy` | -337.41 |

所有九模型状态均为 `ok`，没有跳过或用启发式评分替代；EvoEF2 成功解析 1/1。
该结果验证这台 Linux/CUDA 机器上的环境与流程兼容性，不证明跨平台安装或任意输入均已验收。

NetSolP 此处使用默认 ESM1b ensemble，与历史同模型 CPU 结果 0.81280947 一致到浮点误差；
v0.1.0 验收中的 0.8273101 来自 Distilled 配置，不能直接当作同模型环境对照。
