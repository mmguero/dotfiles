#!/usr/bin/env python3
import os, sys, json

FADE = 0.020  # seconds
TARGET = 0  # track that dips out (first track)
SOURCE = 1  # track the replacement comes from (second track)

uid = os.getuid()
TO = f"/tmp/audacity_script_pipe.to.{uid}"
FROM = f"/tmp/audacity_script_pipe.from.{uid}"
if not (os.path.exists(TO) and os.path.exists(FROM)):
    sys.exit("Pipe not found. Is Audacity running with mod-script-pipe enabled?")

to_pipe = open(TO, "w")
from_pipe = open(FROM, "r")


def cmd(c):
    to_pipe.write(c + "\n")
    to_pipe.flush()
    out = []
    while True:
        line = from_pipe.readline()
        if line == "":
            sys.exit("Audacity closed the pipe.")
        if line == "\n" and out:
            break
        out.append(line)
    resp = "".join(out)
    if "BatchCommand finished: Failed" in resp:
        sys.exit(f"Failed: {c}\n{resp}")
    return resp


def track_count():
    r = cmd("GetInfo: Type=Tracks Format=JSON")
    return len(json.loads(r[: r.rfind("BatchCommand")]))


# Copy the slice of the second track to a new track
cmd(f"SelectTracks: Track={SOURCE} TrackCount=1 Mode=Set")
cmd("Duplicate:")
new = track_count() - 1  # Duplicate appends at the bottom

# Fade the copy in and out
cmd(f"SelectTracks: Track={new} TrackCount=1 Mode=Set")
cmd("SwapSwell:")

# Fade the first track out, hold silence, fade back in
cmd(f"SelectTracks: Track={TARGET} TrackCount=1 Mode=Set")
cmd("SwapDip:")
