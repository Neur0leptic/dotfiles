#!/bin/sh
# librewolf-launch-webapp
# Usage: librewolf-launch-webapp "https://url.com" "app-name"

APP_URL="$1"
APP_NAME="$2"
shift 2
EXTRA_ARGS="$@"

# Profile directory for this webapp
PROFILE_DIR="$HOME/.config/librewolf-webapps/${APP_NAME}"

# Create profile directory if it doesn't exist
mkdir -p "$PROFILE_DIR"
mkdir -p "$PROFILE_DIR/chrome"

# Create userChrome.css for auto-hide navbar/tabs on hover
cat > "$PROFILE_DIR/chrome/userChrome.css" << 'INNEREOF'
/* Auto-hide navigation bar and tabs - show on hover */

/* Remove all top padding/margin */
#navigator-toolbox {
    padding-top: 0 !important;
    margin-top: 0 !important;
}

#titlebar {
    padding-top: 0 !important;
    margin-top: 0 !important;
}

#titlebar-spacer {
    display: none !important;
}

/* Hide nav-bar until mouse hovers */
#nav-bar:not([customizing="true"]):not([inFullscreen]) {
    margin-top: -40px !important;
    transition: margin-top 0.3s ease !important;
}

#nav-bar:hover,
#navigator-toolbox:hover > #nav-bar,
#navigator-toolbox:focus-within > #nav-bar {
    margin-top: 0px !important;
    transition: margin-top 0.3s ease !important;
}

/* Hide tabs toolbar until mouse hovers */
#TabsToolbar:not([customizing="true"]):not([inFullscreen]) {
    margin-top: -50px !important;
    transition: margin-top 0.3s ease !important;
}

#TabsToolbar:hover,
#navigator-toolbox:hover > #TabsToolbar,
#navigator-toolbox:focus-within > #TabsToolbar {
    margin-top: 0px !important;
    transition: margin-top 0.3s ease !important;
}
INNEREOF

# Create user.js to enable userChrome.css
cat > "$PROFILE_DIR/user.js" << 'INNEREOF'
// Enable userChrome.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Disable fullscreen warning
user_pref("full-screen-api.warning.timeout", 0);
INNEREOF

# Launch LibreWolf with webapp mode
exec librewolf \
        --name "WebApp-${APP_NAME}" \
        --class "WebApp-${APP_NAME}" \
        --new-instance \
        --profile "$PROFILE_DIR" \
        "$APP_URL" \
        $EXTRA_ARGS \
        > /dev/null 2>&1 &
