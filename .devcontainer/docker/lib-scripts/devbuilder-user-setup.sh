#!/usr/bin/env bash

# * Description: Create a non-root user and set up bashrc and profile for both the new user and root

# Only check for errors (set -e)
# Don't check for unset variables (set -u) since variables are set in Dockerfile
# Pipepail (set -o pipefail) is not available in sh
set -e

LEVEL='*' $LOGGER "Setting up bashrc and profile for new users and root ..."

# Comment out the bash_aliases sourcing block in /etc/skel/.bashrc
comment_out_bash_aliases() {
    local file="$1"
    if [ -f "$file" ]; then
        sed -i -E '/if[[:space:]]+\[[[:space:]]+-f[[:space:]]+~\/\.bash_aliases[[:space:]]*\];?[[:space:]]*then/,/^[[:space:]]*fi[[:space:]]*$/s/^/# /' "$file"
    fi
}
comment_out_bash_aliases /etc/skel/.bashrc
comment_out_bash_aliases /root/.bashrc

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

cat << EOF | tee -a /etc/skel/.bashrc /root/.bashrc > /dev/null

PATH="\$($FIXPATH)"

C_BOLD="\033[1m" C_UNDERLINE="\033[4m" C_REVERSE="\033[7m" \\
C_DEFAULT="\033[0m" C_RESET="\033[0m" C_NORM="\033[0m" \\
C_RED="\033[31m" C_GREEN="\033[32m" C_YELLOW="\033[33m" \\
C_BLUE="\033[34m" C_MAGENTA="\033[35m" C_CYAN="\033[36m" \\
C_RED_BOLD="\033[1;31m" C_GREEN_BOLD="\033[1;32m" \\
C_YELLOW_BOLD="\033[1;33m" C_BLUE_BOLD="\033[1;34m" \\
C_MAGENTA_BOLD="\033[1;35m" C_CYAN_BOLD="\033[1;36m" \\
C_BRIGHT_RED="\033[91m" C_BRIGHT_GREEN="\033[92m" \\
C_BRIGHT_YELLOW="\033[93m" C_BRIGHT_BLUE="\033[94m" \\
C_BRIGHT_MAGENTA="\033[95m" C_BRIGHT_CYAN="\033[96m" \\
C_BRIGHT_RED_BOLD="\033[1;91m" C_BRIGHT_GREEN_BOLD="\033[1;92m" \\
C_BRIGHT_YELLOW_BOLD="\033[1;93m" C_BRIGHT_BLUE_BOLD="\033[1;94m" \\
C_BRIGHT_MAGENTA_BOLD="\033[1;95m" C_BRIGHT_CYAN_BOLD="\033[1;96m" \\
C_WHITE="\033[97m" C_WHITE_BOLD="\033[1;97m" \\
C_BLACK="\033[30m" C_BLACK_BOLD="\033[1;30m"

# Standardizes error output
# Usage: errcho "Error message here"
errcho() { >&2 echo -e "\$@"; }

# OS Detection
os() {
    if [ -r /etc/os-release ]
    then
        (. /etc/os-release; echo "\${ID-}-\${VERSION_CODENAME-}")
    else
        errcho "Unable to determine OS: /etc/os-release not found"
    fi
}

# String Manipulation
# Usage:
#     uppercase "string to convert"
#     echo "string to convert" | uppercase
#     lowercase "STRING TO CONVERT"
#     echo "STRING TO CONVERT" | lowercase
uppercase() {
    if [ -n "\$1" ]
    then
        tr '[:lower:]' '[:upper:]' <<<"\$@"
    else
        tr '[:lower:]' '[:upper:]'
    fi
}
lowercase() {
    if [ -n "\$1" ]
    then
        tr '[:upper:]' '[:lower:]' <<<"\$@"
    else
        tr '[:upper:]' '[:lower:]'
    fi
}

