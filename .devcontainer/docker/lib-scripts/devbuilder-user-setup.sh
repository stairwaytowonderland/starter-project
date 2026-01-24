#!/usr/bin/env bash

# * Create a non-root user and set up bashrc and profile for both the new user and root
# * All variables are expected to be set via build args in the Dockerfile

set -e

LEVEL='*' $LOGGER "Setting up bashrc and profile for new users and root ..."

cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

# Ensure Homebrew is properly configured
# The brew shellenv line exports HOMEBREW_PREFIX, HOMEBREW_CELLAR,
# and HOMEBREW_REPOSITORY (INFOPATH is also set),
# in addition to prepending the brew 'bin' and 'sbin' to the PATH.
if type "$BREW" &>/dev/null
then
  eval "\$($BREW shellenv)"
fi
EOF

test "$PYTHON_VERSION" = "devcontainer" \
    || test "$PYTHON_VERSION" = "$USERNAME" \
    || test "$PYTHON_VERSION" = "system" \
    || cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

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

test "$PYTHON_VERSION" != "devcontainer" \
    && test "$PYTHON_VERSION" != "$USERNAME" \
    && test "$PYTHON_VERSION" != "system" \
    || cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

if type /usr/local/python/current/bin/python3 &>/dev/null
then
  PATH="/usr/local/python/current/bin:\${PATH}"
fi
EOF

echo | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null \
    && echo PATH="\"\$($FIXPATH)\"" | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null \
    && echo LOGGER="\"$LOGGER\"" | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null \
    && cat << EOF | tee -a /etc/skel/.profile /root/.profile > /dev/null

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

$LOGGER "Done! Bashrc and profile setup complete."

LEVEL='*' $LOGGER "Creating non-root user '$USERNAME' ..."

# Create a new non-root user with sudo privileges
groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME" -s /bin/bash \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME"

# Create SSH directory for non-root user to ensure proper permissions
mkdir -p "/home/$USERNAME/.ssh" \
    && chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh" \
    && chmod 700 "/home/$USERNAME/.ssh"

$LOGGER "Done! User '$USERNAME' created successfully."

# Set default password for root user to 'docker'
# Only for development purposes; password can be changed at runtime
# DO NOT use in production environments
# Avoid using 'chpasswd' with here-string (e.g. chpasswd <<<"root:docker") as it may not be supported in some shells
if [ "$DEFAULT_ROOT_PASS" = "true" ]; then
    # Extract ID from /etc/os-release to use as default root password (e.g., 'ubuntu', 'debian', etc.)
    prop=ID ID="$({ while IFS= read -r line; do printf '%s\n' "$line"; done < /etc/os-release; } | grep "^$prop=" | awk -F'=' '{print $2}')"
    $LOGGER "Setting default root password to '$ID' (for development purposes only)"
    echo "root:${ID:-docker}" | chpasswd
fi

# Add useful bash aliases system-wide
if ! type ll > /dev/null 2>&1; then
    echo >> /etc/bash.bashrc \
        && echo "alias ll='ls -alF' " >> /etc/bash.bashrc
fi

# Enable bash completion system-wide
cat >> /root/.bashrc << EOF
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
   . /etc/bash_completion
fi
EOF
