FROM python:3.12-slim

# OPS-231: the library the app uses to talk to Postgres (installed as root, before switching user)
RUN pip install --no-cache-dir "psycopg[binary]==3.2.*"

# run as a non-root user
RUN useradd --uid 10001 --no-create-home app
USER 10001

WORKDIR /app
# --chown: make user 10001 own the file, so it can read it no matter
# what permissions app.py had on the machine that built the image
COPY --chown=10001:10001 app.py .

# set at build time: docker build --build-arg VERSION=<git sha>
ARG VERSION=dev
ENV VERSION=${VERSION} \
    PYTHONUNBUFFERED=1

EXPOSE 8080
CMD ["python", "app.py"]
