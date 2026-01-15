# Must be debian-based image
ARG IMAGE_NAME=ubuntu
ARG VARIANT=${VARIANT:-latest}
ARG BASE_IMAGE=${IMAGE_NAME}:${VARIANT}
FROM ${BASE_IMAGE} AS base

# Set environment variables to non-interactive (this prevents some prompts)
ENV DEBIAN_FRONTEND=noninteractive

# Build arguments need to be re-declared if used in FROM instructions
# (https://docs.docker.com/build/building/variables/#scoping)
ARG IMAGE_NAME
ARG VARIANT
# Create a non-root user
ARG USERNAME=devcontainer
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG PASSGEN=/passgen.sh
ARG LOGGER=/logger.sh

# Repository information (required for image labels)
ARG REPO_NAME=devcontainer
ARG REPO_NAMESPACE=devcontainer

# Update and install essential packages
RUN \
  # Check for mandatory build arguments (https://stackoverflow.com/a/44791255)
  : "${REPO_NAME:?Build argument needs to be set and non-empty.}" \
  && \
  : "${REPO_NAMESPACE:?Build argument needs to be set and non-empty.}" && \
  # Update package lists and install packages
  apt-get update \
  && apt-get -y install --no-install-recommends \
  # Essential build tools
  build-essential \
  curl \
  wget \
  unzip \
  ca-certificates \
  # Additional utilities
  vim \
  nano \
  less \
  procps \
  lsb-release \
  tzdata \
  jq \
  yq \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN touch "$LOGGER" \
  && chmod +x $LOGGER \
  && cat > "$LOGGER" <<EOF
#!/bin/sh

# Simple logger script

LEVEL="\${LEVEL:-info}"

log() {
  local timestamp="\$(date +'%Y-%m-%d %H:%M:%S')"
  printf "[%s] [%s] %s\n" "\$timestamp" "\$(echo \$LEVEL | tr '[:lower:]' '[:upper:]')" "\$*" >&2
}

main() {
  if [ "\$#" -lt 1 ] ; then
    LEVEL=error log "Usage: logger.sh <message>"
    exit 1
  fi
  # Log the message
  log "\$@"
}

main "\$@"
EOF

# Create password generator script
RUN touch "$PASSGEN" \
  && chmod +x $PASSGEN \
  && cat > "$PASSGEN" <<EOF
#!/bin/sh

# Generate a random 32-character alphanumeric password
LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c${1:-32}
EOF


FROM base AS devuser

ARG PYTHON_VERSION=latest

ENV DEFAULT_ROOT_PASS=true

# Install sudo and fun packages
# We don't want to use --no-install-recommends here,
# since the games (and possibly sudo) may depend on some recommended packages.
RUN apt-get update \
  && apt-get -y install \
  # Install sudo here so production image doesn't have it
  sudo \
  # Git (required for homebrew installation)
  git \
  # Fun
  cowsay \
  fortune \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

ENV PATH="/home/$USERNAME/.local/bin:${PATH}"

# As of Ubuntu 24 (Noble Numbat), the Ubuntu base image comes with a non-root user ubuntu with UID 1000
# Delete this user to avoid conflicts when creating our own non-root user
RUN if [ "$IMAGE_NAME" = "ubuntu" ]; then \
  if id "ubuntu" &>/dev/null; then \
  $LOGGER "Deleting user 'ubuntu' for $IMAGE_NAME" && userdel -f -r ubuntu \
  || LEVEL=error $LOGGER "Failed to delete ubuntu user for $IMAGE_NAME"; \
  else \
  $LOGGER "User 'ubuntu' does not exist for $IMAGE_NAME"; \
  fi; \
  fi

# Ensure Homebrew is properly configured
# The brew shellenv line exports HOMEBREW_PREFIX, HOMEBREW_CELLAR,
# and HOMEBREW_REPOSITORY (INFOPATH is also set),
# in addition to prepending the brew 'bin' and 'sbin' to the PATH.
RUN cat >> /etc/skel/.bashrc <<EOF

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]
then
  eval "\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
EOF

RUN cat >> /etc/skel/.profile <<EOF

# https://docs.brew.sh/Shell-Completion
if type brew &>/dev/null
then
  HOMEBREW_PREFIX="$(brew --prefix)"
  if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]
  then
    source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*
    do
      [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
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
# Only for development purposes; can be changed at runtime
# DO NOT use in production environments
# Avoid using 'chpasswd' with here-string (e.g. chpasswd <<<"root:docker") as it may not be supported in some shells
RUN if [ "$DEFAULT_ROOT_PASS" = "true" ] ; then \
  $LOGGER "Setting default root password to 'docker' (for development purposes only)"; \
  echo "root:docker" | chpasswd; \
  fi

# Install Homebrew for the non-root user
# Note: Homebrew on Linux doesn't require admin privileges when installed in home directory
USER $USERNAME

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Set USER back to root for next stage
USER root


FROM devuser AS devtools

# Set default Python version
# ('system' to use system Python, 'latest' to use latest Homebrew Python, or specify version like '3.9', '3.10', etc.)
ARG PYTHON_VERSION=latest

ENV RESET_ROOT_PASS=true

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
  # Supporting tools for installations
  gnupg \
  software-properties-common \
  && if [ "$PYTHON_VERSION" = "system" ] ; then \
    # Python and related tools
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    pipx; \
  fi \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS version) and npm
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
  && apt-get -y install --no-install-recommends nodejs \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN touch "/docker-entrypoint.sh" \
  && chmod +x /docker-entrypoint.sh \
  && cat > "/docker-entrypoint.sh" <<EOF
