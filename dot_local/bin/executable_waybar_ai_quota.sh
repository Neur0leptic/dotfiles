#!/bin/sh
# Waybar module: the Claude and Codex quota left, fetched once whenever Waybar starts;
# nothing polls in the background. Each provider shows its 5-hour window, or 0% once the
# weekly window is used up, and the tooltip lists both. It stays hidden without any login
# on this machine, while the Omen is off (X220) and for a provider whose subscription has
# ended; the terminal view still says why.

quota=$("$HOME/.local/bin/ai_quota.sh" --json 2>/dev/null)
printf '%s\n' "$quota" | jq -ce '
	.providers |= (. // [] | map(select(.ended | not))) |
	def left: 100 - .used | [., 0] | max | [., 100] | min | round;
	def shown: if any(.windows[]; .used != null and left == 0) then 0
		else first(.windows[] | select(.label == "5-hour" and .used != null) | left) // null end;
	def when: if .resets_at == null then "not started yet"
		else "resets " + (.resets_at | strflocaltime(if . - now < 86400 then "%H:%M" else "%a %H:%M" end)) end;
	def plan: .plan // "" | ascii_downcase | (.[:1] | ascii_upcase) + .[1:];
	def details: .name + (plan | if . == "" then "" else " · " + . end) + "\n" + (if .error then "  " + .error
		else [.windows[] | "  \(.label)  " + (if .used == null then "not reported"
			else "\(left)% left · " + when end)] | join("\n") end);
	if .error or (.providers | length) == 0 then {text: ""}
	else ([.providers[] | select(.error | not) | shown | numbers] | min // 100) as $min
		| {text: ([.providers[] | .short + " " + (if .error then "?" else (shown | if . == null then "—" else "\(.)%" end) end)] | join("  ")),
		   tooltip: ([.providers[] | details] | join("\n\n") | @html),
		   percentage: $min,
		   class: (if any(.providers[]; .error) then "error"
		           elif $min <= 10 then "critical" elif $min <= 25 then "warning" else "normal" end)}
	end
' 2>/dev/null || printf '%s\n' '{"text":"AI ?","class":"error","tooltip":"The quota could not be read."}'
