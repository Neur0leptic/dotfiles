#!/usr/bin/env bash
# Synchronize private dotfiles first so GPG authentication happens at startup.

GREEN='\e[1;92m' BLUE='\e[1;94m' YELLOW='\e[1;93m' NC='\033[0m'

validate_chezmoi_source() {
        local label="${1}"
        local source_dir="${2}"
        local private_allowlist="${3:-}"
        local inventory_file rel secret_dir secret_name plaintext_source
        local -A allowed=(
                [".chezmoiignore"]=1
                [".chezmoiversion"]=1
                [".gitignore"]=1
                ["README.md"]=1
                ["private-source-allowlist.txt"]=1
        )
        local -A forbidden=()

        if [ ! -r "$private_allowlist" ]; then
                echo -e "${YELLOW}${label} chezmoi private-source allowlist is unavailable.${NC}" >&2
                return 1
        fi

        if ! inventory_file="$(mktemp "${TMPDIR:-/tmp}/chezmoi-source-files.XXXXXX")"; then
                echo -e "${YELLOW}Could not create a temporary ${label} chezmoi inventory.${NC}" >&2
                return 1
        fi

        if ! git -C "$source_dir" ls-files --cached --others -z > "$inventory_file"; then
                rm -f "$inventory_file"
                echo -e "${YELLOW}Could not enumerate the ${label} chezmoi source.${NC}" >&2
                return 1
        fi

        if [ "$label" = "Private" ]; then
                if ! command -v gpg >/dev/null 2>&1; then
                        rm -f "$inventory_file"
                        echo -e "${YELLOW}GPG is required to validate the private chezmoi source.${NC}" >&2
                        return 1
                fi

                while IFS= read -r rel || [ -n "$rel" ]; do
                        [ -n "$rel" ] || continue
                        case "$rel" in
                                */encrypted_*.asc)
                                        if [ ! -f "$source_dir/$rel" ] || [ -L "$source_dir/$rel" ]; then
                                                rm -f "$inventory_file"
                                                echo -e "${YELLOW}Required private chezmoi source is missing or not a regular file: ${rel}${NC}" >&2
                                                return 1
                                        fi
                                        if ! gpg --batch --no-options --dearmor < "$source_dir/$rel" >/dev/null 2>&1; then
                                                rm -f "$inventory_file"
                                                echo -e "${YELLOW}Invalid OpenPGP armor in private chezmoi source: ${rel}${NC}" >&2
                                                return 1
                                        fi
                                        allowed["$rel"]=1
                                        ;;
                                *)
                                        rm -f "$inventory_file"
                                        echo -e "${YELLOW}Invalid private chezmoi allowlist entry: ${rel}${NC}" >&2
                                        return 1
                                        ;;
                        esac
                done < "$private_allowlist"

                while IFS= read -r -d '' rel; do
                        if [ -z "${allowed[$rel]+x}" ]; then
                                rm -f "$inventory_file"
                                echo -e "${YELLOW}Unexpected file in private chezmoi source: ${rel}. Refusing automatic staging.${NC}" >&2
                                return 1
                        fi
                done < "$inventory_file"

                rm -f "$inventory_file"
                return 0
        fi

        while IFS= read -r rel || [ -n "$rel" ]; do
                [ -n "$rel" ] || continue
                case "$rel" in
                        */encrypted_*.asc) ;;
                        *)
                                rm -f "$inventory_file"
                                echo -e "${YELLOW}Invalid public private-source allowlist entry: ${rel}${NC}" >&2
                                return 1
                                ;;
                esac
                forbidden["$rel"]=1
                secret_dir="${rel%/*}"
                secret_name="${rel##*/}"
                secret_name="${secret_name#encrypted_}"
                plaintext_source="${secret_dir}/${secret_name%.asc}"
                forbidden["$plaintext_source"]=1
        done < "$private_allowlist"

        while IFS= read -r -d '' rel; do
                if [[ "$rel" == *.asc ]] || [ -n "${forbidden[$rel]+x}" ]; then
                        rm -f "$inventory_file"
                        echo -e "${YELLOW}Private payload found in public chezmoi source: ${rel}. Refusing automatic staging.${NC}" >&2
                        return 1
                fi
                case "$rel" in
                        dot_librewolf/*|private_dot_librewolf/*)
                                if [[ "$rel" != dot_librewolf/librewolf.overrides.cfg &&
                                      "$rel" != private_dot_librewolf/librewolf.overrides.cfg ]]; then
                                        rm -f "$inventory_file"
                                        echo -e "${YELLOW}Browser runtime data found in public chezmoi source: ${rel}. Refusing automatic staging.${NC}" >&2
                                        return 1
                                fi
                                ;;
                esac
        done < "$inventory_file"

        rm -f "$inventory_file"
}

decrypt_private_chezmoi_source() {
	local source_dir="${1}"
	local private_allowlist="${2}"
	local rel decrypted=0

	while IFS= read -r rel || [ -n "$rel" ]; do
		[ -n "$rel" ] || continue
		if ! gpg --quiet --decrypt -- "$source_dir/$rel" >/dev/null; then
			echo -e "${YELLOW}Could not decrypt private chezmoi source: ${rel}.${NC}" >&2
			return 1
		fi
		decrypted=1
	done < "$private_allowlist"

	if [ "$decrypted" -ne 1 ]; then
		echo -e "${YELLOW}The private chezmoi allowlist is empty.${NC}" >&2
		return 1
	fi
}

get_chezmoi_marker() {
        local source_dir="${1}"
        shift
        local current_head context_hash

        if ! current_head="$(git -C "$source_dir" rev-parse HEAD)"; then
                return 1
        fi

        if ! context_hash="$("$@" data | git -C "$source_dir" hash-object --stdin)"; then
                return 1
        fi

        printf '%s %s\n' "$current_head" "$context_hash"
}

record_chezmoi_marker() {
        local marker_file="${1}"
        local marker="${2}"
        local marker_dir marker_tmp

        marker_dir="${marker_file%/*}"
        if ! mkdir -p "$marker_dir" || ! chmod 700 "$marker_dir"; then
                return 1
        fi

        if ! marker_tmp="$(mktemp "$marker_dir/.marker.XXXXXX")"; then
                return 1
        fi

        if ! printf '%s\n' "$marker" > "$marker_tmp" ||
                ! chmod 600 "$marker_tmp" ||
                ! mv -f "$marker_tmp" "$marker_file"; then
                rm -f "$marker_tmp"
                return 1
        fi
}

refresh_chezmoi_config() (
        local source_dir="$1" format template="" directory
        shift
        for format in toml yaml json jsonc; do
                if [ -f "$source_dir/.chezmoi.$format.tmpl" ]; then
                        template="$source_dir/.chezmoi.$format.tmpl"
                        break
                fi
        done
        [ -n "$template" ] || return 0
        directory="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-config.XXXXXX")" || return 1
        trap 'rm -f "$directory/preview.$format" "$directory/warnings" "$directory/render-errors" "$directory/current.json" "$directory/preview.json"; rmdir "$directory"' EXIT
        if ! "$@" --no-tty dump --format=json --exclude=scripts,externals \
                >/dev/null 2>"$directory/warnings"; then
                cat "$directory/warnings" >&2
                return 1
        fi
        grep -q 'config file template has changed' "$directory/warnings" || return 0
        if ! "$@" --no-tty execute-template --init --file "$template" \
                >"$directory/preview.$format" 2>"$directory/render-errors"; then
                cat "$directory/render-errors" >&2
                return 0
        fi
        # Refresh the native template marker only when every effective setting is
        # unchanged. Local config additions and new profile choices are never reset.
        if "$@" dump-config --format=json >"$directory/current.json" 2>/dev/null &&
                "$@" --config "$directory/preview.$format" --config-format "$format" \
                        dump-config --format=json >"$directory/preview.json" 2>/dev/null &&
                cmp -s "$directory/current.json" "$directory/preview.json"; then
                "$@" --no-tty init --apply=false --prompt=false --data=true || return 1
        else
                echo -e "${YELLOW}Config template has new settings; retaining the current config and continuing file sync.${NC}" >&2
        fi
)

sync_chezmoi_files() {
        local phase="$1" snapshot="$2"
        shift 2
        python3 - "$phase" "$snapshot" "$@" <<'PY'
import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile

phase, snapshot, *cmd = sys.argv[1:]

def run(*args, input=None):
    return subprocess.check_output([*cmd, *args], input=input)

def digest(contents):
    return hashlib.sha256(contents).hexdigest()

def actual(path):
    try:
        mode = os.lstat(path).st_mode
    except FileNotFoundError:
        return None
    if stat.S_ISLNK(mode):
        return ['symlink', 0, digest(os.fsencode(os.readlink(path)))]
    if stat.S_ISREG(mode):
        with open(path, 'rb') as stream:
            return ['file', stat.S_IMODE(mode), digest(stream.read())]
    if stat.S_ISDIR(mode):
        return ['dir', stat.S_IMODE(mode), '']
    raise ValueError(f'Unsupported destination type: {path}')

def parents(path):
    result = {}
    parent = os.path.dirname(path)
    while parent != os.path.dirname(parent):
        if os.path.islink(parent):
            raise ValueError(f'Symlink destination parent: {parent} (target {path})')
        result[parent] = actual(parent)
        parent = os.path.dirname(parent)
    return result

def merge_contents(ours, base, theirs, path):
    if ours == base:
        return theirs
    if theirs == base or ours == theirs:
        return ours
    # Let Git merge non-overlapping edits; never write conflict markers to configs.
    with tempfile.TemporaryDirectory(prefix='chezmoi-merge-', dir=os.path.dirname(snapshot)) as directory:
        files = []
        for name, contents in (('source', ours), ('base', base), ('disk', theirs)):
            filename = os.path.join(directory, name)
            with open(filename, 'xb') as stream:
                os.chmod(filename, 0o600)
                stream.write(contents)
            files.append(filename)
        result = subprocess.run(['git', 'merge-file', '--stdout', '--diff-algorithm=histogram', *files],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode:
            raise ValueError(f'{path}: overlapping edits need a merge; both versions are preserved')
        return result.stdout

def render(contents, template):
    return run('execute-template', input=contents) if template else contents

def previous_contents(source, baseline, wanted, current, template, encrypted):
    if baseline is None or baseline == wanted:
        return current
    relative = os.path.relpath(source, source_root)
    if relative.startswith('../'):
        raise ValueError(f'Source is outside the repository: {source}')
    refs = ['HEAD']
    saved_ref = os.environ.get('CHEZMOI_SYNC_BASELINE_REF', '')
    if len(saved_ref) in (40, 64) and all(c in '0123456789abcdef' for c in saved_ref):
        refs.insert(0, saved_ref)
    for ref in refs:
        try:
            contents = subprocess.check_output(['git', '-C', source_root, 'show', f'{ref}:{relative}'],
                                               stderr=subprocess.DEVNULL)
            if encrypted:
                contents = run('decrypt', input=contents)
            contents = render(contents, template)
            if digest(contents) == baseline[2]:
                return contents
        except subprocess.CalledProcessError:
            continue
    raise ValueError(f'{source}: previous rendered contents cannot be recovered; both versions are preserved')

def replace_source(source, contents, expected):
    if actual(source) != expected:
        raise ValueError(f'Source changed during sync: {source}')
    fd, temporary = tempfile.mkstemp(prefix='.chezmoi-sync-', dir=os.path.dirname(source))
    try:
        with os.fdopen(fd, 'wb') as stream:
            os.fchmod(stream.fileno(), expected[1])
            stream.write(contents)
        if actual(source) != expected:
            raise ValueError(f'Source changed during sync: {source}')
        os.replace(temporary, source)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

try:
    context = json.loads(run('data'))['chezmoi']
    destination = context['destDir']
    source_root = context['sourceDir']
    entries = json.loads(run('dump', '--format=json', '--exclude=scripts,externals'))
    targets = {}
    for rel, entry in entries.items():
        path = os.path.abspath(os.path.join(destination, rel))
        if os.path.commonpath([destination, path]) != destination or path == destination:
            raise ValueError(f'Invalid destination: {path}')
        kind = entry['type']
        if kind == 'file':
            wanted = [kind, entry['perm'], digest(run('cat', '--', path))]
        elif kind == 'symlink':
            wanted = [kind, 0, digest(os.fsencode(entry['linkname']))]
        elif kind == 'dir':
            wanted = [kind, entry['perm'], '']
        else:
            raise ValueError(f'Unsupported target type {kind}: {path}')
        targets[path] = wanted

    if phase == 'record':
        observed, ancestors, record = {}, {}, []
        conflicts = []
        for path, wanted in targets.items():
            ancestors.update(parents(path))
            disk = actual(path)
            observed[path] = disk
            if disk == wanted:
                continue
            if disk and disk[0] != wanted[0] and 'dir' in (disk[0], wanted[0]):
                conflicts.append(f'{path}: directory type change needs manual reconciliation')
                continue
            raw = run('state', 'get', '--bucket=entryState', '--key=' + path)
            baseline = json.loads(raw) if raw.strip() else None
            if baseline:
                kind = baseline['type']
                baseline = [kind, baseline.get('mode', 0) & 0o7777,
                            baseline.get('contentsSHA256', '')]
            if disk == baseline:
                continue
            source = os.fsdecode(run('source-path', '--', path)).rstrip('\n')
            if disk is None or disk[0] != 'file' or wanted[0] != 'file':
                conflicts.append(f'{path}: deletion or type change needs a decision; both versions are preserved')
                continue
            if disk[1] not in (0o600, 0o644, 0o700, 0o755):
                conflicts.append(f'{path}: disk permissions cannot be represented safely by re-add')
                continue
            source_state = actual(source)
            if not source_state or source_state[0] != 'file' or os.stat(source).st_nlink != 1:
                conflicts.append(f'{path}: source is not an independent regular file')
                continue
            template = source.endswith(('.tmpl', '.tmpl.asc'))
            encrypted = os.path.basename(source).startswith('encrypted_')
            if not template and (baseline is None or wanted == baseline):
                # A first sync adopts an existing ordinary file, rather than rejecting
                # it just because chezmoi has not written a baseline on this machine.
                record.append((path, source, source_state, None, None))
                continue
            if disk[1] != wanted[1]:
                conflicts.append(f'{path}: competing template/source permissions need a decision')
                continue
            try:
                current = run('cat', '--', path)
                with open(path, 'rb') as stream:
                    edited = stream.read()
                base = previous_contents(source, baseline, wanted, current, template, encrypted)
                expected = merge_contents(current, base, edited, path)
                with open(source, 'rb') as stream:
                    original = stream.read()
                raw = run('decrypt', input=original) if encrypted else original
                candidate = merge_contents(raw, base, edited, path) if template else expected
                if render(candidate, template) != expected:
                    raise ValueError(f'{path}: edit changes generated template fields; both versions are preserved')
                if encrypted:
                    candidate = run('encrypt', input=candidate)
                record.append((path, source, source_state, candidate, expected))
            except (ValueError, subprocess.CalledProcessError) as error:
                conflicts.append(str(error))
        if conflicts:
            raise ValueError('\n'.join(conflicts))
        with open(snapshot, 'w') as stream:
            json.dump({'targets': observed, 'parents': ancestors}, stream)
        # Classify every file before making any source mutation.
        for path, source, source_state, candidate, expected in record:
            current_parents = parents(path)
            if actual(path) != observed[path] or current_parents != {p: ancestors[p] for p in current_parents}:
                raise ValueError(f'Destination changed during sync: {path}')
            if actual(source) != source_state:
                raise ValueError(f'Source changed during sync: {source}')
            if candidate is None:
                subprocess.run([*cmd, '--no-tty', '--force', 're-add', '--', path], check=True,
                               stdin=subprocess.DEVNULL)
                if digest(run('cat', '--', path)) != observed[path][2]:
                    raise ValueError(f'Re-add did not preserve disk contents: {path}')
            else:
                with open(source, 'rb') as stream:
                    original = stream.read()
                replace_source(source, candidate, source_state)
                try:
                    if run('cat', '--', path) != expected:
                        raise ValueError(f'Merged template did not preserve edits: {path}')
                except (ValueError, subprocess.CalledProcessError):
                    replace_source(source, original, actual(source))
                    raise
    elif phase == 'apply':
        with open(snapshot) as stream:
            saved = json.load(stream)
        pending, expected_parents = [], dict(saved['parents'])
        for path, wanted in targets.items():
            current_parents = parents(path)
            for parent, value in current_parents.items():
                if value != saved['parents'].get(parent):
                    # A newly managed remote path may have pre-existing directory parents.
                    if parent in saved['parents'] or value is not None and value[0] != 'dir':
                        raise ValueError(f'Destination parent changed during sync: {parent}')
                expected_parents[parent] = value
            disk = actual(path)
            if disk != saved['targets'].get(path):
                raise ValueError(f'Destination changed or new remote target already exists: {path}')
            if disk and disk[0] != wanted[0] and 'dir' in (disk[0], wanted[0]):
                raise ValueError(f'Directory type change needs manual reconciliation: {path}')
            # Even an already equal file must refresh chezmoi's last-written baseline.
            pending.append(path)
        for path in sorted(pending, key=lambda p: (p.count(os.sep), p)):
            for parent, value in parents(path).items():
                if value != expected_parents[parent]:
                    raise ValueError(f'Destination parent changed during sync: {parent}')
            if actual(path) != saved['targets'].get(path):
                raise ValueError(f'Destination changed during sync: {path}')
            if targets[path][0] == 'file' and digest(run('cat', '--', path)) != targets[path][2]:
                raise ValueError(f'Rendered source changed during sync: {path}')
            subprocess.run([*cmd, '--no-tty', '--force', 'apply',
                            '--exclude=scripts,externals', '--recursive=false', '--', path],
                           check=True, stdin=subprocess.DEVNULL)
            if targets[path][0] == 'dir':
                expected_parents[path] = actual(path)
    else:
        raise ValueError('Unknown sync phase')
except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as error:
    print(f'Chezmoi sync stopped: {error}', file=sys.stderr)
    sys.exit(1)
PY
}

sync_chezmoi_repo() (
        local label="${1}"
        local source_dir="${2}"
        local persistent_state="${3:-}"
        local applied_head_file="${4}"
        local private_allowlist="${5:-}"
	local trusted_private_allowlist="${6:-}"
        local source_status target_status git_dir
        local head_before_pull head_after_pull final_marker ahead snapshot baseline_ref="" applied_marker
        local changes_found=0
	local -a chezmoi_cmd=(env CHEZMOI_SKIP_EXTERNALS=1 chezmoi -S "$source_dir" --refresh-externals=never)

        if [ -n "$persistent_state" ]; then
                chezmoi_cmd+=(--persistent-state "$persistent_state")
        fi

        if [ ! -d "$source_dir" ]; then
                echo -e "${YELLOW}${label} chezmoi source is unavailable. Skipping it.${NC}" >&2
                return 1
        fi

        if ! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                echo -e "${YELLOW}${label} chezmoi source is not a Git repository. Skipping it.${NC}" >&2
                return 1
        fi

	if [ -z "$trusted_private_allowlist" ] || ! cmp -s "$trusted_private_allowlist" "$private_allowlist"; then
		echo -e "${YELLOW}${label} chezmoi allowlist does not match the trusted copy. Aborting dotfile sync.${NC}" >&2
		return 1
	fi

        if ! validate_chezmoi_source "$label" "$source_dir" "$private_allowlist"; then
                echo -e "${YELLOW}${label} chezmoi source validation failed. Skipping it.${NC}" >&2
		return 1
	fi

        if [ "$label" = "Private" ] &&
		! decrypt_private_chezmoi_source "$source_dir" "$private_allowlist"; then
		echo -e "${YELLOW}Private chezmoi payload validation failed. Aborting dotfile sync.${NC}" >&2
		return 1
	fi

        if ! git -C "$source_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
                echo -e "${YELLOW}${label} chezmoi Git upstream is not configured. Skipping it.${NC}" >&2
                return 1
        fi

        if [ "$label" = "Public" ] && ! refresh_chezmoi_config "$source_dir" "${chezmoi_cmd[@]}"; then
                return 1
        fi

        if ! git_dir="$(git -C "$source_dir" rev-parse --absolute-git-dir)"; then
                echo -e "${YELLOW}Could not locate the ${label} chezmoi Git directory. Skipping it.${NC}" >&2
                return 1
        fi

        if git -C "$source_dir" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1 ||
                git -C "$source_dir" rev-parse -q --verify REBASE_HEAD >/dev/null 2>&1 ||
                git -C "$source_dir" rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1 ||
                git -C "$source_dir" rev-parse -q --verify REVERT_HEAD >/dev/null 2>&1 ||
                [ -d "$git_dir/rebase-merge" ] ||
                [ -d "$git_dir/rebase-apply" ] ||
                [ -d "$git_dir/sequencer" ] ||
                [ -n "$(git -C "$source_dir" ls-files --unmerged)" ]; then
                echo -e "${YELLOW}A Git operation is in progress in the ${label} chezmoi source. Skipping it.${NC}" >&2
                return 1
        fi

        if ! git -C "$source_dir" diff --cached --quiet; then
                echo -e "${YELLOW}The ${label} chezmoi source has staged changes. Commit or unstage them before automatic sync.${NC}" >&2
                return 1
        fi

        if ! command -v python3 >/dev/null 2>&1; then
                echo "Python 3 is required for safe per-file chezmoi sync." >&2
                return 1
        fi
        snapshot="$(mktemp "${TMPDIR:-/tmp}/chezmoi-sync.XXXXXX")" || return 1
        trap 'rm -f "$snapshot"' EXIT
        if [ -r "$applied_head_file" ] && IFS= read -r applied_marker < "$applied_head_file"; then
                baseline_ref="${applied_marker%% *}"
        fi
        if ! CHEZMOI_SYNC_BASELINE_REF="$baseline_ref" sync_chezmoi_files record "$snapshot" "${chezmoi_cmd[@]}"; then
                if [ "$label" = "Private" ]; then
                        if ! cmp -s "$trusted_private_allowlist" "$private_allowlist" ||
                                ! validate_chezmoi_source "$label" "$source_dir" "$private_allowlist" ||
                                ! decrypt_private_chezmoi_source "$source_dir" "$private_allowlist"; then
                                echo -e "${YELLOW}Partially re-added private chezmoi payloads failed validation.${NC}" >&2
                        fi
                fi
                return 1
        fi

	if [ -z "$trusted_private_allowlist" ] || ! cmp -s "$trusted_private_allowlist" "$private_allowlist"; then
		echo -e "${YELLOW}${label} chezmoi allowlist changed after re-add. Aborting dotfile sync.${NC}" >&2
		return 1
	fi

        if ! validate_chezmoi_source "$label" "$source_dir" "$private_allowlist"; then
                echo -e "${YELLOW}${label} chezmoi source validation failed after re-add. Skipping commit, pull and push.${NC}" >&2
		return 1
	fi

	if [ "$label" = "Private" ] &&
		! decrypt_private_chezmoi_source "$source_dir" "$private_allowlist"; then
		echo -e "${YELLOW}Private chezmoi payload validation failed after re-add. Aborting dotfile sync.${NC}" >&2
		return 1
	fi

        if ! source_status="$(git -C "$source_dir" status --porcelain)"; then
                echo -e "${YELLOW}Could not inspect re-added ${label} chezmoi changes. Skipping it.${NC}" >&2
                return 1
        fi

        if [ -n "$source_status" ]; then
                if ! git -C "$source_dir" add -A -- .; then
                        echo -e "${YELLOW}Could not stage ${label} chezmoi changes. Skipping it.${NC}" >&2
                        return 1
                fi

                if ! git -C "$source_dir" diff --cached --quiet; then
                        if ! git -C "$source_dir" commit -m "Update dotfiles $(date '+%Y-%m-%d %H:%M:%S')"; then
                                echo -e "${YELLOW}Could not commit ${label} chezmoi changes. Skipping it.${NC}" >&2
                                return 1
                        fi
                        changes_found=1
                fi
        fi

        if ! source_status="$(git -C "$source_dir" status --porcelain)" || [ -n "$source_status" ]; then
                echo -e "${YELLOW}${label} chezmoi source is still dirty after the commit. Skipping pull, apply and push.${NC}" >&2
                return 1
        fi

        if ! head_before_pull="$(git -C "$source_dir" rev-parse HEAD)"; then
                echo -e "${YELLOW}Could not read the ${label} chezmoi Git revision. Skipping it.${NC}" >&2
                return 1
        fi

        if ! git -C "$source_dir" pull --rebase; then
                if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
                        if ! git -C "$source_dir" rebase --abort; then
                                echo -e "${YELLOW}${label} chezmoi rebase could not be aborted automatically. Resolve it manually.${NC}" >&2
                                return 1
                        fi
                fi
                echo -e "${YELLOW}${label} chezmoi pull failed or conflicted; skipping apply and push.${NC}" >&2
                return 1
        fi

        if ! head_after_pull="$(git -C "$source_dir" rev-parse HEAD)"; then
                echo -e "${YELLOW}Could not read the updated ${label} chezmoi Git revision. Skipping apply and push.${NC}" >&2
                return 1
        fi

	if [ -z "$trusted_private_allowlist" ] || ! cmp -s "$trusted_private_allowlist" "$private_allowlist"; then
		echo -e "${YELLOW}${label} chezmoi allowlist changed after pull. Aborting dotfile sync.${NC}" >&2
		return 1
	fi

        if ! validate_chezmoi_source "$label" "$source_dir" "$private_allowlist"; then
                echo -e "${YELLOW}${label} chezmoi source validation failed after pull. Skipping apply and push.${NC}" >&2
		return 1
	fi

	if [ "$label" = "Private" ] &&
		! decrypt_private_chezmoi_source "$source_dir" "$private_allowlist"; then
		echo -e "${YELLOW}Private chezmoi payload validation failed after pull. Aborting dotfile sync.${NC}" >&2
		return 1
	fi

        if [ "$head_before_pull" != "$head_after_pull" ]; then
                changes_found=1
                if [ "$label" = "Public" ] && ! refresh_chezmoi_config "$source_dir" "${chezmoi_cmd[@]}"; then
                        return 1
                fi
        fi

        if ! sync_chezmoi_files apply "$snapshot" "${chezmoi_cmd[@]}"; then
                echo -e "${YELLOW}Could not safely apply ${label} chezmoi changes. Skipping push.${NC}" >&2
                return 1
        fi

        if ! target_status="$("${chezmoi_cmd[@]}" --color=false status --exclude=scripts,externals)"; then
                echo -e "${YELLOW}Could not verify the applied ${label} chezmoi state. Skipping push.${NC}" >&2
                return 1
        fi

        if grep -q '^.[ADM]' <<<"$target_status"; then
                echo -e "${YELLOW}${label} chezmoi-managed files did not converge after apply. Skipping marker update and push.${NC}" >&2
                return 1
        fi

        if ! final_marker="$(get_chezmoi_marker "$source_dir" "${chezmoi_cmd[@]}")" ||
                ! record_chezmoi_marker "$applied_head_file" "$final_marker"; then
                echo -e "${YELLOW}Could not record the applied ${label} chezmoi revision/profile marker. Skipping push.${NC}" >&2
                return 1
        fi

        if ! ahead="$(git -C "$source_dir" rev-list --count '@{upstream}..HEAD')"; then
                echo -e "${YELLOW}Could not determine whether ${label} chezmoi has commits to push. Skipping push.${NC}" >&2
                return 1
        fi

        if [ "$ahead" -gt 0 ]; then
                if ! git -C "$source_dir" push; then
                        echo -e "${YELLOW}Could not push ${label} chezmoi changes. They remain committed locally.${NC}" >&2
                        return 1
                fi
                changes_found=1
        fi

        if [ "$changes_found" -eq 1 ]; then
                echo -e "${GREEN}${label} chezmoi dotfiles synchronized.${NC}"
        else
                echo -e "${BLUE}${label} chezmoi dotfiles are already synchronized.${NC}"
        fi

        return 0
)

sync_chezmoi() (
        local state_home sync_state_dir sync_lock_fd trusted_allowlist required
        local label source_dir persistent_state marker allowlist_rel failed=0
        for required in chezmoi git flock; do
                if ! command -v "$required" >/dev/null 2>&1; then
                        echo -e "${YELLOW}$required is unavailable. Skipping dotfile sync.${NC}" >&2
                        return 1
                fi
        done
        state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
        sync_state_dir="${state_home}/chezmoi-sync"

        umask 077
        if ! mkdir -p "$state_home" "$sync_state_dir" || ! chmod 700 "$sync_state_dir"; then
                echo -e "${YELLOW}Could not create chezmoi sync state directories. Skipping dotfile sync.${NC}" >&2
                return 1
        fi

        if ! exec {sync_lock_fd}>"$sync_state_dir/lock"; then
                echo -e "${YELLOW}Could not open the chezmoi sync lock. Skipping dotfile sync.${NC}" >&2
                return 1
        fi

        if ! flock -n "$sync_lock_fd"; then
                echo -e "${YELLOW}Another chezmoi sync is already running. Skipping dotfile sync.${NC}" >&2
                return 1
        fi

        trusted_allowlist="$(mktemp "${TMPDIR:-/tmp}/chezmoi-policy.XXXXXX")" || return 1
        trap 'rm -f "$trusted_allowlist"' EXIT
        for label in Private Public; do
                case "$label" in
                        Public)
                                if ! source_dir="$(chezmoi source-path 2>/dev/null)"; then
                                        echo -e "${YELLOW}Public chezmoi source is unavailable.${NC}" >&2
                                        failed=1
                                        continue
                                fi
                                persistent_state=""
                                marker="$sync_state_dir/public-head"
                                allowlist_rel="docs/private-source-allowlist.txt"
                                ;;
                        Private)
                                source_dir="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi-private"
                                persistent_state="$state_home/chezmoi-private.boltdb"
                                marker="$sync_state_dir/private-head"
                                allowlist_rel="private-source-allowlist.txt"
                                if [ -t 0 ]; then
                                        GPG_TTY="$(tty)"
                                        export GPG_TTY
                                fi
                                ;;
                esac
                # Each repository uses its own committed privacy policy, not the other's working tree.
                if ! git -C "$source_dir" show "HEAD:$allowlist_rel" > "$trusted_allowlist" || [ ! -s "$trusted_allowlist" ]; then
                        echo -e "${YELLOW}${label} committed privacy policy is unavailable. Skipping only this repository.${NC}" >&2
                        failed=1
                        continue
                fi
                if ! sync_chezmoi_repo "$label" "$source_dir" "$persistent_state" "$marker" \
                        "$source_dir/$allowlist_rel" "$trusted_allowlist"; then
                        echo -e "${YELLOW}${label} sync did not complete; continuing with the remaining work.${NC}" >&2
                        failed=1
                fi
        done
        return "$failed"
)

update_chezmoi_extras() (
	local public_source public_allowlist state_home sync_state_dir public_head
	local source_status target_status current_marker applied_marker exit_status
	local extras_lock_fd
	local -a chezmoi_cmd

	if ! command -v chezmoi >/dev/null 2>&1 ||
		! command -v git >/dev/null 2>&1 ||
		! command -v flock >/dev/null 2>&1; then
		echo -e "${YELLOW}Chezmoi, Git or flock is unavailable. Skipping optional chezmoi assets.${NC}" >&2
		return 0
	fi

	if ! command -v timeout >/dev/null 2>&1; then
		echo -e "${YELLOW}timeout is unavailable. Skipping optional chezmoi assets.${NC}" >&2
		return 0
	fi

	if ! public_source="$(chezmoi source-path 2>/dev/null)" || [ ! -d "$public_source" ]; then
		echo -e "${YELLOW}Public chezmoi source is unavailable. Skipping optional assets.${NC}" >&2
		return 0
	fi

	state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
	sync_state_dir="${state_home}/chezmoi-sync"
	public_head="${sync_state_dir}/public-head"
	umask 077
	if ! mkdir -p "$state_home" "$sync_state_dir" || ! chmod 700 "$sync_state_dir"; then
		echo -e "${YELLOW}Could not prepare the chezmoi sync lock. Skipping optional assets.${NC}" >&2
		return 0
	fi

	if ! exec {extras_lock_fd}>"$sync_state_dir/lock" || ! flock -n "$extras_lock_fd"; then
		echo -e "${YELLOW}Another chezmoi operation is running. Skipping optional assets.${NC}" >&2
		return 0
	fi

	public_allowlist="${public_source}/docs/private-source-allowlist.txt"
	if ! validate_chezmoi_source "Public" "$public_source" "$public_allowlist"; then
		echo -e "${YELLOW}Public chezmoi source validation failed. Skipping optional assets.${NC}" >&2
		return 0
	fi

	if ! source_status="$(git -C "$public_source" status --porcelain)" || [ -n "$source_status" ]; then
		echo -e "${YELLOW}Public chezmoi source is dirty. Skipping optional assets.${NC}" >&2
		return 0
	fi

	chezmoi_cmd=(chezmoi -S "$public_source")
	if ! current_marker="$(get_chezmoi_marker "$public_source" "${chezmoi_cmd[@]}")" ||
		[ ! -r "$public_head" ] ||
		! IFS= read -r applied_marker < "$public_head" ||
		[ "$applied_marker" != "$current_marker" ]; then
		echo -e "${YELLOW}Public chezmoi core state is not synchronized. Skipping optional assets.${NC}" >&2
		return 0
	fi

	if ! target_status="$(CHEZMOI_SKIP_EXTERNALS=1 "${chezmoi_cmd[@]}" --refresh-externals=never --color=false status --exclude=scripts,externals)" ||
		[ -n "$target_status" ]; then
		echo -e "${YELLOW}Public chezmoi-managed files are not synchronized. Skipping optional assets.${NC}" >&2
		return 0
	fi

	if timeout --kill-after=30s 15m env \
		CHEZMOI_SKIP_NEUROWAVE=1 \
		GCM_INTERACTIVE=never \
		GIT_ASKPASS=/bin/false \
		GIT_TERMINAL_PROMPT=0 \
		GIT_CONFIG_COUNT=2 \
		GIT_CONFIG_KEY_0=protocol.version \
		GIT_CONFIG_VALUE_0=1 \
		GIT_CONFIG_KEY_1=credential.interactive \
		GIT_CONFIG_VALUE_1=false \
		SSH_ASKPASS=/bin/false \
		SSH_ASKPASS_REQUIRE=never \
		"${chezmoi_cmd[@]}" --no-tty --keep-going apply --include=scripts,externals </dev/null; then
		echo -e "${GREEN}Optional chezmoi scripts and external assets check completed.${NC}"
	else
		exit_status=$?
		if [ "$exit_status" -eq 124 ]; then
			echo -e "${YELLOW}Optional chezmoi assets timed out; core dotfile sync remains complete.${NC}" >&2
		else
			echo -e "${YELLOW}Optional chezmoi assets failed; core dotfile sync remains complete.${NC}" >&2
		fi
	fi
	return 0
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        set -eo pipefail
        if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
                printf 'Usage: sync_chezmoi.sh [--extras]\n\nPrivate then public sync. --extras refreshes optional public assets only.\n'
                exit 0
        fi
        if ((EUID == 0)); then
                printf 'Run sync_chezmoi.sh as your regular user.\n' >&2
                exit 1
        fi
        if (($# > 1)); then
                printf 'Usage: sync_chezmoi.sh [--extras]\n' >&2
                exit 2
        fi
        case "${1:-}" in
                '') sync_chezmoi ;;
                --extras) update_chezmoi_extras ;;
                *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
        esac
fi
