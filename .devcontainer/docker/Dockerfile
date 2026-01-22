# Must be debian-based image
ARG IMAGE_NAME=ubuntu
ARG VARIANT=${VARIANT:-latest}
ARG BASE_IMAGE=${IMAGE_NAME}:${VARIANT}
FROM ${BASE_IMAGE} AS builder

# Build arguments need to be re-declared if used in FROM instructions
# (https://docs.docker.com/build/building/variables/#scoping)
ARG BASE_IMAGE
ARG IMAGE_NAME
ARG VARIANT

ARG PASSGEN=/passgen.sh
ARG LOGGER=/logger.sh
ARG FIXPATH=/fixpath.sh
ARG TIMEZONE=UTC

# Timezone and locale settings
ENV TZ=$TIMEZONE
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Password generation defaults
# Default character set for password generation
# Use '[:graph:]' for all printable characters (except space)
# Use '[:alnum:]' for alphanumeric characters plus digits
# Use the 'a-zA-Z0-9' form for a custom character set (or specify any characters, e.g. 'a-zA-Z0-9!@#$%^&*()')
ARG DEFAULT_PASS_CHARSET='[:graph:]'
ARG DEFAULT_PASS_LENGTH=32
ENV CODESERVER_PASS_LENGTH=$DEFAULT_PASS_LENGTH
ENV CODESERVER_PASS_CHARSET=$DEFAULT_PASS_CHARSET

