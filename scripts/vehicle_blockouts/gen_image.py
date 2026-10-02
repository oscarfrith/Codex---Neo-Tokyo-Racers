"""Generate one concept image with the local Codex CLI's built-in image_gen tool.

Usage:
  py -3 scripts/vehicle_blockouts/gen_image.py <out.png> <prompt.txt> [--jpg <small.jpg>] [--ref a.png b.png ...]

Runs `codex exec` in a throwaway _work folder beside the output (a system temp folder gets ACLs the
Codex sandbox user writes but this user cannot read), asks it to save the image as out.png there,
then copies it to <out.png>. Project instructions are not loaded (project_doc_max_bytes=0).
--ref attaches reference images: Codex passes them to the image tool as inputs, so the result follows
them (the prompt should say what each one is, in order: "Reference 1 is ...").
--jpg writes a 1000 px wide JPEG copy for docs. Retries twice. Exit code 0 on success.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import time

from PIL import Image

WRAP = """Use your built-in image generation tool (image_gen) to generate exactly ONE landscape 3:2 image from the prompt between the markers.
%s
Then copy the resulting PNG into the current working directory as out.png.
Do not read, search or modify any other files. Do not ask questions. Reply with only the word DONE.

<<<PROMPT
%s
PROMPT>>>
"""
REF_NOTE = """There are %d reference images attached to this message, in the order the prompt numbers them (Reference 1 first).
You MUST pass every attached image to the image generation tool as input/reference images, so the generated image is based on them. Do not generate from the text alone."""


def find_codex():
    hits = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\OpenAI\Codex\bin\*\codex.exe"))
    if not hits:
        raise SystemExit("codex.exe not found under %LOCALAPPDATA%\\OpenAI\\Codex\\bin")
    return max(hits, key=os.path.getmtime)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    out_png, prompt_file = os.path.abspath(sys.argv[1]), sys.argv[2]
    jpg = os.path.abspath(sys.argv[sys.argv.index("--jpg") + 1]) if "--jpg" in sys.argv else None
    refs = []
    if "--ref" in sys.argv:
        for a in sys.argv[sys.argv.index("--ref") + 1:]:
            if a.startswith("--"):
                break
            if not os.path.exists(a):
                raise SystemExit("reference image not found: " + a)
            refs.append(os.path.abspath(a))
    with open(prompt_file, "r", encoding="utf-8") as f:
        prompt = f.read().strip()
    codex = find_codex()
    last = ""
    for attempt in range(3):
        work = os.path.join(os.path.dirname(out_png), "_work", "%d_%d_%d" % (os.getpid(), attempt, int(time.time())))
        os.makedirs(work, exist_ok=True)
        try:
            cmd = [codex, "exec", "--skip-git-repo-check", "-s", "workspace-write"]
            for r in refs:
                cmd += ["-i", r]
            cmd += ["-c", 'model_reasoning_effort="low"', "-c", "project_doc_max_bytes=0", "-C", work, "-"]
            proc = subprocess.run(cmd, input=WRAP % (REF_NOTE % len(refs) if refs else "", prompt),
                                  capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=540)
            last = (proc.stdout or "")[-1500:] + (proc.stderr or "")[-1500:]
            src = os.path.join(work, "out.png")
            readable = False
            try:
                with open(src, "rb") as fh:
                    readable = len(fh.read(16)) == 16
            except OSError:
                pass
            if not readable:
                m = re.findall(r"[A-Za-z]:\\[^\"'\n]*?generated_images[^\"'\n]*?\.png", (proc.stdout or "") + (proc.stderr or ""))
                m = [p.replace("\\\\", "\\") for p in m if os.path.exists(p.replace("\\\\", "\\"))]
                if m:
                    src = m[-1]
            if os.path.exists(src) and os.path.getsize(src) > 50_000:
                os.makedirs(os.path.dirname(out_png), exist_ok=True)
                shutil.copyfile(src, out_png)
                if jpg:
                    os.makedirs(os.path.dirname(jpg), exist_ok=True)
                    im = Image.open(out_png).convert("RGB")
                    im.thumbnail((1000, 1000), Image.LANCZOS)
                    im.save(jpg, "JPEG", quality=82, optimize=True)
                print("OK " + out_png)
                return 0
        except subprocess.TimeoutExpired:
            last = "timeout"
        finally:
            shutil.rmtree(work, ignore_errors=True)
        time.sleep(20 + 25 * attempt)
    print("FAILED after 3 attempts. Last output tail:\n" + last)
    return 1


if __name__ == "__main__":
    sys.exit(main())
