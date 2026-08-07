#!/bin/bash
PORT="${PORT:-8000}"
PIDFILE=".serve.pid"

case "${1:-start}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Already running on port $PORT (pid $(cat "$PIDFILE"))"
      exit 1
    fi
    python3 -m http.server --bind 127.0.0.1 "$PORT" &
    pid=$!
    sleep 0.5
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "Failed to start server on port $PORT" >&2
      exit 1
    fi
    echo "$pid" > "$PIDFILE"
    echo "Serving on http://localhost:$PORT (pid $pid)"
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      pid=$(cat "$PIDFILE")
      if ! kill -0 "$pid" 2>/dev/null; then
        echo "Not running (stale PID file)"
        rm -f "$PIDFILE"
      elif kill "$pid" 2>/dev/null; then
        echo "Stopped (pid $pid)"
        rm -f "$PIDFILE"
      else
        echo "Failed to stop pid $pid" >&2
        exit 1
      fi
    else
      echo "Not running"
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop}" >&2
    exit 1
    ;;
esac
