#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset
#set -o noclobber

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
    echo "Generate the README.md from the current computed statistics."
    echo
    echo "Inputs:"
    echo "  data/<campaign>/statistics.csv"
    echo "  data/<campaign>/aggregate-stats.csv"
    echo "  data/aggregate-stats.csv"
    echo
    echo "  figures/<campaign>/sessions/<session>-histogram.png"
    echo "  figures/<campaign>/aggregate-histogram.png"
    echo "  figures/aggregate-histogram.png"
    echo
    echo "  --help, -h      Show this help and exit"
    echo "  --verbose, -v   Enable verbose output"
    echo "  --dry-run, -n   Do not actually add the session; just calculate statistics"
}

all_campaigns() {
    for dir in "$REPO/data"/*/; do
        echo "$dir"
    done
}

campaign_name() {
    local -r campaign_dir="$1"
    basename "$campaign_dir"
}

all_sessions_in() {
    local -r campaign_dir="$1"
    for session in "$campaign_dir/sessions"/*.csv; do
        echo "$session"
    done
}

session_name() {
    local -r session_file="$1"
    basename "$session_file" .csv
}

render_csv_to_table() {
    # Thanks Claude.
    awk -F, 'NR==1 {
        printf "|"
        for(i=1; i<=NF; i++) printf " %s |", $i
        printf "\n|"
        for(i=1; i<=NF; i++) printf " --- |"
        printf "\n"
        next
    }
    {
        printf "|"
        for(i=1; i<=NF; i++) {
            if($i ~ /^-?[0-9]+\.?[0-9]*$/ && $i ~ /\./) {
                printf " %.2f |", $i
            } else {
                printf " %s |", $i
            }
        }
        printf "\n"
    }'
}

dnd_for_each_row() {
    if [[ "$1" == "filename" ]]; then
        # This is the header
        echo -n "session,"
    else
        # Generate a markdown link to the session histogram
        local campaign
        campaign="$(dirname "$1")/.."
        campaign="$(readlink -f "$campaign")"
        campaign="$(basename "$campaign")"

        local session
        session="$(basename "$1" .csv)"

        if [[ "$session" == "aggregate" ]]; then
            echo -n "aggregate,"
        else
            echo -n "[$session](figures/$campaign/sessions/$session-histogram.png),"
        fi

    fi
    shift
    printf -v joined '%s,' "${@}"
    echo "${joined%,}"
}

## Select and reformat just the columns we care about
transform_stats_for_human_readable() {
    local -r stats="$1"
    local -r include_name="$2"

    if [[ "$include_name" == "true" ]]; then
        export -f dnd_for_each_row
        csvtool call dnd_for_each_row "$stats" |
            csvtool namedcol session,count,mean,stddev,Q1,median,Q3 '-'
    else
        csvtool namedcol count,mean,stddev,Q1,median,Q3 "$stats"
    fi

}

render_stats_to_table() {
    local -r stats="$1"
    local -r include_name="$2"
    if [[ ! -f "$stats" ]]; then
        error "Statistics file '$stats' not found"
        return 1
    fi

    transform_stats_for_human_readable "$stats" "$include_name" | render_csv_to_table
}

generate_table_of_contents() {
    echo "Table of contents:"
    echo "* [Global Statistics](#global-statistics)"
    echo "* Campaign Statistics"
    for campaign in $(all_campaigns); do
        campaign="$(campaign_name "$campaign")"
        echo "  * [$campaign](#$campaign-statistics)"
    done
    echo "* [FAQ](#faq)"
}

generate_global_statistics() {
    local -r stats="$REPO/data/aggregate-stats.csv"
    echo "# Global Statistics"
    echo
    echo "![Global Aggregate Histogram](figures/aggregate-histogram.png)"
    echo
    render_stats_to_table "$stats" "false"
}

generate_campaign_statistics() {
    local -r campaign="$1"
    local campaign_name
    campaign_name="$(campaign_name "$campaign")"

    echo
    echo "## $campaign_name statistics"
    echo
    echo "![$campaign_name Aggregate Histogram](figures/$campaign_name/aggregate-histogram.png)"
    echo

    csvcat "$campaign/aggregate-stats.csv" "$campaign/statistics.csv" >"/tmp/$campaign_name-stats.csv"
    render_stats_to_table "/tmp/$campaign_name-stats.csv" "true"
}

## Generates the README.md file contents; printing them to stdout
generate_readme() {
    echo "<!-- NOTE: This document is generated. Do not hand-edit! -->"
    cat "$REPO/doc/TITLE.md"

    echo
    generate_table_of_contents

    echo
    generate_global_statistics

    echo
    echo "# Campaign Statistics"
    for campaign in $(all_campaigns); do
        generate_campaign_statistics "$campaign"
    done

    echo
    cat "$REPO/doc/FAQ.md"
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

    generate_readme >/tmp/README.md.tmp
    if [[ "$dry_run" == "false" ]]; then
        mv /tmp/README.md.tmp "$REPO/README.md"
        info "Updated README.md"
    else
        cat /tmp/README.md.tmp
    fi
}

main "$@"
