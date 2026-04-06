import os
import subprocess
from pathlib import Path

from fastapi import FastAPI, HTTPException, Header

SANDBOX = Path.home() / "ai-sandbox"
TOKEN = os.environ.get("AI_SANDBOX_DASHBOARD_TOKEN")

app = FastAPI()


def _require_auth(authorization: str | None) -> None:
    if not TOKEN:
        raise HTTPException(
            status_code=503,
            detail="Set AI_SANDBOX_DASHBOARD_TOKEN to enable control endpoints.",
        )
    if not authorization or authorization != f"Bearer {TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/")
def home():
    return {"status": "running", "control_enabled": bool(TOKEN)}


@app.post("/start/{project}")
def start(project: str, authorization: str | None = Header(None)):
    _require_auth(authorization)
    r = subprocess.run(
        [str(SANDBOX / "config/start-container.sh"), "--detach", project],
        check=False,
    )
    if r.returncode != 0:
        raise HTTPException(status_code=500, detail="start-container failed")
    return {"started": project}


@app.post("/stop/{project}")
def stop(project: str, authorization: str | None = Header(None)):
    _require_auth(authorization)
    r = subprocess.run(
        [str(SANDBOX / "config/stop-container.sh"), project],
        check=False,
    )
    if r.returncode != 0:
        raise HTTPException(status_code=500, detail="stop-container failed")
    return {"stopped": project}
