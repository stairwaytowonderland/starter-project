#!/usr/bin/env bash

touch "$LOGGER" \
    && chmod +x "$LOGGER" \
    && cat > "$LOGGER" << EOF
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

touch "$PASSGEN" \
    && chmod +x "$PASSGEN" \
    && cat > "$PASSGEN" << EOF
#!/bin/sh

# Generate a random $DEFAULT_PASS_LENGTH-character alphanumeric password (unless otherwise specified)

# Usage: $PASSGEN [simple|requirements] [length] [charset|min_char_per_fam]
#
# Arguments:
#   mode: 'simple' for simple password generation (default)
#         'requirements' for password generation with character family requirements
#   length: Length of password to generate (default: $DEFAULT_PASS_LENGTH)
#   charset: Characters to use for password generation (simple mode only; default: $DEFAULT_PASS_CHARSET)
#   min_char_per_fam: Minimum characters per family (requirements mode only; default: 2)
#
# Output:
#   Randomly generated password

simple_pass() {
    # Does not guarantee character family requirements

    full_charset='[:graph:]'
    alpha_charset='[:alnum:]'
    custom_charset='0-9a-zA-Z!%^&.@$*_:.,?-'
    default_charset="${DEFAULT_PASS_CHARSET:-\$full_charset}"
    LC_ALL=C tr -dc "\${2:-\$default_charset}" < /dev/urandom | head -c"\${1:-$DEFAULT_PASS_LENGTH}"
}

requirements_pass() {
    # Guarantees at least 2 characters from each character family: digits, lowercase, uppercase, special

    max_string_len=\${1:-$DEFAULT_PASS_LENGTH}
    min_char_per_fam=\${2:-2}

    tr_num='0-9'
    tr_lower='a-z'
    tr_upper='A-Z'
    tr_special='!%^&.@\$*_:.,?-'
    tr_special_addtl='~#|<>[]{}()/+=;'

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
    ) | fold -w1 | shuf | tr -d '\n'
}

if [ "\$#" -eq 0 ] ; then
    simple_pass
else
    case "\$1" in
        simple)
            shift
            simple_pass "\$@"
            ;;
        requirements)
            shift
            requirements_pass "\$@"
            ;;
        *)
            echo "Invalid mode: \$1" >&2
            echo "Usage: $PASSGEN [simple|requirements] [length] [charset|min_char_per_fam]" >&2
            exit 1
            ;;
    esac
fi
EOF

touch "$FIXPATH" \
    && chmod +x "$FIXPATH" \
    && cat > "$FIXPATH" << EOF
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

touch "/docker-entrypoint.sh" \
    && chmod +x /docker-entrypoint.sh \
    && cat > "/docker-entrypoint.sh" << EOF
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
