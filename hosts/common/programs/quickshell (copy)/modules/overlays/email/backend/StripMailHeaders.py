#!/usr/bin/env python3
# Reads raw `himalaya message read` output from stdin, strips the RFC 5322
# header block up to the first blank line, and prints just the body.
# Handles \n\n and \r\n\r\n separators, MIME boundary lines, and content-*
# headers that leak through on malformed messages.

import sys

data = sys.stdin.read()

# Find the header/body separator. Prefer \r\n\r\n (RFC 5322 compliant) then \n\n.
body = None
for sep in ("\r\n\r\n", "\n\n"):
    if sep in data:
        body = data.split(sep, 1)[1]
        break

if body is None:
    # No separator. If the whole thing looks like headers, treat body as empty.
    first_line = data.split("\n", 1)[0]
    header_names = ("From:", "To:", "Cc:", "Bcc:", "Subject:", "Date:",
                    "Return-Path:", "Received:", "Message-ID:", "MIME-Version:",
                    "Content-Type:", "Content-Transfer-Encoding:")
    if first_line.startswith(header_names):
        body = ""
    else:
        body = data

# Strip MIME boundary lines and content headers that leaked into the body
lines = body.split("\n")
filtered = []
for line in lines:
    stripped = line.rstrip("\r")
    # Boundary markers look like "--xxxxx" on their own line
    if stripped.startswith("--") and len(stripped) < 80 and stripped == stripped.rstrip():
        continue
    # Content-* headers that sometimes appear in multipart sections
    if stripped.startswith(("Content-Type:", "Content-Transfer-Encoding:",
                            "Content-Disposition:")):
        continue
    filtered.append(line)

result = "\n".join(filtered).strip()
sys.stdout.write(result)
