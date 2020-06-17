#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash python38Full

export FLASK_APP=src/server.py
export FLASK_DEBUG=0
export FLASK_RUN_PORT="${PORT}"

trap 'exit 0' 1 2 15
source settings.env
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 -m flask run
