#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
set -o noclobber

RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
RESET="\033[0m"

REPO=$(git rev-parse --show-toplevel)

debug() {
    echo -e "${BLUE}DEBUG:${RESET} $*" >&2
}

info() {
    echo -e "${GREEN}INFO:${RESET} $*" >&2
}

error() {
    echo -e "${RED}ERROR:${RESET} $*" >&2
}

usage() {
    echo "Usage: $0 [--help] <CSV...>"
    echo
    echo "  CSV             The CSV file(s) to generate statistics for. May be repeated"
    echo
    echo "  --help, -h          Show this help and exit"
    echo "  --interactive, -i   Use an interactive window to display the generated plots"
}

generate_plots() {
    local -r interactive="$1"
    local -r csv="$2"

    if [[ ! -f "$csv" ]]; then
        error "CSV: '$csv' does not exist"
        exit 1
    fi
    debug "Generating plots for '$csv' ..."

    local csvname
    csvname="$(basename "$csv" .csv)"

    # NOTE: Assumes that the CSV uses 'roll' as the column name
    local args=()
    if [[ "$interactive" = "false" ]]; then
        args=(--output "$REPO/figures/$csvname-time-series.png")
    fi
    csvplot --xlabel time --ylabel roll --ymin 1 --ymax 21 -y roll "$csv" "${args[@]}"

    if [[ "$interactive" = "false" ]]; then
        args=(--output "$REPO/figures/$csvname-histogram.png")
    fi
    csvstats --discrete --min 1 --max 20 --bins 20 --histogram --column roll "$csv" "${args[@]}"
}

main() {
    local csvs=()
    local interactive="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --help | -h)
            usage
            exit 0
            ;;
        --interactive | -i)
            interactive="true"
            ;;
        -*)
            error "Unexpected option: '$1'"
            exit 1
            ;;
        *)
            csvs+=("$1")
            ;;
        esac
        shift
    done

    for csv in "${csvs[@]}"; do
        generate_plots "$interactive" "$csv"
    done
}

main "$@"
