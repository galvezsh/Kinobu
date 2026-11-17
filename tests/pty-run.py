#!/usr/bin/env python3
"""Runs a command in a pseudo-terminal (34 x 120), types the given keys and prints what it showed.
Usage: pty-run.py KEY... -- COMMAND...   A key written as @TEXT waits until TEXT is on screen."""
import fcntl, os, pty, select, struct, sys, termios, time
keys, cmd = sys.argv[1:sys.argv.index("--")], sys.argv[sys.argv.index("--") + 1:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 34, 120, 0, 0))
out, seen, sent, last, start = b"", 0, 0, time.time(), time.time()
while time.time() - start < 180:
    ready, _, _ = select.select([fd], [], [], 0.1)
    if ready:
        try:
            data = os.read(fd, 65536)
        except OSError:
            break
        if not data:
            break
        out += data; last = time.time()
        continue
    if sent == len(keys) and time.time() - last > 5:
        break                      # every key typed and the screen is still: done
    if sent < len(keys) and time.time() - last > 0.25:
        key = keys[sent]
        if key.startswith("@"):
            at = out.find(key[1:].encode(), seen)
            if at < 0:
                continue
            seen = at + len(key) - 1
        else:
            seen = len(out)
            os.write(fd, key.encode())
        sent += 1; last = time.time()
try:
    os.kill(pid, 9)
except OSError:
    pass
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
