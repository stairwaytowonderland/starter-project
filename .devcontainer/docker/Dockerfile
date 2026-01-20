# Must be debian-based image
ARG IMAGE_NAME=ubuntu
ARG VARIANT=${VARIANT:-latest}
ARG BASE_IMAGE=${IMAGE_NAME}:${VARIANT}
FROM ${BASE_IMAGE} AS builder

# Set environment variables to non-interactive (this prevents some prompts)
ENV DEBIAN_FRONTEND=noninteractive

# Development mode flag
ARG DEV=false

# Build arguments need to be re-declared if used in FROM instructions
# (https://docs.docker.com/build/building/variables/#scoping)
ARG BASE_IMAGE
ARG IMAGE_NAME
ARG VARIANT
# Create a non-root user
ARG USERNAME=devcontainer
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG PASSGEN=/passgen.sh
ARG LOGGER=/logger.sh
ARG FIXPATH=/fixpath.sh
ARG TIMEZONE=UTC
# Repository information (required for image labels)
ARG REPO_NAME=devcontainer
ARG REPO_NAMESPACE=devcontainer
# Package management control
ARG NO_BREW_UPDATE=$DEV
# Other
ARG DEFAULT_PASS_LENGTH=32
# Default character set for password generation
# Use '[:graph:]' for all printable characters (except space)
# Use '[:alnum:]' for alphanumeric characters plus digits
# Use the 'a-zA-Z0-9' form for a custom character set (or specify any characters, e.g. 'a-zA-Z0-9!@#$%^&*()')
ARG DEFAULT_PASS_CHARSET='a-zA-Z0-9'
# Default user workspace directory
ARG DEFAULT_WORKSPACE=/home/$USERNAME/workspace

ENV TZ=$TIMEZONE
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ENV DEV=$DEV
ENV DEFAULT_WORKSPACE=$DEFAULT_WORKSPACE

