FROM alpine:3.21

LABEL org.opencontainers.image.title="Git Sync Action" \
      org.opencontainers.image.description="Hardened, SDD-verified GitHub Action for syncing branches and tags between independent Git repositories" \
      org.opencontainers.image.source="https://github.com/homgorn/git-sync" \
      org.opencontainers.image.url="https://refertur.net" \
      org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache git openssh-client ca-certificates \
  && mkdir -p /etc/ssh \
  && (ssh-keyscan -t ed25519,rsa github.com gitlab.com bitbucket.org codeberg.org > /etc/ssh/git_sync_known_hosts 2>/dev/null || true)

COPY entrypoint.sh git-sync.sh /
RUN chmod 755 /entrypoint.sh /git-sync.sh

ENTRYPOINT ["/entrypoint.sh"]
