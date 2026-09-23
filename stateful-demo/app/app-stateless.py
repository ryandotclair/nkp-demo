"""
CSI Demo App (stateless): same UI but ephemeral storage (emptyDir).
Copy is tuned for "data is lost when the pod is deleted" demo.
"""
import os
import sys
from pathlib import Path
from flask import Flask, make_response, redirect, request, render_template_string, url_for

BLOCK_PATH = Path("/data/block")
FILE_PATH = Path("/data/file")
DEMO_FILENAME = "demo-content.txt"

app = Flask(__name__)


def EnsureDir(path: Path) -> None:
    try:
        path.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        print(f"Warning: could not ensure {path}: {e}", file=sys.stderr)


def ReadFile(path: Path) -> str:
    f = path / DEMO_FILENAME
    if not f.exists():
        return ""
    return f.read_text()


def WriteFile(path: Path, content: str) -> None:
    EnsureDir(path)
    (path / DEMO_FILENAME).write_text(content or "(empty)")


@app.route("/", methods=["GET", "POST"])
@app.route("/<path:path>", methods=["GET", "POST"])
def Index(path: str = ""):
    if request.method == "POST":
        action = request.form.get("action")
        text = request.form.get("text", "")
        if action == "save_block":
            WriteFile(BLOCK_PATH, text)
        elif action == "save_file":
            WriteFile(FILE_PATH, text)
        return redirect(request.path, code=303)

    blockContent = ReadFile(BLOCK_PATH)
    fileContent = ReadFile(FILE_PATH)
    blockExists = (BLOCK_PATH / DEMO_FILENAME).exists()
    fileExists = (FILE_PATH / DEMO_FILENAME).exists()
    podName = os.environ.get("HOSTNAME", "unknown")

    response = render_template_string(HTML_TEMPLATE,
        blockContent=blockContent,
        fileContent=fileContent,
        blockExists=blockExists,
        fileExists=fileExists,
        blockPath=str(BLOCK_PATH),
        filePath=str(FILE_PATH),
        podName=podName,
    )
    resp = make_response(response)
    resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    resp.headers["Pragma"] = "no-cache"
    resp.headers["Expires"] = "0"
    return resp


HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CSI Demo — Ephemeral (Stateless)</title>
  <style>
    :root { --bg: #0f1419; --card: #1a2332; --accent: #e67e22; --text: #e6edf3; --muted: #8b949e; }
    * { box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; background: var(--bg); color: var(--text); margin: 0; padding: 2rem; min-height: 100vh; }
    h1 { font-size: 1.5rem; margin-top: 0; }
    .sub { color: var(--muted); font-size: 0.9rem; margin-bottom: 1.5rem; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; max-width: 900px; }
    @media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
    .card { background: var(--card); border-radius: 8px; padding: 1.25rem; border: 1px solid rgba(255,255,255,0.06); }
    .card h2 { font-size: 1rem; margin: 0 0 0.75rem; color: var(--accent); }
    .path { font-family: monospace; font-size: 0.8rem; color: var(--muted); margin-bottom: 0.75rem; }
    form { display: flex; flex-direction: column; gap: 0.5rem; }
    textarea { width: 100%; min-height: 80px; background: #0d1117; border: 1px solid #30363d; border-radius: 6px; color: var(--text); padding: 0.5rem; resize: vertical; }
    button { background: var(--accent); color: #fff; border: none; padding: 0.5rem 1rem; border-radius: 6px; cursor: pointer; font-weight: 500; }
    button:hover { filter: brightness(1.1); }
    .content { white-space: pre-wrap; font-size: 0.9rem; margin-top: 0.5rem; padding: 0.5rem; background: #0d1117; border-radius: 6px; min-height: 2rem; }
    .hint { font-size: 0.75rem; color: var(--muted); margin-top: 0.5rem; }
    .badge { display: inline-block; background: rgba(230,126,34,0.2); color: var(--accent); padding: 0.15rem 0.5rem; border-radius: 4px; font-size: 0.75rem; margin-left: 0.5rem; }
  </style>
</head>
<body>
  <h1>CSI Demo — Ephemeral storage</h1>
  <p class="sub">This app uses <strong>emptyDir</strong> (no PVCs). Data is <strong>lost when the pod is deleted</strong>. <strong>Pod: <span style="color: #fff;">{{ podName }}</span></strong> — delete the pod and reload to see content disappear.</p>
  <div class="grid">
    <div class="card">
      <h2>Block (ephemeral) <span class="badge">emptyDir</span></h2>
      <div class="path">Mount: {{ blockPath }}</div>
      <form method="post">
        <input type="hidden" name="action" value="save_block">
        <textarea name="text" placeholder="Save something — then delete the pod and reload...">{{ blockContent }}</textarea>
        <button type="submit">Save to block</button>
      </form>
      <div class="hint">Current content (lost on pod delete):</div>
      <div class="content">{% if blockContent %}{{ blockContent }}{% else %}(none yet){% endif %}</div>
    </div>
    <div class="card">
      <h2>File (ephemeral) <span class="badge">emptyDir</span></h2>
      <div class="path">Mount: {{ filePath }}</div>
      <form method="post">
        <input type="hidden" name="action" value="save_file">
        <textarea name="text" placeholder="Save something — then delete the pod and reload...">{{ fileContent }}</textarea>
        <button type="submit">Save to file</button>
      </form>
      <div class="hint">Current content (lost on pod delete):</div>
      <div class="content">{% if fileContent %}{{ fileContent }}{% else %}(none yet){% endif %}</div>
    </div>
  </div>
  <p class="sub" style="margin-top: 1.5rem;">Next: add PVCs and switch to the stateful app to see data persist across pod restarts.</p>
</body>
</html>
"""


if __name__ == "__main__":
    try:
        print("Starting CSI demo app (stateless)...", flush=True)
        EnsureDir(BLOCK_PATH)
        EnsureDir(FILE_PATH)
        print("Listening on 0.0.0.0:8080", flush=True)
        app.run(host="0.0.0.0", port=8080)
    except Exception as e:
        print(f"Fatal: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