# Set environment variables to non-interactive (this prevents some prompts)
ENV DEBIAN_FRONTEND=noninteractive

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/*.sh /tmp/lib-scripts/

USER root

# Update and install essential packages
RUN sed -i "s|\$LOGGER|$LOGGER|g" /tmp/lib-scripts/*.sh \
  && /tmp/lib-scripts/builder-generators.sh \
  && /tmp/lib-scripts/builder-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  # && rm -rf /tmp/lib-scripts/builder-*.sh \
  # Set timezone
  && [ "$TIMEZONE" = "UTC" ] || \
  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && $LOGGER "Timezone set to '$TIMEZONE'"

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


FROM builder AS devuser

# Create a non-root user
ARG USERNAME=devcontainer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Development mode flag
ARG DEV=false
ENV DEV=$DEV

# Default path to Homebrew binary (for convenience; not likely to change)
ARG BREW=/home/linuxbrew/.linuxbrew/bin/brew
# Path to pipx binary locator script
ARG PIPX=/pipxpath.sh

# Set default Git version to install
# ('latest' to install latest from source, 'system' to use system Git, or specify version like '2.34.1', '2.35.0', etc.)
ARG GIT_VERSION=latest
# Set default Python version
# ('system' to use system Python, 'latest' to use latest Homebrew Python, or specify version like '3.9', '3.10', etc.)
ARG PYTHON_VERSION=latest
# Whether to set default root password to 'docker' at build time
# (for development purposes only; password can be changed at runtime)
ARG DEFAULT_ROOT_PASS=$DEV

# Export PYTHON_VERSION for convenience
ENV PYTHON_VERSION=$PYTHON_VERSION
# Update PATH here so that all shells contain the updated PATH
ENV PATH="/home/$USERNAME/.local/bin:${PATH}"

RUN /tmp/lib-scripts/devuser-generators.sh \
  && /tmp/lib-scripts/devuser-utils.sh \
  && /tmp/lib-scripts/git-install.sh \
  && /tmp/lib-scripts/devuser-setup.sh \
  # Cleanup
  && apt-get clean -y \
  && apt-get -y autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /tmp/lib-scripts/devuser-*.sh \
  && rm -f /tmp/lib-scripts/git-install.sh

# Install Homebrew for the non-root user
# Note: Homebrew on Linux doesn't require admin privileges when installed in home directory
USER $USERNAME
WORKDIR /home/$USERNAME

# Package management control
# Whether to install Homebrew
# (Very large and has a non-fixable high cve (as of January 2026); install only if needed)
ARG HOMEBREW_ENABLED=false
ARG NO_BREW_UPDATE=$DEV
RUN test "$HOMEBREW_ENABLED" != "true" \
  || NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Set default command
CMD ["/bin/bash"]

# --------------------------------------------------------------


# --------------------------------------------------------------
# THIS IS THE base `devcontainer` TARGET
# --------------------------------------------------------------
FROM devuser AS base

# Whether to install shfmt (shell script formatter) system-wide
# (has many CVEs in the Go toolchain; install only if needed)
ARG SHFMT_ENABLED=false

# Default user workspace directory
ARG DEFAULT_WORKSPACE=/home/$USERNAME/workspace
ENV DEFAULT_WORKSPACE=$DEFAULT_WORKSPACE

# Set default to not reset root password, in case devcontainer inherits from devtools or cloudtools
# Precautionary measure to avoid interactive prompt when running devcontainer
ENV RESET_ROOT_PASS=false

# Copy post-start script
COPY --chmod=755 .devcontainer/docker/utils/post-start.sh /usr/local/bin/post-start

USER root

RUN sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/post-start \
  & /tmp/lib-scripts/base-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /tmp/lib-scripts/base-*.sh

# Switch to non-root user
USER $USERNAME
WORKDIR $DEFAULT_WORKSPACE

# Whether to install pre-commit via Homebrew
# (will result in Homebrew installing Python dependencies)
ARG PRE_COMMIT_ENABLED=false
# If pipx is installed, it implies a user-managed Python environment; use it to install pre-commit
# Otherwise, install as a feature via devcontainer.json
# Use flag (build-arg) to install pre-commit with Homebrew to keep base image size down (Homebrew will install Python dependencies)
RUN if $PIPX 2>/dev/null; then \
    $($PIPX) install pre-commit; \
  else \
    test "$PRE_COMMIT_ENABLED" != "true" \
      || { test "$HOMEBREW_ENABLED" != "true" || $BREW install pre-commit; }; \
  fi

LABEL org.opencontainers.image.ref.name="<repo-name>:devcontainer-$BASE_IMAGE"
LABEL org.opencontainers.image.title="<repo-name> - devcontainer - $IMAGE_NAME - $VARIANT"
LABEL org.opencontainers.image.source=<server-fqdn>/<repo-owner-or-namespace>/<repo-name>
LABEL org.opencontainers.image.description="A simple Debian-based Docker image with essential development tools and Homebrew."
LABEL org.opencontainers.image.licenses=MIT

# --------------------------------------------------------------


FROM base AS devtools

# Whether to reset root password at container startup
# (true/false; default: $DEFAULT_ROOT_PASS build argument)
ENV RESET_ROOT_PASS=$DEFAULT_ROOT_PASS
# Needed to properly reference target version of python3
# ENV PATH="/home/linuxbrew/.linuxbrew/opt/python3/bin:${PATH}"

USER root

RUN /tmp/lib-scripts/devtools-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /tmp/lib-scripts/devtools-*.sh

# Switch to non-root user
USER $USERNAME

# Install Python, pipx, Poetry, uv, and other dev tools via Homebrew.
# Do nothing if PYTHON_VERSION is 'devcontainer' or matches the USERNAME.
# USERNAME cannot be 'system' or 'latest'.
RUN if  [ "$HOMEBREW_ENABLED" = "true" ]; then \
    test "$NO_BREW_UPDATE" = "true" || $BREW update \
    && if [ "$PYTHON_VERSION" = "latest" ] ; then \
      $BREW install python3; \
    elif [ "$PYTHON_VERSION" != "devcontainer" ] && [ "$PYTHON_VERSION" != "system" ] \
      && [ "$PYTHON_VERSION" != "$USERNAME" ] \
      && [ "$(python3 --version | awk -F. '{print $1"."$2}')" != "Python ${PYTHON_VERSION}" ] ; then \
      $BREW install python@${PYTHON_VERSION}; \
    fi \
    # Install pipx after Python
    && if [ "$PYTHON_VERSION" != "system" ] ; then \
      # Homebrew installs the latest version of Python if Python not already installed (by Homebrew)
      $BREW install pipx; \
    fi \
    # Configure pipx, and install Poetry and uv after ensuring pipx is installed
    && if $PIPX 2>/dev/null; then \
      $($PIPX) install \
        pre-commit \
        poetry \
        uv; \
      fi; \
  else \
    if [ "$PYTHON_VERSION" = "latest" ] \
      && $PIPX 2> /dev/null; then \
        $($PIPX) install pip; \
    fi; \
  fi

USER root

USER $USERNAME

ENTRYPOINT ["/docker-entrypoint.sh"]

# Set default command
CMD ["/bin/bash"]

# --------------------------------------------------------------


FROM base AS cloudtools

# TODO: Additional cloud CLI and Terraform installations
# ? https://github.com/awslabs/aws-terraform-dev-container/blob/main/.devcontainer/library-scripts/cloud-cli-tools.sh
# ? https://github.com/awslabs/aws-terraform-dev-container/blob/main/.devcontainer/library-scripts/terraform-tools.sh

USER root

RUN /tmp/lib-scripts/cloud-cli-tools.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /tmp/lib-scripts/cloud*tools.sh

USER $USERNAME

RUN if $PIPX 2>/dev/null; then \
    $($PIPX) install cfn-lint; \
  fi

# --------------------------------------------------------------


FROM base AS codeserver-minimal

ARG BIND_ADDR=0.0.0.0:8080
ENV BIND_ADDR=$BIND_ADDR
ENV DEBUG=false

# Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
ENV CODE_SERVER_WORKSPACE=$DEFAULT_WORKSPACE
ENV CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml
ENV CODE_SERVER_EXTENSIONS=$DEFAULT_WORKSPACE/.code-server/extensions/extensions.json

COPY --chmod=755 .devcontainer/docker/utils/start-code-server.sh /usr/local/bin/start-code-server

USER root

RUN /tmp/lib-scripts/codeserver-utils.sh

USER $USERNAME

RUN $LOGGER "Installing code-server..." \
  && curl -fsSL https://code-server.dev/install.sh | sh \
  && $LOGGER "code-server installation complete."

EXPOSE 8080

WORKDIR $DEFAULT_WORKSPACE

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

ARG BIND_ADDR=0.0.0.0:8080
ENV BIND_ADDR=$BIND_ADDR
ENV DEBUG=false

# Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
ENV CODE_SERVER_WORKSPACE=$DEFAULT_WORKSPACE
ENV CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml
ENV CODE_SERVER_EXTENSIONS=$DEFAULT_WORKSPACE/.code-server/extensions/extensions.json

COPY --chmod=755 .devcontainer/docker/utils/start-code-server.sh /usr/local/bin/start-code-server

USER root

RUN /tmp/lib-scripts/codeserver-utils.sh

USER $USERNAME

RUN $LOGGER "Installing code-server..." \
  && curl -fsSL https://code-server.dev/install.sh | sh \
  && $LOGGER "code-server installation complete."

EXPOSE 8080

WORKDIR $DEFAULT_WORKSPACE

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
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/lib-scripts/

ENTRYPOINT ["/usr/bin/tini", "--"]

# USER ubuntu
# WORKDIR /home/ubuntu

# Default command
CMD ["/bin/bash"]
