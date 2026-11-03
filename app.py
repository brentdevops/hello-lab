import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg

VERSION = os.environ.get("VERSION", "dev")

# where the database is (OPS-231)
DB_HOST = os.environ.get("DB_HOST", "postgres")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")


def count_visit():
    # connect, add 1 visit, return the total
    with psycopg.connect(host=DB_HOST, port=DB_PORT, user="postgres",
                         password=DB_PASSWORD, dbname="postgres",
                         connect_timeout=3) as conn:
        conn.execute("CREATE TABLE IF NOT EXISTS visits (n integer)")
        conn.execute("INSERT INTO visits VALUES (1)")
        return conn.execute("SELECT count(*) FROM visits").fetchone()[0]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            body, code = b"ok\n", 200
        elif self.path == "/":
            try:
                n = count_visit()
                body, code = f"welcome to hello-lab, {VERSION}. you are visitor #{n}\n".encode(), 200
            except Exception as e:
                print(f"DB ERROR: {e}", flush=True)
                body, code = b"sorry, something went wrong\n", 500
        else:
            body, code = b"not found\n", 404
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    print(f"listening on :8080 version={VERSION} db={DB_HOST}:{DB_PORT}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
