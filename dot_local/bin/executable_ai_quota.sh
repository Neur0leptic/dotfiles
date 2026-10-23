#!/bin/sh
# Claude and Codex (ChatGPT) subscription quotas, fetched fresh on every run; nothing is
# cached or kept running. Without arguments it draws them in the terminal, --wait also
# waits for Enter (for the Waybar click window), and --json prints the data for
# waybar_ai_quota.sh. The logins come from Claude Code and OpenCode. The X220 has neither,
# so on Gentoo the data comes from the Omen over SSH, as claude_launcher.sh does.

usage() {
	printf 'Usage: ai_quota.sh [--json | --wait]\n' >&2
	exit 2
}

case "${1:-}" in
	'' | --json | --wait) ;;
	*) usage ;;
esac
[ "$#" -le 1 ] || usage
set -f
nl='
'

# Prints a provider entry that carries only an error message.
failure() {
	jq -cn --arg name "$1" --arg short "$2" --arg error "$3" --arg plan "${4:-}" \
		'{name: $name, short: $short, plan: $plan, error: $error}'
}

# Prints a provider entry for a login whose subscription has ended; Waybar leaves it out.
ended() {
	jq -cn --arg name "$1" --arg short "$2" \
		'{name: $name, short: $short, plan: "", ended: true, error: "No active subscription."}'
}

# Succeeds when a login expiry in milliseconds is known and has passed.
expired() {
	[ "$1" -gt 0 ] 2>/dev/null && [ "$1" -le "$(($(date +%s) * 1000))" ]
}

# Prints the response body, or an error message and fails. The token reaches curl on
# stdin, never on its command line.
request() {
	case "$2" in '' | *[!A-Za-z0-9._~+/=-]*) printf 'The saved login is unreadable.\n'; return 1 ;; esac
	response=$(printf 'header = "Authorization: Bearer %s"\nheader = "%s"\n' "$2" "$3" |
		curl -q --config - --proto '=https' --silent --connect-timeout 5 --max-time 15 \
			-H 'Accept: application/json' -w "\\n%{http_code}" "$1" 2>/dev/null) || {
		printf 'No connection to the service.\n'
		return 1
	}
	status=${response##*"$nl"}
	case "$status" in
		200) printf '%s\n' "${response%"$nl"*}"; return 0 ;;
		401 | 403) printf 'Login expired. %s\n' "$4" ;;
		429) printf 'Too many requests. Try again later.\n' ;;
		*) printf 'The service answered with HTTP %s.\n' "$status" ;;
	esac
	return 1
}

