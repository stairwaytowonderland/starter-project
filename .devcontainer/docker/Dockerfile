# Must be debian-based image
ARG IMAGE_NAME=ubuntu
ARG VARIANT=${VARIANT:-latest}
ARG BASE_IMAGE=${IMAGE_NAME}:${VARIANT}
ARG DEV_PARENT_IMAGE=devuser

# --------------------------------------------------------------
# Generator stage for core helper scripts
# --------------------------------------------------------------
FROM scratch AS filez

ARG LOGGER=/usr/local/bin/logger.sh \
    PASSGEN=/usr/local/bin/passgen.sh \
    DEFAULT_PASS_CHARSET='[:graph:]' \
    DEFAULT_PASS_LENGTH=32

ENV PASSGEN=$PASSGEN \
    CODESERVER_PASS_LENGTH=$DEFAULT_PASS_LENGTH \
    CODESERVER_PASS_CHARSET=$DEFAULT_PASS_CHARSET

COPY --chmod=755 <<EOF $LOGGER
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
QUIET="\${QUIET:-false}"

__log() {
  timestamp="\$(date +'%Y-%m-%d %H:%M:%S')"
  template="[%s] [%s] %s"

  case "\$LEVEL" in
    debug|info|warning|error)
      LEVEL="\$(echo "\$LEVEL" | tr '[:lower:]' '[:upper:]')"
      ;;
    \*|\√|\ƒ)
      template="[%s] (%s) %s"
      ;;
    \!)
      template="[%s] (%s) Error! %s"
      ;;
    *) LEVEL="info" ;;
  esac

  printf "\${template}\\n" "\${timestamp}" "\${LEVEL}" "\$*" >&2
}

__logger() {
  if [ "\$#" -lt 1 ] ; then
    LEVEL=error __log "Usage: [LEVEL=<level>] $LOGGER <message>"
    exit 1
  fi
  # Log the message
  __log "\$@"
}

[ "\$QUIET" = "true" ] || __logger "\$@"
EOF

COPY --chmod=755 <<EOF $PASSGEN
#!/bin/sh

# Generate a random $DEFAULT_PASS_LENGTH-character alphanumeric password (unless otherwise specified)

# Usage: $PASSGEN [simple|requirements] [length] [charset|min_char_per_fam]
#
# Arguments:
#   mode: 'simple' for simple password generation (default)
#         'requirements' for password generation with character family requirements
#   length: Length of password to generate (default: $DEFAULT_PASS_LENGTH)
#   charset: Characters to use for password generation (simple mode only; default: $DEFAULT_PASS_CHARSET)
#           Use '[:graph:]' for all printable characters (except space)
#           Use '[:alnum:]' for alphanumeric characters plus digits
#           Use a custom set of characters (e.g. '0-9a-zA-Z!@#\$%^&*()')
#   min_char_per_fam: Minimum characters per family (requirements mode only; default: 2)
#
# Output:
#   Randomly generated password

DEFAULT_PASS_LENGTH="\${DEFAULT_PASS_LENGTH:-$DEFAULT_PASS_LENGTH}"
DEFAULT_PASS_CHARSET="\${DEFAULT_PASS_CHARSET:-$DEFAULT_PASS_CHARSET}"
DEFAULT_MAX_QTY="\${DEFAULT_MAX_QTY:-10000}"

simple_pass() {
    # Does not guarantee character family requirements

    full_charset='[:graph:]'
    alpha_charset='[:alnum:]'
    custom_charset='0-9a-zA-Z!%^&.@\$*_:.,?-'
    default_charset="\${DEFAULT_PASS_CHARSET:-\$full_charset}"
    LC_ALL=C tr -dc "\${2:-\$default_charset}" < /dev/urandom | head -c"\${1:-\$DEFAULT_PASS_LENGTH}" || usage \$?
}

