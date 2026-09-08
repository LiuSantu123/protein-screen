#!/usr/bin/env python3
"""Copy the upstream TemStaPro launcher and adapt local T5 loading for HF 4.46.

The upstream checkout and weights are never modified. Keep temstapro_dir pointing
at that checkout; set temstapro to the generated launcher.
"""
import argparse
from pathlib import Path
import shutil


def prepare(source: Path, destination: Path) -> None:
    text = (source / 'prottrans_models.py').read_text()
    old = ("T5EncoderModel.from_pretrained(model_path+'/pytorch_model.bin', \n"
           "                    config=model_path+'/config.json')")
    if text.count(old) != 1:
        raise ValueError('Unrecognized upstream loader; inspect before adapting it')
    patched = text.replace(old, 'T5EncoderModel.from_pretrained(model_path)')
    if not (source / 'temstapro').is_file():
        raise FileNotFoundError(source / 'temstapro')
    destination.mkdir(parents=True, exist_ok=False)
    shutil.copy2(source / 'temstapro', destination / 'temstapro')
    (destination / 'prottrans_models.py').write_text(patched)
    print(destination / 'temstapro')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    prepare(args.source.resolve(), args.destination.resolve())