#!/bin/sh

set -e

if [ "\$RESET_ROOT_PASS" = "true" ] ; then
  printf "\033[1m%s\033[0m\n" "Updating root password ..."
  sudo passwd root
fi

/usr/games/fortune | /usr/games/cowsay

exec "\$@"
EOF

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Needed to properly reference target version of python3
ENV PATH="/home/linuxbrew/.linuxbrew/opt/python3/bin:${PATH}"

RUN /home/linuxbrew/.linuxbrew/bin/brew update \
  && if [ "$PYTHON_VERSION" = "latest" ] ; then \
    /home/linuxbrew/.linuxbrew/bin/brew install python3; \
  elif [ "$PYTHON_VERSION" != "system" -a "$(python3 --version | awk -F. '{print $1"."$2}')" != "Python ${PYTHON_VERSION}" ] ; then \
    /home/linuxbrew/.linuxbrew/bin/brew install python@${PYTHON_VERSION}; \
  fi \
  && if [ "$PYTHON_VERSION" != "system" ] ; then \
    /home/linuxbrew/.linuxbrew/bin/brew install pipx; \
  fi \
  # Configure pipx, and install Poetry and uv
  && if [ "$PYTHON_VERSION" = "system" ] ; then \
    pipx install poetry uv; \
  else \
    /home/linuxbrew/.linuxbrew/bin/pipx install poetry uv; \
  fi \
  && /home/linuxbrew/.linuxbrew/bin/brew install \
    cfn-lint \
    pre-commit

# Verify installations
RUN git --version && python3 --version && node --version && npm --version

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["/bin/bash"]


FROM devtools AS cloudtools

USER root

RUN if [ "$(uname -m)" = "x86_64" ] \
  then \
    # Install AWS CLI v2 for x86_64
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
  else \
    # uname -m must be aarch64
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
  fi \
  && unzip -o awscliv2.zip \
  && ./aws/install --update \
  && rm -rf ./aws \
  && rm -f awscliv2.zip \
  && cat >> /home/$USERNAME/.bashrc <<EOF

# Enable AWS CLI bash completion
if command -v aws_completer >/dev/null 2>&1; then
  complete -C aws_completer aws
elif [ -x "/usr/local/bin/aws_completer" ]; then
  complete -C "/usr/local/bin/aws_completer" aws
elif [ -x "/opt/homebrew/bin/aws_completer" ]; then
  complete -C "/opt/homebrew/bin/aws_completer" aws
fi
EOF

RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor \
  | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
  && gpg --no-default-keyring \
  --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
  --fingerprint \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \
  $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/hashicorp.list \
  && apt-get update \
  && apt-get -y install --no-install-recommends terraform \
  && echo >> /home/$USERNAME/.bashrc \
  && echo 'complete -C /usr/bin/terraform terraform' >> /home/$USERNAME/.bashrc \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN [ -d /etc/apt/keyrings ] || mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && mkdir -p -m 755 /etc/apt/sources.list.d \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update \
  && apt-get -y install --no-install-recommends gh \
  && echo >> /home/$USERNAME/.bashrc \
  && echo 'eval "$(gh completion -s bash)"' >> /home/$USERNAME/.bashrc \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f $out

USER $USERNAME

# Verify installations
RUN aws --version && terraform version && gh --version


# --------------------------------------------------------------
# THIS IS THE `devcontainer` TARGET
# --------------------------------------------------------------
FROM devuser AS devcontainer

# Set default to not reset root password, in case devcontainer inherits from devtools or cloudtools
# Precautionary measure to avoid interactive prompt when running devcontainer
ENV RESET_ROOT_PASS=false

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

RUN /home/linuxbrew/.linuxbrew/bin/brew update \
  && /home/linuxbrew/.linuxbrew/bin/brew install \
  cfn-lint \
  pre-commit

# Set the default working directory
WORKDIR /home/$USERNAME/workspace

LABEL org.opencontainers.image.title="$REPO_NAME:devcontainer"
LABEL org.opencontainers.image.source=https://github.com/$REPO_NAMESPACE/$REPO_NAME
LABEL org.opencontainers.image.description="A simple Debian-based Docker image with essential development tools and Homebrew."
LABEL org.opencontainers.image.licenses=MIT