requirements_pass() {
    # Guarantees at least 2 characters from each character family: digits, lowercase, uppercase, special

    max_string_len=\${1:-\$DEFAULT_PASS_LENGTH}
    min_char_per_fam=\${2:-2}

    tr_num='0-9'
    tr_lower='a-z'
    tr_upper='A-Z'
    tr_special='!%^&.@\$*_:.,?-'
    tr_special_addtl='~#|<>[]\{\}()\/+=;'

    set -- "\$tr_num" "\$tr_lower" "\$tr_upper" "\$tr_special" "\$tr_special_addtl"
    count="\$#"
    shift \$count

    remaining_chars="\$(( max_string_len - \$count * min_char_per_fam ))"
    if [ \$remaining_chars -lt 0 ]; then remaining_chars=0 ; fi

    ( \\
          ( LC_CTYPE=C tr -dc "\${tr_num}"     </dev/urandom | head -c "\${min_char_per_fam}" ) \\
        ; ( LC_CTYPE=C tr -dc "\${tr_lower}"   </dev/urandom | head -c "\${min_char_per_fam}" ) \\
        ; ( LC_CTYPE=C tr -dc "\${tr_upper}"   </dev/urandom | head -c "\${min_char_per_fam}" ) \\
        ; ( LC_CTYPE=C tr -dc "\${tr_special}" </dev/urandom | head -c "\${min_char_per_fam}" ) \\
        ; ( LC_CTYPE=C tr -dc "\${tr_special_addtl}" </dev/urandom | head -c "\${min_char_per_fam}" ) \\
        ; ( LC_CTYPE=C tr -dc "\${tr_num}\${tr_lower}\${tr_upper}\${tr_special}\${tr_special_addtl}" </dev/urandom | head -c "\${remaining_chars}" ) \\
    ) | fold -w1 | shuf | tr -d '\n' || usage \$?
}

usage() {
    code="\${1:-0}"
    cat <<EOT >&2
Usage: $PASSGEN [-quantity] [mode] [options] [positional_args]
Arguments:
  quantity: Number of passwords to generate (default: 1; max: 99)
  mode: '-s|--simple' for simple password generation (default)
        '-r|--requirements' for password generation with character family requirements

Options (must be used with modes):
  -l, --length <n>              Password length (default: $DEFAULT_PASS_LENGTH)
  -c, --charset <chars>         Character set for simple mode
  -m, --min-char-per-fam <n>    Minimum characters per family for requirements mode (default: 2)

Positional args (alternative to options):
  length: Length of password to generate
  charset|min_char_per_fam: Charset for simple mode or min chars for requirements mode

Examples:
  $PASSGEN 64
  $PASSGEN -5 20
  $PASSGEN 20 '0-9a-zA-Z!@#\\\$%^&*()'
  $PASSGEN -r -l 16
  $PASSGEN -s -l 32 -c 'a-zA-Z0-9!@#\\\$%^&*()'
  $PASSGEN -5 -r -l 20
  $PASSGEN --simple 12 'a-zA-Z0-9'
  $PASSGEN --requirements 16 3
EOT
    exit "\$code"
}

parse_args() {
    case "\$1" in
        -s|--simple)
            shift
            while [ "\$#" -gt 0 ]; do
                case "\$1" in
                    -l|--length) length="\$2"; shift 2 ;;
                    -c|--charset) charset="\$2"; shift 2 ;;
                    -m|--min-char-per-fam)
                        LEVEL='!' $LOGGER "-m|--min-char-per-fam is not valid with -s|--simple mode"
                        usage 1
                        ;;
                    *) break ;;
                esac
            done
            simple_pass "\${length:-\$1}" "\${charset:-\$2}"
            return \$?
            ;;
        -r|--requirements)
            shift
            while [ "\$#" -gt 0 ]; do
                case "\$1" in
                    -l|--length) length="\$2"; shift 2 ;;
                    -m|--min-char-per-fam) min_char="\$2"; shift 2 ;;
                    -c|--charset)
                        LEVEL='!' $LOGGER "-c|--charset is not valid with -r|--requirements mode"
                        usage 1
                        ;;
                    *) break ;;
                esac
            done
            requirements_pass "\${length:-\$1}" "\${min_char:-\$2}"
            return \$?
            ;;
        *)
            simple_pass "\$@"
            return \$?
            ;;
    esac
}

