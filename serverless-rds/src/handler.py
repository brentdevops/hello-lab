# OPS-262: the notes app. AWS runs handler() every time someone opens or submits the page.
#   GET  /  -> show the form + every saved note
#   POST /  -> save the typed note in RDS, then show the page again
import base64
import html
import json
import os
import ssl
import urllib.parse

import boto3          # AWS's Python library (already in the Lambda runtime)
import pg8000.native  # talks to Postgres (bundled in this folder)

DB_HOST = os.environ["DB_HOST"]              # the RDS address, set by Terraform
DB_SECRET_ARN = os.environ["DB_SECRET_ARN"]  # where the DB password lives in Secrets Manager

secrets = boto3.client("secretsmanager")


def connect():
    # 1. get the username + password from Secrets Manager (allowed by the Lambda's IAM role)
    secret = json.loads(secrets.get_secret_value(SecretId=DB_SECRET_ARN)["SecretString"])

    # 2. RDS requires an encrypted connection.
    #    Lab shortcut: encrypt but skip checking RDS's certificate. At work you'd bundle the RDS CA file.
    tls = ssl.create_default_context()
    tls.check_hostname = False
    tls.verify_mode = ssl.CERT_NONE

    # 3. open the connection to RDS on port 5432 (allowed by the security group). Give up after 5 seconds.
    try:
        return pg8000.native.Connection(
            user=secret["username"],
            password=secret["password"],
            host=DB_HOST,
            port=int(os.environ.get("DB_PORT", "5432")),
            database="postgres",
            ssl_context=tls,
            timeout=5,
        )
    except pg8000.native.InterfaceError as e:
        # log the real network reason: "Name or service not known" = wrong address, "timed out" = blocked path
        print(f"DB ERROR: can't connect to {DB_HOST}: {e.__cause__ or e.__context__!r}")
        raise


def page(notes):
    items = "".join(
        f"<li>{html.escape(body)} <small>{created:%b %d, %H:%M} UTC</small></li>" for body, created in notes
    )
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Notes</title>
<style>body{{font-family:sans-serif;max-width:520px;margin:40px auto}}input{{width:75%;padding:8px}}button{{padding:8px 14px}}li{{margin:6px 0}}small{{color:#888}}</style>
</head><body>
<h1>Notes</h1>
<form method="post"><input name="note" placeholder="Write a note..." autofocus required> <button>Save</button></form>
<ul>{items or "<li><i>No notes yet.</i></li>"}</ul>
</body></html>"""


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    db = connect()
    try:
        db.run("CREATE TABLE IF NOT EXISTS notes (id serial PRIMARY KEY, body text NOT NULL, created_at timestamptz DEFAULT now())")

        if method == "POST":
            body = event.get("body") or ""
            if event.get("isBase64Encoded"):
                body = base64.b64decode(body).decode()
            note = urllib.parse.parse_qs(body).get("note", [""])[0].strip()
            if note:
                db.run("INSERT INTO notes (body) VALUES (:note)", note=note[:500])
                print(f"saved note: {note[:80]!r}")  # goes to CloudWatch Logs
            # send the browser back to the page (so a refresh doesn't re-submit)
            return {"statusCode": 303, "headers": {"Location": "/"}}

        notes = db.run("SELECT body, created_at FROM notes ORDER BY id DESC LIMIT 50")
        return {"statusCode": 200, "headers": {"Content-Type": "text/html"}, "body": page(notes)}
    finally:
        db.close()
