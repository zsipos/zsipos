#!/usr/bin/env python3

import os
import sys
from collections import OrderedDict


current_path = os.path.dirname(os.path.realpath(__file__))

# name,  (url, recursive clone, develop)
repos = [
    # HDL
    ("migen",      ("https://github.com/m-labs/",        True,  True)),

    # LiteX SoC builder
    ("litex",      ("https://github.com/zsipos/", True,  True)),

    # LiteX cores ecosystem
    ("liteeth",    ("https://github.com/enjoy-digital/", False, True)),
    ("litedram",   ("https://github.com/enjoy-digital/", False, True)),
]
repos = OrderedDict(repos)

if len(sys.argv) < 2:
    print("Available commands:")
    print("- install to user directory)")
    print("- update")
    exit()

if "install" in sys.argv[1:]:
    for name in repos.keys():
        url, need_recursive, need_develop = repos[name]
        # develop if needed
        print("[installing " + name + "]...")
        if need_develop:
            os.chdir(os.path.join(current_path, name))
            os.system("python3 setup.py develop --user")

if "update" in sys.argv[1:]:
    for name in repos.keys():
        # update
        print("[updating " + name + "]...")
        os.chdir(os.path.join(current_path, name))
        os.system("git pull")