# Boolean Checks
# Usage:
#     is_bool "value"
#     is_true "value"
#     is_false "value"
#     is "value" && echo "Value is true" || echo "Value is false"
is_bool() {
    case "\$1" in
        y|Y|yes|Yes|YES|n|N|no|No|NO|true|True|TRUE|false|False|FALSE|on|On|ON|off|Off|OFF|1|0) errcho true;;
        *) errcho false; return 1;;
    esac
}
is_true() {
    case "\$1" in
        y|Y|yes|Yes|YES|true|True|TRUE|on|On|ON|1) errcho true;;
        *) errcho false; return 1;;
    esac
}
is_false() {
    local err=0
    is_bool "\$1" >/dev/null 2>&1 && ! is_true "\$1" >/dev/null 2>&1 || err=\$?
    [ "\$err" -gt 0 ] && errcho false && return \$err || errcho true
}
is() { is_true "\$1" 2>/dev/null || return \$?; }

# A mostly POSIX Compliant Decimal Comparison
# Simple decimal comparison function.
# Last (4th) argument defaults to false; Setting to true will cause
# the function to return 0 or 1 based on success or failure of the comparison,
# causing an error code of 1 if the comparison fails.
# Usage:
# testd <value1> <value2> <operator> [true|false]
# Example:
# testd 1.0 eq 1.1
# testd 1.0 eq 1.1 eq false
testd() {
    local value1="\${1-}" operator="\${2-}" value2="\${3-}" err=0
    case "\$operator" in
        'eq'|'==') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a == b ) exit 0; else exit 1 } '; err=\$? ;;
        'ne'|'!=') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a != b ) exit 0; else exit 1 } '; err=\$? ;;
        'gt'|'>') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a > b ) exit 0; else exit 1 } '; err=\$? ;;
        'ge'|'>=') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a >= b ) exit 0; else exit 1 } '; err=\$? ;;
        'lt'|'<') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a < b ) exit 0; else exit 1 } '; err=\$? ;;
        'le'|'<=') set +e; awk -v a="\$value1" -v b="\$value2" ' BEGIN { if ( a <= b ) exit 0; else exit 1 } '; err=\$? ;;
        *) err=2 ;;
    esac
    echo "\$-" | grep -Eqv '[e]' || set -e
    case "\$err" in
        0) errcho true; [ "true" != "\${4:-false}" ] || return 0;;
        1) errcho false; [ "true" != "\${4:-false}" ] || return 1;;
        *) errcho "Bad number"; return \$err ;;
    esac
}

alias unixtime='date +%s'
alias utc='date -u +"%Y-%m-%dT%H:%M:%SZ"'
alias now='date "+%A, %B %d, %Y %I:%M:%S %p %Z"'

alias ll='ls -alF'

# Additional alias definitions.
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
EOF

cat << EOF | tee -a /etc/skel/.profile /root/.profile > /dev/null

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

# Enable bash completion for root
cat >> /root/.bashrc << EOF

if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
   . /etc/bash_completion
fi
EOF

LEVEL='√' $LOGGER "Done! Bashrc and profile setup complete."

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

LEVEL='√' $LOGGER "Done! User '$USERNAME' created successfully."

# Set default password for root user to 'docker'
# Only for development purposes; password can be changed at runtime
# DO NOT use in production environments
# Avoid using 'chpasswd' with here-string (e.g. chpasswd <<<"root:docker") as it may not be supported in some shells
if [ "$DEFAULT_ROOT_PASS" = "true" ]; then
    # Extract ID from /etc/os-release to use as default root password (e.g., 'ubuntu', 'debian', etc.)
    prop=ID ID="$({ while IFS= read -r line; do printf '%s\n' "$line"; done < /etc/os-release; } | grep "^$prop=" | cut -d'=' -f2 | tr -d '"')"
    $LOGGER "Setting default root password to '$ID' (for development purposes only)"
    echo "root:${ID:-docker}" | chpasswd
fi
