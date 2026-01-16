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
ARG FIXPATH=/fixpath.sh
ARG TIMEZONE=UTC
# Repository information (required for image labels)
ARG REPO_NAME=devcontainer
ARG REPO_NAMESPACE=devcontainer
# Package management control
ARG DEV=false
ARG NO_BREW_UPDATE=$DEV
# Other
ARG DEFAULT_PASS_LENGTH=32
ARG DEFAULT_PASS_CHARSET='a-zA-Z0-9'
ARG DEFAULT_WORKSPACE=/home/$USERNAME/workspace

ENV TZ=$TIMEZONE
ENV DEV=$DEV
ENV DEFAULT_WORKSPACE=$DEFAULT_WORKSPACE

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

# Usage: [LEVEL=<level>] $LOGGER <message>
#
# Arguments:
#   message: Message to log
#
# Output:
#   Logs message with timestamp and log level (default: info)

LEVEL="\${LEVEL:-info}"

log() {
  local timestamp="\$(date +'%Y-%m-%d %H:%M:%S')"
  printf "[%s] [%s] %s\n" "\$timestamp" "\$(echo \$LEVEL | tr '[:lower:]' '[:upper:]')" "\$*" >&2
}

main() {
  if [ "\$#" -lt 1 ] ; then
    LEVEL=error log "Usage: [LEVEL=<level>] $LOGGER <message>"
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

# Generate a random $DEFAULT_PASS_LENGTH-character (unless specified) alphanumeric password

# Usage: $PASSGEN [length] [charset]
#
# Arguments:
#   length: Length of password to generate (default: $DEFAULT_PASS_LENGTH)
#   charset: Characters to use for password generation (default: $DEFAULT_PASS_CHARSET)
#
# Output:
#   Randomly generated password

LC_ALL=C tr -dc "${2:-$DEFAULT_PASS_CHARSET}" < /dev/urandom | head -c${1:-$DEFAULT_PASS_LENGTH}
EOF

RUN touch "$FIXPATH" \
  && chmod +x $FIXPATH \
  && cat > "$FIXPATH" <<EOF
#!/bin/sh

set -eu

# Fix PATH to use the PATH variable from /etc/environment

# Usage: $FIXPATH [term]
#
# Arguments:
#   term: Term to search for in PATH (default: /usr/local/sbin)
#        Expected to be the first common entry in the
#        /etc/environment PATH and exported PATH. Typically
#        the first entry in PATH, and usually /usr/local/sbin
#        for Debian-based systems.
#
# Output:
#   Fixed PATH string

term=\${1:-/usr/local/sbin}
search=\$(echo "\$PATH" | awk -F"\${term}:" '{print \$2}')
replace=\$(sed -nE '1s|^PATH=\"(.*)\"|\1|p' /etc/environment 2>/dev/null)

if ! echo "\$PATH" | grep -q "\$replace" ; then
  replaced=\$(echo "\$PATH" | sed "s|\$search|\$replace|g" 2>/dev/null)
  PATH=\$(echo "\$replaced" | sed "s|\${term}:||" 2>/dev/null)
fi

# Remove duplicate entries from PATH
# https://unix.stackexchange.com/questions/40749/remove-duplicate-path-entries-with-awk-command
__path=\$PATH:
PATH=
while [ -n "\$__path" ]; do
  x=\${__path%%:*}          # Extract the first entry
  case \$PATH: in
    *:"\$x":*) ;;           # If already in PATH, do nothing
    *) PATH=\$PATH:\$x;;    # Otherwise, append it
  esac
  __path=\${__path#*:}      # Remove the first entry from the list
done
PATH=\${PATH#:}             # Remove the leading colon

printf "%s" "\$PATH"
EOF

RUN cat >> /root/.bashrc <<EOF
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
   . /etc/bash_completion
fi
EOF

RUN "$TIMEZONE" = "UTC" || \
  ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && $LOGGER "Timezone set to '$TIMEZONE'"


FROM base AS devuser

# Set default Python version
# ('system' to use system Python, 'latest' to use latest Homebrew Python, or specify version like '3.9', '3.10', etc.)
ARG PYTHON_VERSION=latest
# Whether to set default root password to 'docker' at build time
# (for development purposes only; password can be changed at runtime)
ARG DEFAULT_ROOT_PASS=$DEV
# Default path to Homebrew binary (for convenience; not likely to change)
ARG DEFAULT_BREW_PATH=/home/linuxbrew/.linuxbrew/bin/brew

# Export PYTHON_VERSION for convenience
ENV PYTHON_VERSION=$PYTHON_VERSION
# Update PATH here so that all shells contain the updated PATH
ENV PATH="/home/$USERNAME/.local/bin:${PATH}"

# Install sudo and fun packages
RUN apt-get update \
  && apt-get -y install --no-install-recommends \
    # Install sudo here so production image doesn't have it
    sudo \
    # Git (required for homebrew installation)
    git \
  # We don't want to use --no-install-recommends here,
  # since the games (and possibly sudo) may depend on some recommended packages.
  && apt-get -y install \
    # Fun
    cowsay \
    fortune \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

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

RUN cat <<EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

# Ensure Homebrew is properly configured
# The brew shellenv line exports HOMEBREW_PREFIX, HOMEBREW_CELLAR,
# and HOMEBREW_REPOSITORY (INFOPATH is also set),
# in addition to prepending the brew 'bin' and 'sbin' to the PATH.
if type "$DEFAULT_BREW_PATH" &>/dev/null
then
  eval "\$($DEFAULT_BREW_PATH shellenv)"
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
  && test "$PYTHON_VERSION" = "system" || \
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
  if [[ -r "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]
  then
    source "\${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "\${HOMEBREW_PREFIX}/etc/bash_completion.d/"*
    do
      [[ -r "\${COMPLETION}" ]] && source "\${COMPLETION}"
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

# Install Homebrew for the non-root user
# Note: Homebrew on Linux doesn't require admin privileges when installed in home directory
USER $USERNAME
WORKDIR /home/$USERNAME

RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Set USER back to root for next stage
USER root

# Set default command to login shell
CMD ["/bin/bash"]


FROM devuser AS devtools

# Whether to reset root password at container startup
# (true/false; default: $DEFAULT_ROOT_PASS build argument)
ENV RESET_ROOT_PASS=$DEFAULT_ROOT_PASS
# Needed to properly reference target version of python3
# ENV PATH="/home/linuxbrew/.linuxbrew/opt/python3/bin:${PATH}"

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

if type /usr/games/fortune >/dev/null 2>&1 \
  && type /usr/games/cowsay >/dev/null 2>&1
then
  /usr/games/fortune | /usr/games/cowsay
fi

exec "\$@"
EOF

# Switch to non-root user
USER $USERNAME

# Install Python via Homebrew, pipx, Poetry, uv, and other dev tools via Homebrew.
# Do nothing if PYTHON_VERSION is 'devcontainer' or matches the USERNAME.
# USERNAME cannot be 'system' or 'latest'.
RUN test "$PYTHON_VERSION" = "devcontainer" -o test "$PYTHON_VERSION" = "$USERNAME" || \
    test "$NO_BREW_UPDATE" = "true" || $DEFAULT_BREW_PATH update \
  && if [ "$PYTHON_VERSION" = "latest" ] ; then \
    $DEFAULT_BREW_PATH install python3; \
  elif [ "$PYTHON_VERSION" != "system" -a "$(python3 --version | awk -F. '{print $1"."$2}')" != "Python ${PYTHON_VERSION}" ] ; then \
    $DEFAULT_BREW_PATH install python@${PYTHON_VERSION}; \
  fi \
  # Install pipx after Python
  && if [ "$PYTHON_VERSION" != "system" ] ; then \
    $DEFAULT_BREW_PATH install pipx; \
  fi \
  # Configure pipx, and install Poetry and uv after ensuring pipx is installed
  && if [ "$PYTHON_VERSION" = "system" ] ; then \
    pipx install poetry uv; \
  else \
    "$(dirname $DEFAULT_BREW_PATH)/pipx" install poetry uv; \
  fi \
  && $DEFAULT_BREW_PATH install \
    cfn-lint \
    pre-commit

# Verify installations
RUN git --version && python3 --version && node --version && npm --version

ENTRYPOINT ["/docker-entrypoint.sh"]

# Set default command to login shell
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
if type aws_completer &>/dev/null
then
  complete -C aws_completer aws
elif type /usr/local/bin/aws_completer &>/dev/null; then
  complete -C "/usr/local/bin/aws_completer" aws
elif type /opt/homebrew/bin/aws_completer &>/dev/null; then
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
# WORKDIR /home/$USERNAME

RUN test "$NO_BREW_UPDATE" = "true" || $DEFAULT_BREW_PATH update \
  && $DEFAULT_BREW_PATH install cfn-lint

# Set the default working directory
WORKDIR $DEFAULT_WORKSPACE

LABEL org.opencontainers.image.title="$REPO_NAME:devcontainer"
LABEL org.opencontainers.image.source=https://github.com/$REPO_NAMESPACE/$REPO_NAME
LABEL org.opencontainers.image.description="A simple Debian-based Docker image with essential development tools and Homebrew."
LABEL org.opencontainers.image.licenses=MIT
# --------------------------------------------------------------


FROM devtools AS codeserver

ARG BIND_ADDR=0.0.0.0:8080

# Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
ENV CODE_SERVER_WORKSPACE=$DEFAULT_WORKSPACE
ENV CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml
ENV CODE_SERVER_EXTENSIONS=$DEFAULT_WORKSPACE/.code-server/extensions/extensions.json

ENV BIND_ADDR=$BIND_ADDR
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

if [ "\${DEV:-$DEV}" = "true" ] ; then
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
  $LOGGER "Installing extensions from \$CODE_SERVER_WORKSPACE/.vscode/extensions.json"
  # Use cpp preprocessor to strip comments in JSON
  # extension_ids=\$(cpp -P -E "\$CODE_SERVER_WORKSPACE/.devcontainer/devcontainer.json" \\
  # 	| jq -r '.customizations.vscode.extensions[]')
  extension_ids=\$(cpp -P -E "\$CODE_SERVER_WORKSPACE/.vscode/extensions.json" \\
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
    "\$CODE_SERVER_WORKSPACE"

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

  workspace_dir="\${CODE_SERVER_WORKSPACE:-.}"
  [ -d "$workspace_dir" ] || \\
    mkdir -p "$workspace_dir"

  # Start code-server with the specified parameters
  set -x
  exec /home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server \\
    --bind-addr \$bind_addr --auth \$auth --cert \$cert \\
    --extensions-dir \$extensions_dir \\
    "\${@:-\$workspace_dir}"
fi
EOF

USER $USERNAME

RUN test "$NO_BREW_UPDATE" = "true" || $DEFAULT_BREW_PATH update \
  && $DEFAULT_BREW_PATH install code-server

EXPOSE 8080

WORKDIR $DEFAULT_WORKSPACE

ENTRYPOINT ["/usr/bin/tini", "--"]

# CMD ["/start-code-server.sh"]
CMD ["/bin/sh", "-c", "/start-code-server.sh --config-only && set -x ; exec \
    /home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server \
      --bind-addr $BIND_ADDR \
      --extensions-dir \
      $(dirname $CODE_SERVER_EXTENSIONS) \
      ${CODE_SERVER_WORKSPACE:-.}"]


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
