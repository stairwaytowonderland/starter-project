# Must be debian-based image
ARG IMAGE_NAME=ubuntu
ARG VARIANT=${VARIANT:-latest}
ARG BASE_IMAGE=${IMAGE_NAME}:${VARIANT}
ARG DEV_PARENT_IMAGE=devuser

# --------------------------------------------------------------
# Generator stages for core utility scripts
# --------------------------------------------------------------
FROM alpine AS utils

ARG LOGGER=/usr/local/bin/logger.sh \
    PASSGEN=/usr/local/bin/passgen.sh \
    DEFAULT_PASS_CHARSET='[:graph:]' \
    DEFAULT_PASS_LENGTH=32

COPY --chmod=755 .devcontainer/docker/utils/logger.sh $LOGGER
COPY --chmod=755 .devcontainer/docker/utils/passgen.sh $PASSGEN

RUN sed -i "s|\$PASSGEN|$PASSGEN|g" $PASSGEN \
  && sed -i "s|\$DEFAULT_PASS_LENGTH|$DEFAULT_PASS_LENGTH|g" $PASSGEN \
  && sed -i "s|\$DEFAULT_PASS_CHARSET|$DEFAULT_PASS_CHARSET|g" $PASSGEN


FROM scratch AS filez

ARG LOGGER=/usr/local/bin/logger.sh \
    PASSGEN=/usr/local/bin/passgen.sh \
    DEFAULT_PASS_CHARSET='[:graph:]' \
    DEFAULT_PASS_LENGTH=32

COPY --from=utils $LOGGER $LOGGER
COPY --from=utils $PASSGEN $PASSGEN