passgen() {
    qty=0
    first_arg="\${1-}"
    if echo "\$first_arg" | grep -qE "^-[0-9]+$"; then
        qty="\${first_arg#-}"
        shift
    fi
    if [ \$qty -gt 0 ] && [ \$qty -lt "\$DEFAULT_MAX_QTY" ]; then
        count=0
        while [ \$count -lt \$qty ]; do
            printf "%s\\n" "\$(parse_args \$@)"
            count=\$(( count + 1 ))
        done
    else
        parse_args "\$@"
    fi
}

passgen "\$@"
EOF

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
ENV TZ=$TIMEZONE \
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

# --------------------------------------------------------------


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
    # Path to pipx binary locator script
    PIPX=/usr/local/bin/pipxpath.sh \
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

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/devbuilder*.sh \
    .devcontainer/docker/lib-scripts/git-install.sh \
    /tmp/lib-scripts/

RUN /tmp/lib-scripts/devbuilder-generators.sh \
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

# Default user workspace directory
ARG DEFAULT_WORKSPACE=/home/$USERNAME/workspace \
    PRE_COMMIT_ENABLED=false

ENV DEFAULT_WORKSPACE=$DEFAULT_WORKSPACE \
    # Set default to not reset root password, in case devcontainer inherits from devtools or cloudtools
    # Precautionary measure to avoid interactive prompt when running devcontainer
    RESET_ROOT_PASS=false

# Copy library scripts
COPY --chmod=755 .devcontainer/docker/lib-scripts/base-*.sh /tmp/lib-scripts/
# Copy post-start script
COPY --chmod=755 .devcontainer/docker/utils/post-start.sh /usr/local/bin/post-start

# Copy shfmt installation from gobuilder stage
COPY --from=gobuilder /usr/local/bin/shfmt /usr/local/bin/shfmt

USER root

RUN sed -i "s|\$LOGGER|$LOGGER|g" /usr/local/bin/post-start \
  && /tmp/lib-scripts/base-utils.sh \
  # Cleanup
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/* \
  # Create healthcheck lock file
  && touch /.healthcheck \
  && chmod 666 /.healthcheck

COPY --chmod=755 <<EOF /usr/local/bin/healthcheck.sh
#!/bin/sh

set -e

healthcheck="/.healthcheck"

cleanup() {
  code=\${1:-\$?}
  [ "\$code" -eq 0 ] \\
    && $LOGGER "** Exiting cleanly. Bye!" \\
    || $LOGGER "** Exiting with code \${code}. Bye!"
}

handle_int() {
  code=\$?
  $LOGGER "** Detected interrupt (\${code}). Cleanup..."
  trap - EXIT
  cleanup \$code
  exit
}

trap handle_int INT
trap cleanup EXIT

out="/dev/null"
case "\$1" in
  -i|--interactive)
    out="/dev/stdout"
    ;;
  *)
    ;;
esac

echo q \\
  | watch -n 5 -e '[ "\$(cat '"\$healthcheck"')x" != "x" ] && cat '"\$healthcheck"' || false' >"\$out" 2>&1 \\
  || handle_int

## Use `while read` loop instead of `watch` to allow for interrupt handling with CTRL+D (EOF)
# while read -r line; do
#   cat \$healthcheck > /dev/null 2>&1
# done
EOF

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

# Whether to reset root password at container startup
# (true/false; default: $DEFAULT_ROOT_PASS build argument)
ENV RESET_ROOT_PASS=$DEFAULT_ROOT_PASS
# Needed to properly reference target version of python3
# ENV PATH="/home/linuxbrew/.linuxbrew/opt/python3/bin:$PATH"

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
COPY --chmod=755 .devcontainer/docker/utils/start-code-server.sh /usr/local/bin/start-code-server

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
COPY --chmod=755 .devcontainer/docker/utils/start-code-server.sh /usr/local/bin/start-code-server

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
