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
    echo "Add roll statistics from a new session:"
    echo "  0. Search for session files not yet added"
    echo "  1. Generate campaign aggregates (not checked-in)"
    echo "  2. Generate global aggregates (not checked-in)"
    echo "  3. Calculate session statistics and plots; append"
    echo "  4. Calculate campaign statistics and plots; overwrite"
    echo "  5. Calculate global statistics and plots; overwrite"
    echo "  6. Regenerate README.md from statistics"
    echo
    echo "  --help, -h      Show this help and exit"
    echo "  --verbose, -v   Enable verbose output"
    echo "  --force, -f     Force regenerating all sessions"
    echo "  --dry-run, -n   Do not actually add the session; just calculate statistics and open plots in GUI viewers"
}

## Search for session files not yet added to the campaign statistics.csv files
#
# Outputs the path to the session.csv file, one per line, on stdout.
new_sessions() {
    local -r force="$1"

    for campaign in "$REPO/data/"*/; do
        local campaign_name
        campaign_name="$(basename "$campaign")"
        debug "Searching for new sessions in campaign: $campaign_name"
        local campaign_stats="${campaign}statistics.csv"
        for session in "${campaign}sessions/"*.csv; do
            # Use relative paths from the repo root
            session="$(realpath -s --relative-to="$REPO" "$session")"
            local session_name
            session_name="$(basename "$session")"
            # If the campaign statistics.csv does not exist, then all discovered sessions are new
            if [[ ! -f "$campaign_stats" ]]; then
                info "Found new session '$session_name' in new campaign '$campaign_name'"
                echo "$session"
                continue
            fi

            # If we don't find the session.csv basename in the campaign statistics.csv, then it's a
            # new session, and we output its path
            if [[ "$force" == "true" ]] || ! grep -q "$(basename "$session")" "$campaign_stats"; then
                info "Found new session '$session_name' in campaign '$campaign_name'"
                echo "$session"
            fi
        done
    done
    true
}

## Calculate and add statistics for the given new session
#
# 1a. Calculate statistics for the session and append to <campaign>/statistics.csv
# 1b. Generate histogram of rolls to figures<campaign>/sessions/<session>-histogram.png
# 2. Generate time-series plot of rolls over time to figures/<campaign>/sessions/<session>-time-series.png
add_session_statistics() {
    local -r dry_run="$1"
    local -r campaign="$2"
    local -r session="$3"

    local session_name
    session_name="$(basename "$session")"
    session_name="${session_name%.csv}"
    local campaign_name
    campaign_name="$(basename "$campaign")"

    info "Calculating statistics for session '$session_name' in campaign '$campaign_name'"

    # 1. Calculate statistics
    local args=()
    if [[ "$dry_run" == "false" ]]; then
        mkdir -p "$REPO/figures/$campaign_name/sessions/"
        args+=(--output "$REPO/figures/$campaign_name/sessions/$session_name-histogram.png")
    fi
    csvstats \
        --discrete \
        --min 1 --max 20 --bins 20 \
        --histogram \
        --column roll \
        "${args[@]}" \
        "$session" >"/tmp/session-stats.csv"
    info "Session statistics for '$session_name':"
    cat "/tmp/session-stats.csv"

    # 2. Generate time-series plot
    args=()
    if [[ "$dry_run" == "false" ]]; then
        args+=(--output "$REPO/figures/$campaign_name/sessions/$session_name-time-series.png")
    fi
    csvplot --xlabel time --ylabel roll --ymin 1 --ymax 21 -y roll "${args[@]}" "$session"

    # 1a. Append session statistics to <campaign>/statistics.csv
    if [[ "$dry_run" == "false" ]]; then
        touch "$campaign/statistics.csv"
        csvcat "$campaign/statistics.csv" "/tmp/session-stats.csv" >"/tmp/statistics.csv"
        mv "/tmp/statistics.csv" "$campaign/statistics.csv"
    fi
}

## Update campaign aggregates in <campaign>/aggregate.csv and <campaign>aggregate-stats.csv
update_campaign_aggregates() {
    local -r dry_run="$1"
    local -r campaign="$2"
    local campaign_name
    campaign_name="$(basename "$campaign")"

    csvcat "$campaign/sessions"/*.csv >"$campaign/aggregate.csv"

    local args=()
    if [[ "$dry_run" == "false" ]]; then
        args+=(--output "$REPO/figures/$campaign_name/aggregate-histogram.png")
    fi
    csvstats \
        --discrete \
        --min 1 --max 20 --bins 20 \
        --histogram \
        --column roll \
        "${args[@]}" \
        "$campaign/aggregate.csv" >"$campaign/aggregate-stats.csv"
    info "Campaign statistics for '$campaign_name':"
    cat "$campaign/aggregate-stats.csv"
}

## Update global aggregates in data/aggregate.csv and data/aggregate-stats.csv
#
# Assumes each campaign's aggregates have been updated
update_global_aggregates() {
    local -r dry_run="$1"

    csvcat "$REPO/data"/*/aggregate.csv >"$REPO/data/aggregate.csv"
    local args=()
    if [[ "$dry_run" == "false" ]]; then
        args+=(--output "$REPO/figures/aggregate-histogram.png")
    fi
    csvstats \
        --discrete \
        --min 1 --max 20 --bins 20 \
        --histogram \
        --column roll \
        "${args[@]}" \
        "$REPO/data/aggregate.csv" >"$REPO/data/aggregate-stats.csv"
    info "Global statistics:"
    cat "$REPO/data/aggregate-stats.csv"
}

main() {
    local dry_run="false"
    local force="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --help | -h)
            usage
            exit 0
            ;;
        --verbose | -v)
            VERBOSE="true"
            ;;
        --dry-run | -n)
            dry_run="true"
            ;;
        --force | -f)
            force="true"
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

    # Update data
    for new_session in $(new_sessions "$force"); do
        local campaign
        campaign="$(dirname "$new_session")/../"
        campaign="$(readlink -f "$campaign")"

        add_session_statistics "$dry_run" "$campaign" "$new_session"
        update_campaign_aggregates "$dry_run" "$campaign"
        update_global_aggregates "$dry_run"
    done

    # Regenerate README from updated data
    local readme_args=()
    if [[ "$dry_run" == "true" ]]; then
        readme_args+=("--dry-run")
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        readme_args+=("--verbose")
    fi
    "$REPO/scripts/generate-readme.sh" "${readme_args[@]}"
}

main "$@"