# Copy library scripts
COPY .devcontainer/docker/lib-scripts/*.sh /tmp/lib-scripts/

USER root

# Update and install essential packages
RUN chmod +x /tmp/lib-scripts/*.sh \
  && sed -i "s|\$LOGGER|$LOGGER|g" /tmp/lib-scripts/*.sh \
  && /tmp/lib-scripts/builder-generators.sh && \
  # Check for mandatory build arguments (https://stackoverflow.com/a/44791255)
  : "${REPO_NAME:?Build argument needs to be set and non-empty.}" \
  && \
  : "${REPO_NAMESPACE:?Build argument needs to be set and non-empty.}" \
  # Update package lists and install packages
  && /tmp/lib-scripts/builder-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/lib-scripts/builder-*.sh \
  # Set timezone
  && [ "$TIMEZONE" = "UTC" ] || \
  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && $LOGGER "Timezone set to '$TIMEZONE'" \
  # Add useful bash aliases system-wide
  && if ! type ll >/dev/null 2>&1; then \
    echo >> /etc/bash.bashrc && \
    echo "alias ll='ls -alF' " >> /etc/bash.bashrc; \
  fi \
  # Enable bash completion for root user
  && cat >> /root/.bashrc <<EOF
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
   . /etc/bash_completion
fi
EOF


FROM builder AS devuser

# Set default Git version to install
# ('latest' to install latest from source, 'system' to use system Git, or specify version like '2.34.1', '2.35.0', etc.)
ARG GIT_VERSION=latest
# Set default Python version
# ('system' to use system Python, 'latest' to use latest Homebrew Python, or specify version like '3.9', '3.10', etc.)
ARG PYTHON_VERSION=latest
# Whether to set default root password to 'docker' at build time
# (for development purposes only; password can be changed at runtime)
ARG DEFAULT_ROOT_PASS=$DEV
# Default path to Homebrew binary (for convenience; not likely to change)
ARG BREW=/home/linuxbrew/.linuxbrew/bin/brew
# Path to pipx binary locator script
ARG PIPX=/pipxpath.sh

# Export PYTHON_VERSION for convenience
ENV PYTHON_VERSION=$PYTHON_VERSION
# Update PATH here so that all shells contain the updated PATH
ENV PATH="/home/$USERNAME/.local/bin:${PATH}"

# As of Ubuntu 24 (Noble Numbat), the Ubuntu base image comes with a non-root user ubuntu with UID 1000
# Delete this user to avoid conflicts when creating our own non-root user
RUN if [ "$IMAGE_NAME" = "ubuntu" ]; then \
    if id "ubuntu" >/dev/null 2>&1; then \
      $LOGGER "Deleting user 'ubuntu' for $IMAGE_NAME" && userdel -f -r ubuntu \
        || LEVEL=error $LOGGER "Failed to delete ubuntu user for $IMAGE_NAME"; \
    else \
      $LOGGER "User 'ubuntu' does not exist for $IMAGE_NAME"; \
    fi; \
  fi \
  && /tmp/lib-scripts/devuser-generators.sh \
  && /tmp/lib-scripts/devuser-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && apt-get -y autoremove \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /tmp/lib-scripts/devuser-*.sh \
  && rm -f /tmp/lib-scripts/git-install.sh

RUN cat <<EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

# Ensure Homebrew is properly configured
# The brew shellenv line exports HOMEBREW_PREFIX, HOMEBREW_CELLAR,
# and HOMEBREW_REPOSITORY (INFOPATH is also set),
# in addition to prepending the brew 'bin' and 'sbin' to the PATH.
if type "$BREW" &>/dev/null
then
  eval "\$($BREW shellenv)"
fi
EOF

RUN test "$PYTHON_VERSION" = "devcontainer" \
  || test "$PYTHON_VERSION" = "$USERNAME" \
  || test "$PYTHON_VERSION" = "system" || \
  cat <<EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

if type brew &>/dev/null
then
  # PYTHON_BREW_PATH="\$(brew --prefix python3)/bin"
  PYTHON_BREW_PATH="\$(brew --prefix)/opt/python3/bin"
  if test -d "\$PYTHON_BREW_PATH"
  then
    PATH="\${PYTHON_BREW_PATH}:\${PATH}"
  fi
fi
EOF

RUN test "$PYTHON_VERSION" != "devcontainer" \
  && test "$PYTHON_VERSION" != "$USERNAME" \
  && test "$PYTHON_VERSION" != "system" || \
  cat <<EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

if type /usr/local/python/current/bin/python3 &>/dev/null
then
  PATH="/usr/local/python/current/bin:\${PATH}"
fi
EOF

RUN echo | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null && \
  echo PATH="\$($FIXPATH)" | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null && \
  cat <<EOF | tee -a /etc/skel/.profile /root/.profile > /dev/null

# https://docs.brew.sh/Shell-Completion
if type brew &>/dev/null
then
  HOMEBREW_PREFIX="\$(brew --prefix)"
  if [ -r "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]
  then
    source "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "\${HOMEBREW_PREFIX}/etc/bash_completion.d/"*
    do
      ! test  -r "\${COMPLETION}" || source "\${COMPLETION}"
    done
  fi
fi
EOF

# Create a new non-root user with sudo privileges
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
  && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Set default password for root user to 'docker'
# Only for development purposes; password can be changed at runtime
# DO NOT use in production environments
# Avoid using 'chpasswd' with here-string (e.g. chpasswd <<<"root:docker") as it may not be supported in some shells
RUN if [ "$DEFAULT_ROOT_PASS" = "true" ] ; then \
    $LOGGER "Setting default root password to 'docker' (for development purposes only)"; \
    echo "root:docker" | chpasswd; \
  fi

# Create SSH directory for non-root user to ensure proper permissions
RUN mkdir -p /home/$USERNAME/.ssh \
  && chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh \
  && chmod 700 /home/$USERNAME/.ssh

# Install Homebrew for the non-root user
# Note: Homebrew on Linux doesn't require admin privileges when installed in home directory
USER $USERNAME
WORKDIR /home/$USERNAME

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# RUN git --version && $BREW --version

# Set USER back to root for next stage
USER root

# Set default command to login shell
CMD ["/bin/bash"]
# --------------------------------------------------------------


# --------------------------------------------------------------
# THIS IS THE base `devcontainer` TARGET
# --------------------------------------------------------------
FROM devuser AS base

# Set default to not reset root password, in case devcontainer inherits from devtools or cloudtools
# Precautionary measure to avoid interactive prompt when running devcontainer
ENV RESET_ROOT_PASS=false

# Copy post-start script
COPY .devcontainer/docker/utils/post-start.sh /usr/local/bin/post-start

USER root

RUN /tmp/lib-scripts/base-utils.sh \
  && chmod +x /usr/local/bin/post-start \
  && sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/post-start \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /tmp/lib-scripts/base-*.sh

# Switch to non-root user
USER $USERNAME
# WORKDIR /home/$USERNAME

RUN ! $PIPX || \
  $($PIPX) install pre-commit

# Set the default working directory
WORKDIR $DEFAULT_WORKSPACE

LABEL org.opencontainers.image.ref.name="$REPO_NAME:devcontainer-$BASE_IMAGE"
LABEL org.opencontainers.image.title="$REPO_NAME - devcontainer - $IMAGE_NAME - $VARIANT"
LABEL org.opencontainers.image.source=https://github.com/$REPO_NAMESPACE/$REPO_NAME
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

# Install Python via Homebrew, pipx, Poetry, uv, and other dev tools via Homebrew.
# Do nothing if PYTHON_VERSION is 'devcontainer' or matches the USERNAME.
# USERNAME cannot be 'system' or 'latest'.
RUN test "$NO_BREW_UPDATE" = "true" || $BREW update \
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
  && if $PIPX; then \
    $($PIPX) install \
      pre-commit \
      poetry \
      uv; \
    fi

ENTRYPOINT ["/docker-entrypoint.sh"]

# Set default command to login shell
CMD ["/bin/bash"]


FROM devtools AS cloudtools

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

RUN if $PIPX; then \
    $($PIPX) install cfn; \
  fi

# Verify installations
RUN aws --version && terraform version


FROM devtools AS codeserver

ARG BIND_ADDR=0.0.0.0:8080

# Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
ENV CODE_SERVER_WORKSPACE=$DEFAULT_WORKSPACE
ENV CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml
ENV CODE_SERVER_EXTENSIONS=$DEFAULT_WORKSPACE/.code-server/extensions/extensions.json

ENV BIND_ADDR=$BIND_ADDR
ENV DEBUG=false

COPY .devcontainer/docker/utils/start-code-server.sh /usr/local/bin/start-code-server

USER root

RUN apt-get update \
  && apt-get -y install --no-install-recommends tini \
  && chmod +x /usr/local/bin/start-code-server \
  && sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/start-code-server \
  && sed -i "s|\$PASSGEN|$PASSGEN|g" /usr/local/bin/start-code-server \
  && sed -i "s|\$DEV|$DEV|g" /usr/local/bin/start-code-server \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

USER $USERNAME

RUN test "$NO_BREW_UPDATE" = "true" || $BREW update \
  && $BREW install code-server

EXPOSE 8080

WORKDIR $DEFAULT_WORKSPACE

ENTRYPOINT ["/usr/bin/tini", "--"]

# CMD ["/start-code-server.sh"]
CMD ["/bin/sh", "-c", "start-code-server --config-only && set -x ; exec \
    /home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server \
      --bind-addr $BIND_ADDR \
      --extensions-dir \
      $(dirname $CODE_SERVER_EXTENSIONS) \
      ${CODE_SERVER_WORKSPACE:-.}"]


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