COPY .devcontainer/docker/helpers/*.sh /helpers/

# --------------------------------------------------------------

# --------------------------------------------------------------
# Base builder stage
# --------------------------------------------------------------
FROM $BASE_IMAGE AS builder

# Build arguments need to be re-declared if used in FROM instructions
# (https://docs.docker.com/build/building/variables/#scoping)

ARG BASE_IMAGE \
    IMAGE_NAME \
    VARIANT \
    DEV_PARENT_IMAGE

ARG LOGGER=/usr/local/bin/logger.sh \
    TIMEZONE=UTC

# Timezone and locale settings
# ? localedef -i en_US -f UTF-8 en_US.UTF-8
ENV LOGGER=$LOGGER \
    TZ=$TIMEZONE \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    # Set environment variables to non-interactive (this prevents some prompts)
    DEBIAN_FRONTEND=noninteractive

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/builder-*.sh /tmp/lib-scripts/
# Copy logger script
COPY --from=filez $LOGGER $LOGGER
# Copy helper scripts
COPY --from=filez /helpers /helpers

USER root

# Update and install essential packages
RUN /tmp/lib-scripts/builder-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && apt-get -y autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/* \
  # Set timezone
  && [ "$TIMEZONE" = "UTC" ] || \
  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata

# Password generation defaults
# Default character set for password generation
# Use '[:graph:]' for all printable characters (except space)
# Use '[:alnum:]' for alphanumeric characters plus digits
# Use the 'a-zA-Z0-9' form for a custom character set (or specify any characters, e.g. 'a-zA-Z0-9!@#$%^&*()')
ARG PASSGEN=/usr/local/bin/passgen.sh \
    DEFAULT_PASS_CHARSET='[:graph:]' \
    DEFAULT_PASS_LENGTH=32
ENV PASSGEN=$PASSGEN \
    DEFAULT_PASS_LENGTH=$DEFAULT_PASS_LENGTH \
    DEFAULT_PASS_CHARSET=$DEFAULT_PASS_CHARSET
# Copy passgen script
COPY --from=filez $PASSGEN $PASSGEN

# As of Ubuntu 24 (Noble Numbat), the Ubuntu base image comes with a non-root user ubuntu with UID 1000
# Delete this user to avoid conflicts when creating our own non-root user
# ! Use 'userdel' to perform a shallow delete, and preserve htpasswd/group integrity for UID and GID
RUN if [ "$IMAGE_NAME" = "ubuntu" ]; then \
    if id "ubuntu" >/dev/null 2>&1; then \
      $LOGGER "Deleting user 'ubuntu' for $IMAGE_NAME" \
        && userdel -r -f ubuntu > /dev/null 2>&1 \
        || LEVEL=error $LOGGER "Failed to delete ubuntu user for $IMAGE_NAME"; \
    else \
      $LOGGER "User 'ubuntu' does not exist for $IMAGE_NAME"; \
    fi; \
  fi

# --------------------------------------------------------------


# --------------------------------------------------------------
# Build-only builder stages: brewbuilder, gobuilder
# --------------------------------------------------------------
FROM builder AS brewbuilder

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/git-install.sh /tmp/lib-scripts/

USER root

RUN apt-get update \
  && apt-get -y install --no-install-recommends sudo \
  && groupadd --gid "$USER_GID" "$USERNAME" \
  && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME" -s /bin/bash \
  && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
  && chmod 0440 "/etc/sudoers.d/$USERNAME" \
  && /tmp/lib-scripts/git-install.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

USER $USERNAME

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

CMD ["/bin/bash"]


FROM builder AS gobuilder

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/go-install.sh /tmp/lib-scripts/

USER root

RUN /tmp/lib-scripts/go-install.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]


FROM builder AS nodebuilder

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ARG NODE_VERSION=lts
ARG NODEPATH=/usr/local/lib/node/nodejs
ENV NODEJS_HOME=/usr/local/lib/nodejs

ENV PATH="$NODEJS_HOME/bin:$PATH"

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/node-install.sh /tmp/lib-scripts/

USER root

RUN /tmp/lib-scripts/node-install.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]

# --------------------------------------------------------------


# --------------------------------------------------------------
# Intermediary builder stages: devbuilder, devuser, brewuser
# --------------------------------------------------------------
FROM builder AS devbuilder

# Create a non-root user
ARG USER_UID=1000 \
    USER_GID=$USER_UID \
    USERNAME=devcontainer \
    # Development mode flag
    FIXPATH=/usr/local/bin/fixpath.sh \
    # Default path to Homebrew binary (for convenience; not likely to change)
    BREW=/home/linuxbrew/.linuxbrew/bin/brew \
    # Set default Git version to install
    # ('latest' to install latest from source, 'system' to use system Git, or specify version like '2.34.1', '2.35.0', etc.)
    GIT_VERSION=latest \
    # Set default Python version
    # ('system' to use system Python, 'latest' to use latest Homebrew Python, or specify version like '3.9', '3.10', etc.)
    PYTHON_VERSION=latest \
    # Whether to set default root password to 'docker' at build time
    # (for development purposes only; password can be changed at runtime)
    DEV=false \
    DEFAULT_ROOT_PASS=$DEV

# Update PATH here so that all shells contain the updated PATH
ENV PATH="/home/$USERNAME/.local/bin:$PATH" \
    # Export PYTHON_VERSION for convenience
    PYTHON_VERSION=$PYTHON_VERSION \
    DEV=$DEV

COPY --chmod=755 .devcontainer/docker/utils/fixpath.sh $FIXPATH

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/devbuilder*.sh \
    .devcontainer/docker/lib-scripts/git-install.sh \
    /tmp/lib-scripts/

RUN sed -i "s|\$FIXPATH|$FIXPATH|g" $FIXPATH \
  && /tmp/lib-scripts/devbuilder-utils.sh \
  && /tmp/lib-scripts/git-install.sh \
  && /tmp/lib-scripts/devbuilder-user-setup.sh \
  # Cleanup
  && apt-get clean -y \
  && apt-get -y autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

# Install Homebrew for the non-root user
# Note: Homebrew on Linux doesn't require admin privileges when installed in home directory
USER $USERNAME
WORKDIR /home/$USERNAME

CMD ["/bin/bash"]


FROM devbuilder AS devuser

USER $USERNAME
WORKDIR /home/$USERNAME

CMD ["/bin/bash"]


FROM devbuilder AS brewuser

WORKDIR /home/linuxbrew
COPY --from=brewbuilder --chown=$USERNAME:$USERNAME /home/linuxbrew .

USER $USERNAME
WORKDIR /home/$USERNAME

CMD ["sh", "-c", "exec $BREW"]

# --------------------------------------------------------------


# --------------------------------------------------------------
# THIS IS THE base `devcontainer` TARGET
# --------------------------------------------------------------
FROM $DEV_PARENT_IMAGE AS base

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/base-*.sh /tmp/lib-scripts/
# Copy post-start script
COPY --chmod=755 .devcontainer/docker/scripts/post-start.sh /usr/local/bin/post-start

# Copy shfmt installation from gobuilder stage
COPY --from=gobuilder /usr/local/bin/shfmt /usr/local/bin/shfmt

# Path to pipx binary locator script
ARG PIPX=/usr/local/bin/pipxpath.sh
COPY --chmod=755 .devcontainer/docker/utils/pipxpath.sh $PIPX

USER root

ARG PRE_COMMIT_ENABLED=false

RUN sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/post-start \
  && sed -i "s|\$PIPX|$PIPX|g" $PIPX \
  && sed -i "s|\$BREW|$BREW|g" $PIPX \
  && /tmp/lib-scripts/base-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/* \
  # Create healthcheck lock file
  && touch /.healthcheck \
  && chmod 666 /.healthcheck

# Default user workspace directory
ARG DEFAULT_WORKSPACE=/home/$USERNAME/workspace
ENV DEFAULT_WORKSPACE=$DEFAULT_WORKSPACE \
    # Set IGNOREEOF to prevent accidental EOF (`CTRL+D`) from closing the container when running in interactive mode
    IGNOREEOF=1

COPY --chmod=755 .devcontainer/docker/utils/healthcheck.sh /usr/local/bin/healthcheck.sh

# Switch to non-root user
USER $USERNAME
WORKDIR $DEFAULT_WORKSPACE

# If pipx is installed, it implies a user-managed Python environment; use it to install pre-commit
# Otherwise, use Homebrew to install pre-commit if Homebrew is available
# Install as a feature via devcontainer.json if neither pipx nor Homebrew is available
RUN if ! type pre-commit >/dev/null 2>&1 && [ "$PRE_COMMIT_ENABLED" = "true" ]; then \
    if "$PIPX" >/dev/null 2>&1; then \
      $("$PIPX") install pre-commit; \
    else \
      if type "$BREW" > /dev/null 2>&1 ; then \
        "$BREW" install pre-commit; \
      fi; \
    fi; \
  fi \
  && $PASSGEN -s 16 '[:alpha:]' > /.healthcheck

# docker inspect --format='{{json .State.Health}}' <container_id> | jq
HEALTHCHECK --interval=5s --timeout=3s --start-period=1s --retries=3 \
  CMD $PASSGEN -s 16 '[:alpha:]' | tee /.healthcheck || exit 1

CMD ["healthcheck.sh"]

# LABEL org.opencontainers.image.ref.name="<repo-name>:devcontainer-$BASE_IMAGE"
# LABEL org.opencontainers.image.title="<repo-name> - devcontainer - $IMAGE_NAME - $VARIANT"
# LABEL org.opencontainers.image.source=<server-fqdn>/<repo-owner-or-namespace>/<repo-name>
# LABEL org.opencontainers.image.description="A simple Debian-based Docker image with essential development tools and Homebrew."
# LABEL org.opencontainers.image.licenses=MIT

# --------------------------------------------------------------


FROM base AS devtools

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/devtools-*.sh \
    .devcontainer/docker/lib-scripts/python-install.sh \
    /tmp/lib-scripts/

ARG NODEPATH=/home/$USERNAME/.local/lib/node/nodejs
ENV NODEJS_HOME=/home/$USERNAME/.local/lib/nodejs
ENV PATH="$NODEJS_HOME/bin:$PATH"
COPY --from=nodebuilder --chown=$USERNAME:$USERNAME /usr/local/lib/node/nodejs $NODEPATH
COPY --from=nodebuilder --chmod=755 /tmp/node-* /tmp/

USER root

RUN /tmp/lib-scripts/devtools-utils.sh \
  && /tmp/lib-scripts/python-install.sh \
  # # Insert NODEPATH variable on 2nd line
  && if [ -x /tmp/node-install ]; then \
    sed -i "2s|^|\nNODEPATH=$NODEPATH\n\n|" /tmp/node-install \
    && /tmp/node-install; \
  fi \
  # Cleanup
  && apt-get -y autoremove \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

# Switch to non-root user
USER $USERNAME

# Install Python, pipx, Poetry, uv, and other dev tools.
# Do nothing if PYTHON_VERSION is 'devcontainer' or matches the USERNAME.
# USERNAME cannot be 'system' or 'latest'.
ARG NO_BREW_UPDATE=$DEV
RUN if type "$BREW" > /dev/null 2>&1; then \
    test "$NO_BREW_UPDATE" = "true" || "$BREW" update \
    && if [ "$PYTHON_VERSION" = "latest" ] ; then \
      "$BREW" install python3; \
    elif [ "$PYTHON_VERSION" != "devcontainer" ] && [ "$PYTHON_VERSION" != "system" ] \
      && [ "$PYTHON_VERSION" != "$USERNAME" ] \
      && [ "$(python3 --version | awk -F. '{print $1"."$2}')" != "Python ${PYTHON_VERSION}" ] ; then \
      "$BREW" install "python@${PYTHON_VERSION}"; \
    fi \
    && if [ "$PYTHON_VERSION" != "system" ] ; then \
      "$BREW" install pipx; \
    fi; \
  else \
    if [ "$PYTHON_VERSION" = "latest" ] && "$PIPX" 2> /dev/null \
      && [ "$IMAGE_NAME" = "ubuntu" ]; then \
        $("$PIPX") install pip; \
    fi; \
  fi \
  && if "$PIPX" 2>/dev/null; then \
    type pre-commit >/dev/null 2>&1 \
      || [ "$PRE_COMMIT_ENABLED" != "true" ] \
      || $("$PIPX") install pre-commit \
    && $("$PIPX") install poetry \
    && $("$PIPX") install uv; \
  fi

COPY --chmod=755 <<EOF /usr/local/bin/docker-entrypoint.sh
#!/bin/sh

set -eu

if [ "\${RESET_ROOT_PASS:-$DEFAULT_ROOT_PASS}" = "true" ]
then
  printf "\033[1m%s\033[0m\n" "Updating root password ..."
  sudo passwd root
fi

if type /usr/games/fortune >/dev/null 2>&1 \\
  && type /usr/games/cowsay >/dev/null 2>&1
then
  /usr/games/fortune | /usr/games/cowsay
fi

exec "\$@"
EOF

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["/bin/bash"]

# --------------------------------------------------------------


FROM base AS cloudtools

# TODO: Additional cloud CLI and Terraform installations
# ? https://github.com/awslabs/aws-terraform-dev-container/blob/main/.devcontainer/library-scripts/cloud-cli-tools.sh
# ? https://github.com/awslabs/aws-terraform-dev-container/blob/main/.devcontainer/library-scripts/terraform-tools.sh

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/cloud*tools.sh /tmp/lib-scripts/

USER root

RUN /tmp/lib-scripts/cloud-cli-tools.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

USER $USERNAME

RUN if $PIPX 2>/dev/null; then \
    $($PIPX) install cfn-lint; \
  fi

# --------------------------------------------------------------


FROM base AS codeserver-minimal

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/codeserver-utils.sh /tmp/lib-scripts/

USER root

RUN /tmp/lib-scripts/codeserver-utils.sh \
  # Remove sudo access for non-root user
  && rm -f /etc/sudoers.d/$USERNAME \
  && SUDO_FORCE_REMOVE=yes apt-get -y remove sudo \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

# Results in a much larger image
# RUN $LOGGER "Installing code-server..." \
#   && curl -fsSL https://code-server.dev/install.sh | sh \
#   && $LOGGER "code-server installation complete."

ARG BIND_ADDR=0.0.0.0:13337
ENV BIND_ADDR=$BIND_ADDR \
    # Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
    CODE_SERVER_WORKSPACE=$DEFAULT_WORKSPACE \
    CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml \
    CODE_SERVER_EXTENSIONS=$DEFAULT_WORKSPACE/.code-server/extensions/extensions.json \
    DOWNLOAD_STANDALONE=true \
    DEBUG=false

# Copy start-code-server script
COPY --chmod=755 .devcontainer/docker/scripts/start-code-server.sh /usr/local/bin/start-code-server

# If standalone download is false, use root to install the .deb package
# If standalone download is true use $USERNAME to install the tar.gz package
USER $USERNAME
COPY --chmod=755 --chown=$USERNAME:$USERNAME .devcontainer/docker/lib-scripts/codeserver-install.sh \
    /tmp/lib-scripts/

RUN $LOGGER "Installing code-server..." \
  && /tmp/lib-scripts/codeserver-install.sh \
  && $LOGGER "code-server installation complete." \
  && rm -rf /tmp/*

# USER $USERNAME
WORKDIR $DEFAULT_WORKSPACE

# dockerfile-utils: ignore
EXPOSE "${BIND_ADDR##*:}"

# Health check
# dockerfile-utils: ignore
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -fsSL "http://localhost:"${BIND_ADDR##*:}"/healthz" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]

# CMD ["start-code-server"]
CMD ["/bin/sh", "-c", "start-code-server --config-only && set -x ; \
    exec code-server \
      --bind-addr $BIND_ADDR \
      --extensions-dir \
      $(dirname $CODE_SERVER_EXTENSIONS) \
      ${CODE_SERVER_WORKSPACE:-.}"]

# --------------------------------------------------------------


FROM devtools AS codeserver

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/codeserver-utils.sh /tmp/lib-scripts/

USER root

RUN /tmp/lib-scripts/codeserver-utils.sh \
  # Remove sudo access for non-root user
  && rm -f /etc/sudoers.d/$USERNAME \
  && SUDO_FORCE_REMOVE=yes apt-get -y remove sudo \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

# Results in a much larger image
# RUN $LOGGER "Installing code-server..." \
#   && curl -fsSL https://code-server.dev/install.sh | sh \
#   && $LOGGER "code-server installation complete."

ARG BIND_ADDR=0.0.0.0:13337
ENV BIND_ADDR=$BIND_ADDR \
    # Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
    CODE_SERVER_WORKSPACE=$DEFAULT_WORKSPACE \
    CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml \
    CODE_SERVER_EXTENSIONS=$DEFAULT_WORKSPACE/.code-server/extensions/extensions.json \
    DOWNLOAD_STANDALONE=true \
    DEBUG=false

# Copy start-code-server script
COPY --chmod=755 .devcontainer/docker/scripts/start-code-server.sh /usr/local/bin/start-code-server

# If standalone download is false, use root to install the .deb package
# If standalone download is true use $USERNAME to install the tar.gz package
USER $USERNAME
COPY --chmod=755 --chown=$USERNAME:$USERNAME .devcontainer/docker/lib-scripts/codeserver-install.sh \
    /tmp/lib-scripts/

RUN $LOGGER "Installing code-server..." \
  && /tmp/lib-scripts/codeserver-install.sh \
  && $LOGGER "code-server installation complete." \
  && rm -rf /tmp/*

# USER $USERNAME
WORKDIR $DEFAULT_WORKSPACE

# dockerfile-utils: ignore
EXPOSE "${BIND_ADDR##*:}"

# Health check
# dockerfile-utils: ignore
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -fsSL "http://localhost:"${BIND_ADDR##*:}"/healthz" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]

# CMD ["start-code-server"]
CMD ["/bin/sh", "-c", "start-code-server --config-only && set -x ; \
    exec code-server \
      --bind-addr $BIND_ADDR \
      --extensions-dir \
      $(dirname $CODE_SERVER_EXTENSIONS) \
      ${CODE_SERVER_WORKSPACE:-.}"]

# --------------------------------------------------------------


FROM builder AS production

RUN apt-get update \
  && apt-get -y install --no-install-recommends tini \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/tini", "--"]

# USER ubuntu
# WORKDIR /home/ubuntu

# Default command
CMD ["/bin/bash"]
