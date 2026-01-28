#!/bin/sh

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
  timestamp="\$(date +'%Y-%m-%d %H:%M:%S')"
  template="[%s] [%s] %s\n"

  case "\$LEVEL" in
    debug|info|warning|error) LEVEL=\$(echo \$LEVEL | tr '[:lower:]' '[:upper:]') ;;
    \*)
        LEVEL='*'
        template="[%s] (%s) %s\n"
        ;;
    \!)
        LEVEL='!'
        template="[%s] (%s) Error! %s\n"
        ;;
    *) LEVEL="info" ;;
  esac

  printf "\$template" "\$timestamp" "\$LEVEL" "\$*" >&2
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
#           Use '[:graph:]' for all printable characters (except space)
#           Use '[:alnum:]' for alphanumeric characters plus digits
#           Use a custom set of characters (e.g. '0-9a-zA-Z!@#\$%^&*()')
#   min_char_per_fam: Minimum characters per family (requirements mode only; default: 2)
#
# Output:
#   Randomly generated password

DEFAULT_PASS_LENGTH="\${DEFAULT_PASS_LENGTH:-$DEFAULT_PASS_LENGTH}"
DEFAULT_PASS_CHARSET="\${DEFAULT_PASS_CHARSET:-$DEFAULT_PASS_CHARSET}"

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
    case "\$1" in
        -[0-9] | -[0-9][0-9])
            qty="\${1#-}"
            shift
            ;;
    esac
    if [ "\$qty" -gt 0 ] ; then
        count=0
        while [ \$count -lt "\$qty" ]; do
            printf "%s\n" "\$(parse_args \$@)"
            count=\$(( count + 1 ))
        done
    else
        parse_args "\$@"
    fi
}

passgen "\$@"
EOF
