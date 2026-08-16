import logging
import subprocess
import sys

log = logging.getLogger("kitty-is-cmd-allowed")
log.setLevel("@log_level@")
log.addHandler(logging.StreamHandler())


def notify(title, message, urgency="normal"):
  """Send desktop notification."""
  try:
    subprocess.run(["@libnotify@", "-a", "kitty-is-cmd-allowed", "-i", "kitty", "-u", urgency, title, message], check=False)
  except Exception:
    pass


def is_cmd_allowed(pcmd, window, from_socket, extra_data):
    cmd_name = pcmd['cmd']  # the name of the command
    cmd_payload = pcmd['payload']  # the arguments to the command
    # examine the cmd_name and cmd_payload and return True to allow
    # the command or False to disallow it. Return None to have no
    # effect on the command.

    log.debug('is_cmd_allowed called: cmd_name=%s, cmd_payload=%s, window=%s, from_socket=%s', cmd_name, cmd_payload, window, from_socket)

    if cmd_name in {"focus-tab", "focus-window", "select-window", "ls"}:
        log.info('Command whitelist: %s', cmd_name)
        return True
    elif cmd_name not in {"launch"}:
        log.debug('Allowing non-launch command: %s', cmd_name)
        return None
    if cmd_payload.get('args') or cmd_payload.get('env') or cmd_payload.get('copy_cmdline') or cmd_payload.get('copy_env'):
        log.warning('Blocking launch command with restricted args: %s', cmd_payload)
        notify('Blocking launch command', f"restricted args: {cmd_payload}")
        return False
    # prints in this function go to the parent kitty process STDOUT
    log.info('Allowing launch command: %s', cmd_payload)
    return True


if __name__ == "__main__":
  # Read JSON input from stdin for testing
  import json
  data = json.load(sys.stdin)
  result = is_cmd_allowed(data.get('pcmd', {}), data.get('window'), data.get('from_socket'), data.get('extra_data'))
  print(result)