CMD ["/bin/bash"]
# --------------------------------------------------------------


FROM devtools AS codeserver

# Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
ENV CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml
ENV CODE_SERVER_EXTENSIONS=/home/$USERNAME/workspace/.code-server/extensions/extensions.json

ARG BIND_ADDR=0.0.0.0:8080

ENV BIND_ADDR=$BIND_ADDR
ENV DEV=false
ENV DEBUG=false

USER root

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
  # Tini for proper signal handling
  tini \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN touch "/start-code-server.sh" \
  && chmod +x /start-code-server.sh \
  && cat > "/start-code-server.sh" <<EOF
#!/bin/sh

[ \$DEBUG != "true" ] || exec /bin/bash

if [ "\$DEV" = "true" ] ; then
  $LOGGER "Running in DEV mode: disabling authentication for code-server"
  auth="none"
else
  $LOGGER "Set DEV=true to disable authentication for code-server"
  auth="password"
  export PASSWORD="\${PASSWORD:-\$($PASSGEN)}"
fi

config_dir="\$(dirname \$CODE_SERVER_CONFIG)"
extensions_dir="\$(dirname \$CODE_SERVER_EXTENSIONS)"
[ -d "\$config_dir" ] || \\
  mkdir -p "\$config_dir"
[ -d "\$extensions_dir" ] || \\
  mkdir -p "\$extensions_dir"

if [ -f "\$CODE_SERVER_EXTENSIONS" ]; then
  $LOGGER "Installing extensions from \$CODE_SERVER_EXTENSIONS"
  extension_ids=\$(jq -r '.[].identifier.id' "\$CODE_SERVER_EXTENSIONS")
else
  $LOGGER "Installing extensions from \$HOME/workspace/.vscode/extensions.json"
  # Use cpp preprocessor to strip comments in JSON
  # extension_ids=\$(cpp -P -E "\$HOME/workspace/.devcontainer/devcontainer.json" \\
  # 	| jq -r '.customizations.vscode.extensions[]')
  extension_ids=\$(cpp -P -E "\$HOME/workspace/.vscode/extensions.json" \\
    | jq -r '.recommendations[]')
fi
for extension_id in \$extension_ids; do
  $LOGGER "Installing extension: \$extension_id"
  /home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server \\
    --install-extension "\$extension_id" \\
    --extensions-dir "\$extensions_dir"
done

# File is either 'sourced', or no arguments passed, so set default parameters
[ -n "\$0" -a -n "\$1" ] || \\
  set -- \
    --bind-addr "\$BIND_ADDR" \
    --auth "\$auth" \
    --cert false \
    "\$HOME/workspace"

# Ensure all parameters are set
config_only=false
while [ "\$#" -gt 0 ] ; do
  case "\$1" in
    --config-only)
      shift
      config_only=true
      break
      ;;
    --bind-addr)
      bind_addr="\${2-}"
      shift 2
      ;;
    --auth)
      auth="\${2-}"
      shift 2
      ;;
    --cert)
      cert="\${2-}"
      shift 2
      ;;
    --)
      break
      ;;
    *)
      break
      ;;
  esac
done

# Create config file to prevent one from being auto-generated
# with incorrect values (since parameters are passed on CLI)
cat > "\$CODE_SERVER_CONFIG" <<EOT
bind-addr: \${bind_addr:-\$BIND_ADDR}
auth: \${auth:-password}
password: \${PASSWORD:-password}
cert: \${cert:-false}
EOT

if [ "\$config_only" != "true" ] ; then
  if [ -n "\${1-}" ] ; then
    $LOGGER "Starting code-server with workspace: \${1}"
  else
    $LOGGER "Starting code-server without a workspace"
  fi

  # Start code-server with the specified parameters
  exec /home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server \\
    --bind-addr \$bind_addr --auth \$auth --cert \$cert \\
    --extensions-dir \$extensions_dir \\
    "\${@:-.}"
fi
EOF

USER $USERNAME

RUN /home/linuxbrew/.linuxbrew/bin/brew update \
  && /home/linuxbrew/.linuxbrew/bin/brew install \
  cfn-lint \
  pre-commit \
  code-server

EXPOSE 8080

WORKDIR /home/$USERNAME/workspace

ENTRYPOINT ["/usr/bin/tini", "--"]

# CMD ["/start-code-server.sh"]
CMD ["/bin/sh", "-c", "/start-code-server.sh \
  --config-only \
  && exec /home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server \
  --extensions-dir $(dirname $CODE_SERVER_EXTENSIONS) \
  ${@:-.}"]


FROM base AS production

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
  # Tini for proper signal handling
  tini \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/tini", "--"]

# USER ubuntu
# WORKDIR /home/ubuntu

# Default command
CMD ["/bin/bash"]
