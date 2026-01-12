# Must be debian-based image
ARG IMAGE_NAME=ubuntu
ARG VARIANT=${VARIANT:-latest}
ARG BASE_IMAGE=${IMAGE_NAME}:${VARIANT}
FROM ${BASE_IMAGE} AS base

# Set environment variables to non-interactive (this prevents some prompts)
ENV DEBIAN_FRONTEND=noninteractive

# Build arguments need to be re-declared if used in FROM instructions
ARG IMAGE_NAME
ARG VARIANT
# Create a non-root user
ARG USERNAME=devcontainer
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG PASSGEN=/passgen.sh
ARG LOGGER=/logger.sh

# Update and install essential packages
RUN apt-get update \
	&& apt-get -y install --no-install-recommends \
		# Essential build tools
		build-essential \
		curl \
		wget \
		ca-certificates \
		# Additional utilities
		sudo \
		vim \
		nano \
		less \
		procps \
		lsb-release \
		tzdata \
		jq \
		yq \
		# Git (required for homebrew installation)
		git \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/*

RUN touch "$LOGGER" \
	&& chmod +x $LOGGER \
	&& cat > "$LOGGER" <<EOF
#!/bin/sh

# Simple logger script

LEVEL="\${LEVEL:-info}"

log() {
	local message="\$*"
	local timestamp="\$(date +'%Y-%m-%d %H:%M:%S')"
	echo "[\$timestamp] [\$(echo \$LEVEL | tr '[:lower:]' '[:upper:]')] \$message" >&2
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


FROM base AS usersetup

# As of Ubuntu 24 (Noble Numbat), the Ubuntu base image comes with a non-root user ubuntu with UID 1000
# Delete this user to avoid conflicts when creating our own non-root user
RUN if [ "$IMAGE_NAME" = "ubuntu" ]; then \
        if id "ubuntu" &>/dev/null; then \
            $LOGGER "Deleting user 'ubuntu' for $IMAGE_NAME" && userdel -f -r ubuntu || echo "Failed to delete ubuntu user for $IMAGE_NAME"; \
        else \
            $LOGGER "User 'ubuntu' does not exist for $IMAGE_NAME"; \
        fi; \
    fi

# Create a new non-root user with sudo privileges
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME


FROM usersetup AS devtools

ARG PYTHON_VERSION=3.12

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		# Python and related tools
		python3 \
		python3-pip \
		python3-venv \
		python3-dev \
		pipx \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/*

RUN python3 --version | awk -F. '{print $1"."$2}' > /python-version \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends software-properties-common \
	&& add-apt-repository -y ppa:deadsnakes/ppa \
	&& apt-get update \
	&& if [ "$(cat /python-version)" != "Python ${PYTHON_VERSION}" ] ; then \
		apt-get install -y --no-install-recommends \
			# Python specific version
			python${PYTHON_VERSION} \
			python${PYTHON_VERSION}-venv \
			python${PYTHON_VERSION}-dev \
		&& python3 --version > /python-version ; \
	fi \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS version) and npm
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends \
		nodejs \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Ensure target version of python is used
RUN rm -f /usr/bin/python3 \
	&& ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
	&& ln -s /usr/bin/python3 /usr/bin/python

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Configure pipx, and install Poetry and uv
# RUN python3 -m pipx ensurepath
RUN pipx install poetry uv

# Verify installations
RUN git --version && python3 --version && node --version && npm --version


FROM usersetup AS devcontainer

# Add Homebrew to PATH for the user
# ENV PATH="/home/$USERNAME/.local/bin:${PATH}"
# ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Install Homebrew for the non-root user
# Note: Homebrew on Linux doesn't require admin privileges when installed in home directory
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ensure Homebrew is properly configured
RUN echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/$USERNAME/.bashrc \
    && echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/$USERNAME/.profile

ENV PATH="/home/$USERNAME/.local/bin:${PATH}"

# Update Homebrew and install some packages
RUN /home/linuxbrew/.linuxbrew/bin/brew update \
	&& /home/linuxbrew/.linuxbrew/bin/brew install \
		pre-commit

# Set the default working directory
WORKDIR /home/$USERNAME/workspace

LABEL org.opencontainers.image.title="simple-project:devcontainer"
LABEL org.opencontainers.image.source=https://github.com/stairwaytowonderland/simple-project
LABEL org.opencontainers.image.description="A simple Debian-based Docker image with essential development tools and Homebrew."
LABEL org.opencontainers.image.licenses=MIT


FROM devcontainer AS codeserver

# Don't put CODE_SERVER_CONFIG in workspace directly to avoid issues with volume mounts
ENV CODE_SERVER_CONFIG=/home/$USERNAME/.config/code-server/config.yaml
ENV CODE_SERVER_EXTENSIONS_DIR=/home/$USERNAME/workspace/.code-server/extensions

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

RUN touch "/docker-cmd.sh" \
	&& chmod +x /docker-cmd.sh \
	&& chown $USERNAME:$USERNAME "/docker-cmd.sh" \
	&& cat > "/docker-cmd.sh" <<EOF
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

[ -n "\$0" -a -n "\$1" ] || \\
	set -- "\$HOME/workspace"

config_dir="\$(dirname \$CODE_SERVER_CONFIG)"
[ -d "\$config_dir" ] || \\
	mkdir -p "\$config_dir"
[ -d "\$CODE_SERVER_EXTENSIONS_DIR" ] || \\
	mkdir -p "\$CODE_SERVER_EXTENSIONS_DIR"

if [ -f "\$CODE_SERVER_EXTENSIONS_DIR/extensions.json" ]; then
	$LOGGER "Installing extensions from \$CODE_SERVER_EXTENSIONS_DIR/extensions.json"
	extension_ids=\$(jq -r '.[].identifier.id' "\$CODE_SERVER_EXTENSIONS_DIR/extensions.json")
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
		--extensions-dir "\$CODE_SERVER_EXTENSIONS_DIR"
done

# Create config file to prevent one from being auto-generated
# with incorrect values (since parameters are passed on CLI)
cat > "\$CODE_SERVER_CONFIG" <<EOT
bind-addr: \$BIND_ADDR
auth: \$auth
password: \${PASSWORD:-password}
cert: false
EOT

# Start code-server with the specified parameters
exec /home/linuxbrew/.linuxbrew/opt/code-server/bin/code-server \\
  --bind-addr \$BIND_ADDR --auth \$auth --cert false \\
  --extensions-dir \$CODE_SERVER_EXTENSIONS_DIR \\
  "\$@"
EOF

USER $USERNAME

RUN /home/linuxbrew/.linuxbrew/bin/brew install code-server

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/docker-cmd.sh"]


FROM base AS production

RUN apt-get update \
	&& apt-get -y install --no-install-recommends \
		# Tini for proper signal handling
		tini \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/tini", "--"]

# Default command
CMD ["/bin/bash"]
