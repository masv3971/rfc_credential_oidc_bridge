#!/bin/bash
PORT="${PORT:-8000}"
PIDFILE=".serve.pid"

case "${1:-start}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Already running on port $PORT (pid $(cat "$PIDFILE"))"
      exit 1
    fi
    python3 -m http.server "$PORT" &
    echo $! > "$PIDFILE"
    echo "Serving on http://localhost:$PORT (pid $!)"
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null && echo "Stopped" || echo "Not running"
      rm -f "$PIDFILE"
    else
      echo "Not running"
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop}" >&2
    exit 1
    ;;
esac
