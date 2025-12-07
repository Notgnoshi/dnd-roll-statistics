#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o noclobber

REPO=$(git rev-parse --show-toplevel)

RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
RESET="\033[0m"

VERBOSE="false"

debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}DEBUG:${RESET} $*" >&2
    fi
}

info() {
    echo -e "${GREEN}INFO:${RESET} $*" >&2
}

error() {
    echo -e "${RED}ERROR:${RESET} $*" >&2
}

usage() {
    echo "Usage: $0 [--help]"
    echo
    echo "  --help, -h      Show this help and exit"
    echo "  --verbose, -v   Enable verbose output"
    echo "  --dry-run, -n   Do not actually add the session; just calculate statistics"
}

main() {
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --help | -h)
            usage
            exit 0
            ;;
        --dry-run | -n)
            dry_run="true"
            ;;
        --verbose | -v)
            VERBOSE="true"
            ;;
        -*)
            error "Unexpected option: '$1'"
            exit 1
            ;;
        *)
            error "Unexpected positional argument: '$1'"
            exit 1
            ;;
        esac
        shift
    done
}

main "$@"
