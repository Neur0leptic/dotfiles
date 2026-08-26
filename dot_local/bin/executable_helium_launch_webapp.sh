#!/bin/sh

APP_URL="$1"
APP_NAME="$2"
shift 2
EXTRA_ARGS="$@"

# Profile directory for this webapp
PROFILE_DIR="$HOME/.config/helium-webapps/${APP_NAME}"

# Create profile directory if it doesn't exist
mkdir -p "$PROFILE_DIR"

# Launch Helium with webapp mode
exec helium-browser \
        --user-data-dir="$PROFILE_DIR" \
        --class="WebApp-${APP_NAME}" \
        --app="$APP_URL" \
        $EXTRA_ARGS \
        > /dev/null 2>&1 &
