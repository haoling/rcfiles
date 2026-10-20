#!/usr/bin/python3
"""pinentry-touchid の前段に入り、鍵を要求したプロセスを確認ダイアログで表示する中継スクリプト。

gpg-agent <-> pinentry 間の Assuan 通信はそのまま素通しし、
gpg-agent から送られる "OPTION owner=<pid>/<uid> <host>" から要求元を調べる。
GETPIN（Touch ID 認証の開始）の直前に確認ダイアログを出し、
OK（Enter）なら続行、キャンセル（Escape）・タイムアウト・表示失敗なら中止する。
~/.gnupg/pinentry-notify-webhook に URL を書いておくと、結果と要求元を webhook に送る。
pinentry からの応答（パスフレーズを含む D 行）は一切記録しない。
"""
import json
import os
import re
import socket
import subprocess
import sys
import threading
import urllib.request

REAL_PINENTRY = "/opt/homebrew/opt/pinentry-touchid/bin/pinentry-touchid"
MAX_DEPTH = 6
DIALOG_TIMEOUT = 60  # この秒数操作がなければキャンセル扱い
# gpg-agent から起動されると環境変数が引き継がれないため、URL はファイルから読む
WEBHOOK_URL_FILE = os.path.expanduser("~/.gnupg/pinentry-notify-webhook")
WEBHOOK_TIMEOUT = 5
OWNER_RE = re.compile(rb"^OPTION\s+owner=(\d+)")
GETPIN_RE = re.compile(rb"^GETPIN\b", re.IGNORECASE)
# GPG_ERR_SOURCE_PINENTRY(5) << 24 | GPG_ERR_CANCELED(99)
ERR_CANCELED = b"ERR 83886179 Operation cancelled <Pinentry>\n"

stdout_lock = threading.Lock()


def debug(message):
    if os.environ.get("PINENTRY_NOTIFY_DEBUG"):
        print("[pinentry-notify] " + message, file=sys.stderr)


def write_to_agent(data):
    with stdout_lock:
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()


def process_chain(pid):
    """pid から親方向にたどって 'gpg (PID 123) ← git ← zsh' 形式の文字列を返す。"""
    names = []
    first_pid = pid
    for _ in range(MAX_DEPTH):
        if pid <= 1:
            break
        try:
            out = subprocess.run(
                ["/bin/ps", "-o", "ppid=,comm=", "-p", str(pid)],
                capture_output=True, text=True, timeout=2,
            ).stdout.strip()
        except Exception:
            break
        if not out:
            break
        ppid, _, comm = out.partition(" ")
        names.append(os.path.basename(comm.strip()))
        try:
            pid = int(ppid)
        except ValueError:
            break
    if not names:
        return "PID %d（プロセス情報を取得できません）" % first_pid
    names[0] = "%s (PID %d)" % (names[0], first_pid)
    return " ← ".join(names)


def send_webhook(status, requester):
    """結果を webhook に送る。URL 未設定や送信失敗は無視する。"""
    try:
        with open(WEBHOOK_URL_FILE) as f:
            url = f.read().strip()
    except OSError:
        return
    if not url:
        return
    host = socket.gethostname()
    payload = {
        "text": "🔐 GPG鍵の使用要求: %s\n要求元: %s\nホスト: %s" % (status, requester, host),
        "status": status,
        "requester": requester,
        "host": host,
    }

    def post():
        try:
            req = urllib.request.Request(
                url, data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            urllib.request.urlopen(req, timeout=WEBHOOK_TIMEOUT).close()
        except Exception as e:
            debug("webhook failed: %r" % e)

    # Touch ID 認証を待たせないよう別スレッドで送る。
    # daemon にしないので、プロセス終了前に送信（最大 WEBHOOK_TIMEOUT 秒）を待つ。
    threading.Thread(target=post).start()


def confirm(requester):
    """確認ダイアログを出し、"ok" / "cancel" / "timeout" / "error" のいずれかを返す。"""
    debug(requester)
    try:
        # 文字列は argv 経由で渡し、AppleScript への埋め込みを避ける
        result = subprocess.run(
            ["/usr/bin/osascript",
             "-e", "on run argv",
             "-e", "display dialog (item 1 of argv) with title (item 2 of argv)"
                   " buttons {\"キャンセル\", \"OK\"} default button \"OK\""
                   " cancel button \"キャンセル\" with icon caution"
                   " giving up after (item 3 of argv as integer)",
             "-e", "end run",
             "要求元: " + requester + "\n\nTouch ID 認証に進みますか？",
             "🔐 GPG鍵の使用要求", str(DIALOG_TIMEOUT)],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
            timeout=DIALOG_TIMEOUT + 10,
        )
    except Exception:
        return "error"
    if result.returncode != 0:
        # キャンセルボタン・Escape は osascript がエラー -128 で終了する
        return "cancel" if "-128" in result.stderr else "error"
    if "gave up:true" in result.stdout:
        return "timeout"
    if "button returned:OK" in result.stdout:
        return "ok"
    return "error"


def pump_agent_to_pinentry(src, dst):
    requester = "不明（gpg-agent から要求元が渡されませんでした）"
    try:
        for line in iter(src.readline, b""):
            m = OWNER_RE.match(line)
            if m:
                requester = process_chain(int(m.group(1)))
            if GETPIN_RE.match(line):
                status = confirm(requester)
                debug(status)
                send_webhook(status, requester)
                if status != "ok":
                    write_to_agent(ERR_CANCELED)
                    continue
            dst.write(line)
            dst.flush()
    except (BrokenPipeError, OSError):
        pass
    finally:
        try:
            dst.close()
        except OSError:
            pass


def pump_pinentry_to_agent(src):
    try:
        for chunk in iter(lambda: src.read1(65536), b""):
            write_to_agent(chunk)
    except (BrokenPipeError, OSError):
        pass


def main():
    child = subprocess.Popen(
        [REAL_PINENTRY] + sys.argv[1:],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
    )
    t_in = threading.Thread(
        target=pump_agent_to_pinentry, args=(sys.stdin.buffer, child.stdin), daemon=True)
    t_out = threading.Thread(target=pump_pinentry_to_agent, args=(child.stdout,))
    t_in.start()
    t_out.start()
    t_out.join()
    sys.exit(child.wait())


if __name__ == "__main__":
    main()
