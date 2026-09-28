"""Agent A wrapper around common/preview.py: identical, except SG window variants render dark blue like 'Windows*'."""
import os
SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "common", "preview.py")
code = open(SRC).read().replace('if var.startswith("Windows"): return (58, 74, 98)',
                                'if var.startswith("Windows") or var.startswith("SG Windows"): return (58, 74, 98) if "Blocks" in var else (84, 104, 130)')
exec(compile(code, SRC, "exec"), {"__file__": SRC, "__name__": "__main__"})