claude_quota() {
	file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
	[ -r "$file" ] || return 0 # No Claude Code login here: leave Claude out.
	set -- $(jq -r '.claudeAiOauth | "\(.accessToken // "") \(.expiresAt // 0) \(.subscriptionType // "")"' \
		"$file" 2>/dev/null)
	[ "$#" -ge 2 ] || { failure Claude C 'The Claude Code login is unreadable.'; return; }
	plan=${3:-}
	expired "$2" && { failure Claude C 'Login expired. Start Claude Code once.' "$plan"; return; }
	body=$(request https://api.anthropic.com/api/oauth/profile "$1" 'anthropic-beta: oauth-2025-04-20' \
		'Start Claude Code once.') || { failure Claude C "$body" "$plan"; return; }
	# The plan saved with the login is not updated when Claude Code refreshes it, so the
	# profile tells whether the subscription is still active.
	case $(printf '%s\n' "$body" | jq -r 'select(.account | type == "object")
		| (.account.has_claude_pro // false) or (.account.has_claude_max // false)
		  or .organization.subscription_status == "active"' 2>/dev/null) in
		true) ;;
		false) ended Claude C; return ;;
		*) failure Claude C 'Unexpected answer from Anthropic.' "$plan"; return ;;
	esac
	body=$(request https://api.anthropic.com/api/oauth/usage "$1" 'anthropic-beta: oauth-2025-04-20' \
		'Start Claude Code once.') || { failure Claude C "$body" "$plan"; return; }
	printf '%s\n' "$body" | jq -c --arg plan "$plan" '
		def epoch: try (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) catch null;
		def window($label): {label: $label,
			used: (.utilization | if type == "number" then . else null end),
			resets_at: (.resets_at | if type == "string" then epoch else null end)};
		{name: "Claude", short: "C", plan: $plan,
		 windows: [((.five_hour // {}) | window("5-hour")), ((.seven_day // {}) | window("Weekly"))]}
	' 2>/dev/null || failure Claude C 'Unexpected answer from Anthropic.' "$plan"
}

codex_quota() {
	db="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"
	[ -r "$db" ] && command -v sqlite3 >/dev/null 2>&1 || return 0
	# Read-only: OpenCode keeps the refreshed ChatGPT login in its database.
	login=$(sqlite3 -readonly -cmd '.timeout 2000' "$db" "select value from credential
		where integration_id = 'openai' order by time_updated desc limit 1;" 2>/dev/null) || login=
	[ -n "$login" ] || return 0 # No ChatGPT login in OpenCode: leave Codex out.
	set -- $(printf '%s\n' "$login" |
		jq -r '"\(.access // "") \(.expires // 0) \(.metadata.accountID // "")"' 2>/dev/null)
	case "${3:-}" in
		'' | *[!A-Za-z0-9_-]*) failure Codex G 'The OpenCode login is unreadable.'; return ;;
	esac
	expired "$2" && { failure Codex G 'Login expired. Use a GPT model in OpenCode once.'; return; }
	body=$(request https://chatgpt.com/backend-api/wham/usage "$1" "ChatGPT-Account-Id: $3" \
		'Use a GPT model in OpenCode once.') || { failure Codex G "$body"; return; }
	[ "$(printf '%s\n' "$body" | jq -r '.plan_type?' 2>/dev/null)" = free ] && { ended Codex G; return; }
	# A window that has not started yet reports its full length as the time to reset.
	printf '%s\n' "$body" | jq -c '
		def window($seconds; $label):
			[.rate_limit.primary_window, .rate_limit.secondary_window]
			| map(objects | select(.limit_window_seconds == $seconds)) | .[0] as $w
			| {label: $label,
			   used: ($w.used_percent | if type == "number" then . else null end),
			   resets_at: (if $w == null or ($w.used_percent == 0 and $w.reset_after_seconds == $seconds)
			               then null else $w.reset_at end)};
		{name: "Codex", short: "G", plan: (.plan_type // ""),
		 windows: [window(18000; "5-hour"), window(604800; "Weekly")]}
	' 2>/dev/null || failure Codex G 'Unexpected answer from OpenAI.'
}

data() {
	if [ -r /etc/os-release ] && . /etc/os-release && [ "${ID:-}" = gentoo ]; then
		remote=$("$HOME/.local/bin/ssh_connection.sh" .local/bin/ai_quota.sh --json </dev/null 2>/dev/null)
		if printf '%s\n' "$remote" | jq -e 'type == "object"' >/dev/null 2>&1; then
			printf '%s\n' "$remote"
		else
			jq -cn '{fetched_at: (now | floor), error: "The Omen is not reachable."}'
		fi
		return
	fi
	{ claude_quota; codex_quota; } | jq -cs '{fetched_at: (now | floor), providers: .}'
}

if [ "${1:-}" = --json ]; then
	data
	exit
fi

colour=false
[ -t 1 ] && [ -z "${NO_COLOR:-}" ] && colour=true
[ -t 1 ] && printf 'Fetching quotas...'
quota=$(data)
[ -t 1 ] && printf '\r\033[K'

# Colours are the terminal's own palette entries, so the view follows the Neurowave theme.
printf '%s\n' "$quota" | jq -r --argjson colour "$colour" '
	def paint($code; $text): if $colour and $code != "" then "\u001b[\($code)m\($text)\u001b[0m" else $text end;
	def spaces($n): " " * ([$n, 0] | max);
	def width: 50;
	# A line is a list of [colour, text] parts; a row pads it by its visible length.
	def visible($parts): $parts | map(.[1]) | add // "" | length;
	def line($parts): $parts | map(paint(.[0]; .[1])) | add // "";
	def row($left; $right): line($left + [["", spaces(width - visible($left + $right))]] + $right);
	def level($left): if $left <= 10 then "31" elif $left <= 25 then "33" else "32" end;
	def bar($left; $cells): ($left * $cells / 100 * 8 | round) as $eighths
		| ("█" * ($eighths / 8 | floor)) + (["", "▏", "▎", "▍", "▌", "▋", "▊", "▉"][$eighths % 8])
		| [., "░" * ($cells - length)];
	def duration($s):
		if $s >= 86400 then "\($s / 86400 | floor)d \($s % 86400 / 3600 | floor)h"
		elif $s >= 3600 then "\($s / 3600 | floor)h \($s % 3600 / 60 | floor)m"
		else "\([$s / 60 | ceil, 1] | max)m" end;
	def resets:
		if .resets_at == null then (if .used > 0 then "reset time not reported" else "not started yet" end)
		else ((.resets_at - now) | floor | [., 0] | max) as $in
			| "resets in \(duration($in)), "
			  + (.resets_at | strflocaltime(if $in < 86400 then "%H:%M" else "%a %d %b %H:%M" end))
		end;
	def title: .label + spaces(8 - (.label | length));
	def window:
		if .used == null then [line([["", title], ["2", "not reported"]])]
		else (100 - .used | [., 0] | max | [., 100] | min) as $left | bar($left; 30) as $bar
			| [row([["", title], [level($left), $bar[0]], ["2;37", $bar[1]]];
			       [["1;" + level($left), "\($left | round)%"], ["", " left"]]),
			   line([["", spaces(8)], ["2", resets]])]
		end;
	def plan: .plan // "" | ascii_downcase | (.[:1] | ascii_upcase) + .[1:];
	def provider: [row([["1;36", .name]]; [["35", plan]])]
		+ (if .error then [line([["33", .error]])] else [.windows[] | window[]] end);
	[row([["1;35", "AI QUOTA"]]; [["2", (.fetched_at | strflocaltime("%H:%M"))]]),
	 line([])]
	+ (if .error then [line([["33", .error]])]
	   elif (.providers | length) == 0 then [line([["33", "No Claude Code or OpenCode login here."]])]
	   else [.providers | to_entries[] | (if .key > 0 then [line([])] else [] end) + (.value | provider) | .[]]
	   end)
	| .[]
'

if [ "${1:-}" = --wait ]; then
	printf '\nPress Enter to close...'
	read -r _
fi
