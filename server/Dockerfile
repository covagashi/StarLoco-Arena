# DofusArena 2.70 server — multi-stage build.
# Pure-Go (CGO disabled), so the final image is a tiny static binary on alpine.

# ---- build stage ----------------------------------------------------------
FROM golang:1.26-alpine AS build
WORKDIR /src

# Cache module downloads.
COPY go.mod go.sum ./
RUN go mod download

# Build the server + seed tool.
# VERSION is stamped into the binary so `arena-server --version` and the update
# check work in the image too:
#   docker build --build-arg VERSION=v0.1.0 .
ARG VERSION=dev
COPY . .
ENV CGO_ENABLED=0 GOOS=linux
RUN go build -trimpath \
      -ldflags="-s -w -X github.com/StarLoco/arena-2.70/internal/version.Version=${VERSION}" \
      -o /out/arena-server ./cmd/server && \
    go build -trimpath -ldflags="-s -w" -o /out/seedaccount ./cmd/seedaccount

# ---- runtime stage --------------------------------------------------------
FROM alpine:3.20
RUN adduser -D -u 10001 arena
WORKDIR /app

COPY --from=build /out/arena-server /app/arena-server
COPY --from=build /out/seedaccount /app/seedaccount
COPY configs/ /app/configs/

# The small server-data subset ships in the image by default, so fights work
# with zero mounts (see AGENTS.md / DISCLAIMER.md for what this is and isn't).
# Mount your own copy over ARENA_DATA_DIR=/data to use different data instead.
COPY --from=build /src/data-dist /app/data-dist

# Bug-report screenshots are written here at runtime (web.bug_report_dir).
# Create it in the IMAGE and own it as the unprivileged user: docker seeds a
# named volume from the image's contents on first mount, ownership included, and
# a volume that does not exist in the image is created root-owned - which the
# server (uid 10001) then cannot write to, so every screenshot fails with
# "permission denied" while the report itself still saves.
RUN mkdir -p /app/bugreports && chown arena:arena /app/bugreports

# Same problem for the SQLite state dir: the sqlite compose stack mounts a
# named volume at /state, and a path absent from the image mounts root-owned,
# which the uid-10001 server cannot write -> "unable to open database file".
RUN mkdir -p /state && chown arena:arena /state

# The DB (sqlite) or connection (postgres/mysql) is configured via config/env.
USER arena

# 5555 = game client, 8080 = the account-registration web portal. The portal is
# pinned to a fixed port here rather than left on "choose one for me", so the
# EXPOSE/publish mapping is predictable.
ENV ARENA_WEB_ADDR=0.0.0.0:8080
EXPOSE 5555 8080

# Default: read config from env (ARENA_*) or a mounted config file.
ENTRYPOINT ["/app/arena-server"]
CMD ["--config", "/app/configs/config.sqlite.yaml"]
