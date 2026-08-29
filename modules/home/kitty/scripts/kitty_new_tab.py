import logging
import os
import subprocess
import sys
from pathlib import Path


log = logging.getLogger("@name@")
log.setLevel(logging.@log_level@)
log.addHandler(logging.StreamHandler())

try:
  # Optional, if needed, add `libraries = with pkgs.python3Packages; [ systemd-python ];`
  # to writePython3Bin arguments
  from systemd.journal import JournalHandler

  log.addHandler(JournalHandler(SYSLOG_IDENTIFIER="@name@"))
except ImportError:
  pass

if not (runtime_dir := os.getenv("XDG_RUNTIME_DIR")):
  raise RuntimeError("XDG_RUNTIME_DIR is not set")

RUNTIME_DIR = Path(runtime_dir)
SOCK_PREFIX = "kitty-rc"
PASSWORD = ""


def find_sock():
  """Find the most recent kitty-rc-{pid} socket."""
  socks = sorted(
    RUNTIME_DIR.glob(SOCK_PREFIX + "-*"),
    key=lambda p: p.stat().st_mtime,
    reverse=True,
  )
  if socks:
    log.debug("found sockets: %s", socks)
    return "unix:" + str(socks[0])
  log.debug("no existing kitty sockets found")
  return None


def parse_args(argv):
  title = None
  app_id = None
  cwd = os.getcwd()
  hold = False
  cmd = []
  it = iter(argv[1:])
  for arg in it:
    if arg == "--":
      cmd = list(it)
      break
    elif arg == "--title":
      title = next(it, None)
    elif arg == "--class":
      app_id = next(it, None)
    elif arg == "--working-directory":
      cwd = next(it, None)
    elif arg == "--hold":
      hold = True
  return title, app_id, cwd, hold, cmd


def notify(title, message, urgency="normal"):
  """Send desktop notification."""
  try:
    subprocess.run(["notify-send", "-a", "@name@", "-i", "kitty", "-u", urgency, title, message], check=False)
  except Exception:
    pass


def try_remote_launch(sock, title, cwd, hold, cmd):
  remote_base = ["kitten", "@", "--to", sock]
  if PASSWORD and not os.getenv("KITTY_PUBLIC_KEY"):
    # remote_base += ["--password", PASSWORD]
    log.critical("password protected remote launch outside of kitty is unsupported")
    notify("Remote launch error", "password protected remote launch outside of kitty is unsupported", urgency="critical")
    return False
  launch_args = remote_base + ["launch", "--type=tab"]
  if title:
    launch_args += ["--tab-title", title]
  if cwd:
    launch_args += ["--cwd", cwd]
  if hold:
    launch_args.append("--hold")
  launch_args += cmd
  log.info("remote launch: %s", launch_args)
  result = subprocess.run(launch_args, capture_output=True, text=True)
  if result.returncode == 0:
    window_id = result.stdout.strip()
    log.info("tab launched, focusing window %s", window_id)
    subprocess.run(remote_base + ["focus-window", "-m", f"id:{window_id}"])
    return True
  log.warning("remote launch failed (rc=%d): %s", result.returncode, result.stderr.strip())
  notify("Remote launch failed", result.stderr.strip())
  return False


def detached_log_path():
  """Return the log file Kitty's --detach redirects its output to."""
  return RUNTIME_DIR / "kitty-new-tab.log"


def fallback_launch(title, app_id, cwd, hold, cmd):
  """Launch a detached Kitty instance and return immediately.

  kitty --detach forks, calls setsid and redirects its own stdio, so the spawned
  process exits right away instead of replacing this script and blocking the
  terminal that invoked it.
  """
  log_path = detached_log_path()
  args = ["kitty", "--detach", "--detached-log", str(log_path)]
  if title:
    args += ["--title", title]
  if app_id:
    args += ["--class", app_id]
  if cwd:
    args += ["--directory", cwd]
  if hold:
    args.append("--hold")
  if cmd:
    args.append("--")
    args += cmd
  log.info("fallback: %s", args)
  result = subprocess.run(
    args,
    stdin=subprocess.DEVNULL,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.PIPE,
    text=True,
    start_new_session=True,
  )
  if result.returncode == 0:
    log.info("detached fallback kitty started")
    return True
  detail = result.stderr.strip() or f"kitty exited with status {result.returncode} (see {log_path})"
  log.warning("detached fallback failed (rc=%d): %s", result.returncode, detail)
  notify("Kitty launch failed", detail, urgency="critical")
  return False


def main():
  log.debug("argv: %s", sys.argv)
  title, app_id, cwd, hold, cmd = parse_args(sys.argv)
  log.info(
    "parsed: title=%s app_id=%s cwd=%s hold=%s cmd=%s",
    title, app_id, cwd, hold, cmd,
  )
  sock = find_sock()
  if sock and try_remote_launch(sock, title, cwd, hold, cmd):
    return
  if not fallback_launch(title, app_id, cwd, hold, cmd):
    sys.exit(1)


if __name__ == "__main__":
  main()
