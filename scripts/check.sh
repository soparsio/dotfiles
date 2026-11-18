#!/bin/sh

# Render and validate managed configuration in isolated temporary homes.
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
CHEZMOI=${CHEZMOI:-chezmoi}
CHEZMOI_SOURCE=${CHEZMOI_SOURCE:-$repo_root}
case $CHEZMOI_SOURCE in
/*) ;;
*) CHEZMOI_SOURCE="$PWD/$CHEZMOI_SOURCE" ;;
esac
CHEZMOI_SOURCE=$(CDPATH= cd "$CHEZMOI_SOURCE" && pwd)
cd "$CHEZMOI_SOURCE"

if [ "${CHECK_TRACE:-0}" = 1 ]; then
  set -x
fi

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [all|bootstrap|profiles|platforms|profile-state|vscode]\n' "${0##*/}" >&2
  exit 2
fi

suite=${1:-all}
case $suite in
all | bootstrap | profiles | platforms | profile-state | vscode) ;;
*)
  printf 'Unknown check suite: %s\n' "$suite" >&2
  printf 'Usage: %s [all|bootstrap|profiles|platforms|profile-state|vscode]\n' "${0##*/}" >&2
  exit 2
  ;;
esac

for command_name in "$CHEZMOI" python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command_name" >&2
    exit 127
  fi
done

if [ "$suite" != bootstrap ]; then
  for command_name in zsh git gh; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'Required command not found: %s\n' "$command_name" >&2
      exit 127
    fi
  done
fi

PROFILE_TEST_DATA='{"name":"Fixture User","email":"fixture@example.test","editor":"code --wait","vscode":{"defaultProfile":"Default"},"path":{"aliases":{"home":"~","root":"/","ws":"~/Workspace","projects":"~/Projects"},"profiles":"~/.config/profiles"},"accounts":{"default":{"tools":["codex","vscode"],"name":"Default"},"review":{"tools":["codex","gh","git","vscode"],"alias":"review-account","name":"Review Profile","email":"profile@example.test","git":{"name":"Review User","email":"review@example.test"}},"git_only":{"tools":["git","vscode"],"email":"git-only@example.test"},"vscode_only":{"tools":["vscode"]},"gh-default":{"tools":["gh"],"alias":"fallback-login"},"gh-git-default":{"tools":["gh","git"],"alias":"custom-alias","git":{"name":"Fallback Git","email":"fallback@example.test"}}}}'
ARRAY_PROFILE_TEST_DATA='{"editor":"code --wait","vscode":{"defaultProfile":"Default"},"path":{"profiles":"~/.config/profiles"},"accounts":[{"id":"array-profile","name":"Array Profile","email":"array@example.test","alias":"array-gh","tools":["codex","gh","git","vscode"],"git":{"gpgsign":true},"gh":{"username":"array-user"}}],"ssh":{"gh":{"accounts":[{"username":"array-user","signingKey":"~/.ssh/array-signing.pub"}]}}}'
NUMERIC_PROFILE_TEST_DATA='{"editor":"code --wait","path":{"profiles":"~/.config/profiles"},"accounts":{"numeric":{"tools":["git","gh"],"alias":123,"name":123}}}'
MULTI_TOOL_ALIAS_TEST_DATA='{"accounts":{"work":{"tools":["codex","claude","copilot","gemini","vscode"]}}}'
PROFILE_INSTRUCTION_TEST_DATA='{"path":{"profiles":"~/.config/profiles"},"accounts":{"instructions":"All profile base","inherit":{"tools":["codex"]},"empty_profile":{"tools":["codex"],"instructions":""},"empty_tool":{"tools":["codex"],"instructions":"Parent profile base","codex":{"instructions":""}},"specific":{"tools":["codex"],"instructions":"Specific\u0027s base"},"tool":{"tools":["codex"],"instructions":"Profile base","codex":{"force":true,"instructions":"Tool replacement"}}}}'
PROFILE_FORCE_TEST_DATA='{"path":{"profiles":"~/.config/profiles"},"accounts":{"instructions":"Global base","ai_append":{"tools":["codex"],"instructions":"Profile base","ai":{"force":false,"instructions":"AI append"},"codex":{"force":false,"instructions":"Codex append"}},"ai_default":{"tools":["codex"],"ai":{"instructions":"AI default append"}},"ai_force":{"tools":["codex"],"instructions":"Profile base","ai":{"force":true,"instructions":"AI replacement"}},"tool_force_false":{"tools":["codex"],"instructions":"Profile base","codex":{"force":false,"instructions":"Tool append"}},"tool_default":{"tools":["codex"],"instructions":"Tool parent base","codex":{"instructions":"Tool default append"}},"tool_force_true":{"tools":["codex"],"instructions":"Profile base","codex":{"force":true,"instructions":"Tool replacement"}}}}'
SPECIAL_PATH_TEST_DATA='{"path":{"aliases":{"ws":"~/John\u0027s folder/$HOME"}}}'
ALIAS_COLLISION_TEST_DATA='{"vscode":{"defaultProfile":"Default"},"path":{"aliases":{"code-review":"~/Workspace"}},"accounts":{"review":{"tools":["vscode"]}}}'

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
touch "$tmpdir/chezmoi.toml"

copy_accounts_template() {
  accounts_template_dir="$1/home/.chezmoitemplates/accounts"
  mkdir -p "$accounts_template_dir"
  cp home/.chezmoitemplates/accounts/by-id home/.chezmoitemplates/accounts/ssh-signing home/.chezmoitemplates/accounts/tools "$accounts_template_dir/"
  mkdir -p "$1/home/.chezmoitemplates/git"
  cp home/.chezmoitemplates/git/signing "$1/home/.chezmoitemplates/git/"
}

check_bootstrap() {
  mkdir -p "$tmpdir/data-bootstrap-source/scripts" "$tmpdir/data-bootstrap-source/examples/.chezmoidata"
  cp scripts/copy-example-data.sh "$tmpdir/data-bootstrap-source/scripts/"
  cp examples/.chezmoidata/*.example "$tmpdir/data-bootstrap-source/examples/.chezmoidata/"
  printf '%s\n' home >"$tmpdir/data-bootstrap-source/.chezmoiroot"
  sh "$tmpdir/data-bootstrap-source/scripts/copy-example-data.sh" "$tmpdir/data-bootstrap-source" >/dev/null
  cmp -s examples/.chezmoidata/ai.yaml.example "$tmpdir/data-bootstrap-source/home/.chezmoidata/ai.yaml"
  cmp -s examples/.chezmoidata/99-local.yaml.example "$tmpdir/data-bootstrap-source/home/.chezmoidata/99-local.yaml"
  cmp -s examples/.chezmoidata/host.yaml.example "$tmpdir/data-bootstrap-source/home/.chezmoidata/host.yaml"
  cmp -s examples/.chezmoidata/path.yaml.example "$tmpdir/data-bootstrap-source/home/.chezmoidata/path.yaml"
  grep -Fx 'accounts:' "$tmpdir/data-bootstrap-source/home/.chezmoidata/99-local.yaml" >/dev/null
  "$CHEZMOI" --source "$tmpdir/data-bootstrap-source" --config "$tmpdir/chezmoi.toml" data --format=json >"$tmpdir/data-bootstrap.json"
  python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); accounts={item["id"]:item for item in data["accounts"]}; assert data["name"] == "" and data["email"] == ""; assert data["editor"] == "code --wait" and data["vscode"]["defaultProfile"] == "Default"; assert data["host"]["ollama"] == "127.0.0.1:11434"; assert data["path"]["aliases"] == {"home":"~","root":"/","ws":"~/Workspace"} and data["path"]["profiles"] == "~/.config/profiles"; assert "workspaceDir" not in data and "profilesDir" not in data; assert isinstance(data["ai"]["instructions"], str) and "personal" in accounts; assert accounts["personal"]["ai"]["force"] is False and isinstance(accounts["personal"]["ai"]["instructions"], str); assert accounts["personal"]["codex"]["force"] is False; assert accounts["work"]["ai"]["force"] is True' "$tmpdir/data-bootstrap.json"
  mkdir -p "$tmpdir/no-host-source/home/dot_config/zsh"
  printf '%s\n' home >"$tmpdir/no-host-source/.chezmoiroot"
  cp home/dot_config/zsh/exports.zsh.tmpl "$tmpdir/no-host-source/home/dot_config/zsh/"
  "$CHEZMOI" --source "$tmpdir/no-host-source" --config "$tmpdir/chezmoi.toml" --override-data '{"editor":"code --wait","host":{}}' cat ~/.config/zsh/exports.zsh >"$tmpdir/exports-no-host"
  grep -F 'export OLLAMA_HOST="127.0.0.1:11434"' "$tmpdir/exports-no-host" >/dev/null
  mkdir -p "$tmpdir/gitconfig-fallback-source/home"
  printf '%s\n' home >"$tmpdir/gitconfig-fallback-source/.chezmoiroot"
  cp home/dot_gitconfig.tmpl "$tmpdir/gitconfig-fallback-source/home/"
  copy_accounts_template "$tmpdir/gitconfig-fallback-source"
  "$CHEZMOI" --source "$tmpdir/gitconfig-fallback-source" --config "$tmpdir/chezmoi.toml" --override-data '{"name":"Your Name","email":"you@example.com"}' cat ~/.gitconfig >"$tmpdir/gitconfig"
  grep -Fx '    name = "Your Name"' "$tmpdir/gitconfig" >/dev/null
  grep -Fx '    email = "you@example.com"' "$tmpdir/gitconfig" >/dev/null
  mkdir -p "$tmpdir/gitconfig-local-source/home/.chezmoidata"
  printf '%s\n' home >"$tmpdir/gitconfig-local-source/.chezmoiroot"
  cp home/dot_gitconfig.tmpl "$tmpdir/gitconfig-local-source/home/"
  copy_accounts_template "$tmpdir/gitconfig-local-source"
  cat >"$tmpdir/gitconfig-local-source/home/.chezmoidata/99-local.yaml" <<'YAML'
name: Local Git User
email: local-git@example.test
git:
  gpgsign: false
gh:
  gpgsign: false
ssh:
  gh:
    accounts:
      - isRoot: false
        name: Profile Git User
        email: profile-git@example.test
        signingKey: ~/.ssh/profile.pub
      - isRoot: true
        name: Root Git User
        email: root-git@example.test
        signingKey: ~/.ssh/signing.pub
accounts: {}
YAML
  "$CHEZMOI" --source "$tmpdir/gitconfig-local-source" --config "$tmpdir/chezmoi.toml" cat ~/.gitconfig >"$tmpdir/gitconfig-local"
  grep -Fx '    name = "Root Git User"' "$tmpdir/gitconfig-local" >/dev/null
  grep -Fx '    email = "root-git@example.test"' "$tmpdir/gitconfig-local" >/dev/null
  grep -Fx '    signingkey = ~/.ssh/signing.pub' "$tmpdir/gitconfig-local" >/dev/null
  cat >"$tmpdir/gitconfig-local-source/home/.chezmoidata/99-local.yaml" <<'YAML'
name: Local Git User
email: local-git@example.test
git:
  gpgsign: true
gh:
  gpgsign: false
  sshKey: ~/.ssh/signing
accounts: {}
YAML
  "$CHEZMOI" --source "$tmpdir/gitconfig-local-source" --config "$tmpdir/chezmoi.toml" cat ~/.gitconfig >"$tmpdir/gitconfig-local-disabled"
  ! grep -F 'signingkey = ~/.ssh/signing.pub' "$tmpdir/gitconfig-local-disabled" >/dev/null

  mkdir -p "$tmpdir/git-config-template-source/home/dot_config/git" "$tmpdir/git-config-template-source/home/.chezmoitemplates/path"
  printf '%s\n' home >"$tmpdir/git-config-template-source/.chezmoiroot"
  cp home/dot_config/git/config.tmpl "$tmpdir/git-config-template-source/home/dot_config/git/"
  cp home/.chezmoitemplates/path/profiles-dir "$tmpdir/git-config-template-source/home/.chezmoitemplates/path/"
  copy_accounts_template "$tmpdir/git-config-template-source"
  "$CHEZMOI" --source "$tmpdir/git-config-template-source" --config "$tmpdir/chezmoi.toml" --override-data '{"name":"Fixture User","email":"fixture@example.test","editor":"code --wait","path":{"profiles":"~/.config/profiles"},"ssh":{"default":{"signer":"~/.custom/allowed_signers"},"gh":{"signer":"~/.gh/allowed_signers"}},"git":{"gpgsign":true},"gh":{"gpgsign":false},"accounts":{"disabled":{"tools":["git"],"git":{"gpgsign":false}},"override":{"tools":["git","gh"],"git":{"gpgsign":false},"gh":{"gpgsign":true,"username":"fixture"}},"inherit":{"tools":["git"]}}}' execute-template --file home/dot_config/git/config.tmpl >"$tmpdir/git-config-template"
  grep -F 'commit.gpgsign=false' "$tmpdir/git-config-template" >/dev/null
  grep -F 'commit.gpgsign=true' "$tmpdir/git-config-template" >/dev/null
  grep -F '    gpgsign = false' "$tmpdir/git-config-template" >/dev/null
  grep -F 'allowedSignersFile = ~/.gh/allowed_signers' "$tmpdir/git-config-template" >/dev/null
  "$CHEZMOI" --source "$tmpdir/git-config-template-source" --config "$tmpdir/chezmoi.toml" --override-data '{"editor":"code --wait","ssh":{"default":{"signer":"~/.custom/allowed_signers"},"gh":{}}}' execute-template --file home/dot_config/git/config.tmpl >"$tmpdir/git-config-template-default-signer"
  grep -F 'allowedSignersFile = ~/.custom/allowed_signers' "$tmpdir/git-config-template-default-signer" >/dev/null
  printf '%s\n' 'Keep existing local data' >"$tmpdir/data-bootstrap-source/home/.chezmoidata/ai.yaml"
  sh "$tmpdir/data-bootstrap-source/scripts/copy-example-data.sh" "$tmpdir/data-bootstrap-source" >/dev/null
  grep -Fx 'Keep existing local data' "$tmpdir/data-bootstrap-source/home/.chezmoidata/ai.yaml" >/dev/null
  mkdir -p "$tmpdir/remote-install-source/home" "$tmpdir/remote-install-source/scripts" "$tmpdir/remote-install-source/examples/.chezmoidata" "$tmpdir/remote-install-bin" "$tmpdir/remote-install-checkout"
  cp scripts/copy-example-data.sh "$tmpdir/remote-install-source/scripts/"
  cp examples/.chezmoidata/99-local.yaml.example "$tmpdir/remote-install-source/examples/.chezmoidata/"
  cp install.sh "$tmpdir/remote-install-checkout/install.sh"
  cat >"$tmpdir/remote-install-bin/chezmoi" <<'EOF'
#!/bin/sh
case "$1" in
  init|diff) exit 0 ;;
  source-path) printf '%s\n' "$CHEZMOI_TEST_SOURCE_ROOT" ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$tmpdir/remote-install-bin/chezmoi"
  printf 'n\n' | PATH="$tmpdir/remote-install-bin:$PATH" HOME="$tmpdir/remote-install-home" \
    CHEZMOI_TEST_SOURCE_ROOT="$tmpdir/remote-install-source/home" \
    sh "$tmpdir/remote-install-checkout/install.sh" >"$tmpdir/remote-install-output"
  test -f "$tmpdir/remote-install-source/home/.chezmoidata/99-local.yaml"
  grep -F 'Created machine-local data file: home/.chezmoidata/99-local.yaml' "$tmpdir/remote-install-output" >/dev/null
}

check_profiles() {
  mkdir -p "$tmpdir/profile-instruction-source/home/.chezmoiscripts" "$tmpdir/profile-instruction-source/home/.chezmoitemplates/codex" "$tmpdir/profile-instruction-source/home/.chezmoitemplates/Code" "$tmpdir/profile-instruction-source/home/.chezmoitemplates/path" "$tmpdir/profile-instruction-source/scripts" "$tmpdir/profile-instruction-home/.codex"
  printf '%s\n' home >"$tmpdir/profile-instruction-source/.chezmoiroot"
  cp scripts/share-codex-config.py "$tmpdir/profile-instruction-source/scripts/"
  cp scripts/configure-vscode-profiles.py "$tmpdir/profile-instruction-source/scripts/"
  cp home/.chezmoitemplates/codex/config.toml "$tmpdir/profile-instruction-source/home/.chezmoitemplates/codex/"
  cp home/.chezmoitemplates/Code/settings-profile.json "$tmpdir/profile-instruction-source/home/.chezmoitemplates/Code/"
  cp home/.chezmoitemplates/path/profiles-dir "$tmpdir/profile-instruction-source/home/.chezmoitemplates/path/"
  copy_accounts_template "$tmpdir/profile-instruction-source"
  printf '%s\n' 'Shared agent baseline' >"$tmpdir/profile-instruction-home/.codex/AGENTS.md"
  cp home/.chezmoiscripts/run_onchange_setup-profiles.sh.tmpl "$tmpdir/profile-instruction-source/home/.chezmoiscripts/setup.tmpl"
  "$CHEZMOI" --source "$tmpdir/profile-instruction-source" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_INSTRUCTION_TEST_DATA" execute-template --file "$tmpdir/profile-instruction-source/home/.chezmoiscripts/setup.tmpl" >"$tmpdir/profile-instruction-setup.sh"
  python3 -c 'import pathlib,sys; text=pathlib.Path(sys.argv[1]).read_text().replace("$HOME", sys.argv[2]); pathlib.Path(sys.argv[3]).write_text(text)' "$tmpdir/profile-instruction-setup.sh" "$tmpdir/profile-instruction-home" "$tmpdir/profile-instruction-setup-isolated.sh"
  ! grep -F '/Users/sio' "$tmpdir/profile-instruction-setup-isolated.sh" >/dev/null
  sh -n "$tmpdir/profile-instruction-setup-isolated.sh"
  HOME="$tmpdir/profile-instruction-home" sh "$tmpdir/profile-instruction-setup-isolated.sh"
  grep -Fx 'All profile base' "$tmpdir/profile-instruction-home/.config/profiles/inherit/codex/AGENTS.md" >/dev/null
  grep -Fx "Specific's base" "$tmpdir/profile-instruction-home/.config/profiles/specific/codex/AGENTS.md" >/dev/null
  grep -Fx 'Tool replacement' "$tmpdir/profile-instruction-home/.config/profiles/tool/codex/AGENTS.md" >/dev/null
  mkdir -p "$tmpdir/profile-force-home/.codex"
  printf '%s\n' 'Shared agent baseline' >"$tmpdir/profile-force-home/.codex/AGENTS.md"
  "$CHEZMOI" --source "$tmpdir/profile-instruction-source" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_FORCE_TEST_DATA" execute-template --file "$tmpdir/profile-instruction-source/home/.chezmoiscripts/setup.tmpl" >"$tmpdir/profile-force-setup.sh"
  python3 -c 'import pathlib,sys; text=pathlib.Path(sys.argv[1]).read_text().replace("$HOME", sys.argv[2]); pathlib.Path(sys.argv[3]).write_text(text)' "$tmpdir/profile-force-setup.sh" "$tmpdir/profile-force-home" "$tmpdir/profile-force-setup-isolated.sh"
  sh -n "$tmpdir/profile-force-setup-isolated.sh"
  HOME="$tmpdir/profile-force-home" sh "$tmpdir/profile-force-setup-isolated.sh"
  grep -Fx 'Profile base' "$tmpdir/profile-force-home/.config/profiles/ai_append/codex/AGENTS.md" >/dev/null
  grep -Fx 'AI append' "$tmpdir/profile-force-home/.config/profiles/ai_append/codex/AGENTS.md" >/dev/null
  grep -Fx 'Codex append' "$tmpdir/profile-force-home/.config/profiles/ai_append/codex/AGENTS.md" >/dev/null
  grep -Fx 'Global base' "$tmpdir/profile-force-home/.config/profiles/ai_default/codex/AGENTS.md" >/dev/null
  grep -Fx 'AI default append' "$tmpdir/profile-force-home/.config/profiles/ai_default/codex/AGENTS.md" >/dev/null
  grep -Fx 'AI replacement' "$tmpdir/profile-force-home/.config/profiles/ai_force/codex/AGENTS.md" >/dev/null
  ! grep -E 'Global base|Profile base' "$tmpdir/profile-force-home/.config/profiles/ai_force/codex/AGENTS.md" >/dev/null
  grep -Fx 'Profile base' "$tmpdir/profile-force-home/.config/profiles/tool_force_false/codex/AGENTS.md" >/dev/null
  grep -Fx 'Tool append' "$tmpdir/profile-force-home/.config/profiles/tool_force_false/codex/AGENTS.md" >/dev/null
  grep -Fx 'Tool parent base' "$tmpdir/profile-force-home/.config/profiles/tool_default/codex/AGENTS.md" >/dev/null
  grep -Fx 'Tool default append' "$tmpdir/profile-force-home/.config/profiles/tool_default/codex/AGENTS.md" >/dev/null
  grep -Fx 'Tool replacement' "$tmpdir/profile-force-home/.config/profiles/tool_force_true/codex/AGENTS.md" >/dev/null
  ! grep -E 'Global base|Profile base' "$tmpdir/profile-force-home/.config/profiles/tool_force_true/codex/AGENTS.md" >/dev/null
  if "$CHEZMOI" --source "$tmpdir/profile-instruction-source" --config "$tmpdir/chezmoi.toml" --override-data '{"accounts":{"bad":{"tools":["codex"],"ai":{"force":"false","instructions":"Invalid force"}}}}' execute-template --file "$tmpdir/profile-instruction-source/home/.chezmoiscripts/setup.tmpl" >"$tmpdir/invalid-force-output" 2>&1; then
    printf '%s\n' 'Invalid AI force value was accepted.' >&2
    exit 1
  fi
  grep -F 'must be a boolean' "$tmpdir/invalid-force-output" >/dev/null
  if "$CHEZMOI" --source "$tmpdir/profile-instruction-source" --config "$tmpdir/chezmoi.toml" --override-data '{"accounts":{"bad":{"tools":["codex"],"codex":{"force":"false","instructions":"Invalid force"}}}}' execute-template --file "$tmpdir/profile-instruction-source/home/.chezmoiscripts/setup.tmpl" >"$tmpdir/invalid-tool-force-output" 2>&1; then
    printf '%s\n' 'Invalid tool force value was accepted.' >&2
    exit 1
  fi
  grep -F 'must be a boolean' "$tmpdir/invalid-tool-force-output" >/dev/null
  grep -Fx 'All profile base' "$tmpdir/profile-instruction-home/.config/profiles/empty_profile/codex/AGENTS.md" >/dev/null
  grep -Fx 'Parent profile base' "$tmpdir/profile-instruction-home/.config/profiles/empty_tool/codex/AGENTS.md" >/dev/null
  mkdir -p "$tmpdir/empty-profile-home/.codex"
  printf '%s\n' 'Shared agent baseline' >"$tmpdir/empty-profile-home/.codex/AGENTS.md"
  mkdir -p "$tmpdir/empty-profile-home/.config/profiles/empty/codex"
  printf '%s\n' '<!-- Managed by chezmoi; edit profiles.toml instead. -->' 'Old generated instructions' >"$tmpdir/empty-profile-home/.config/profiles/empty/codex/AGENTS.md"
  "$CHEZMOI" --source "$tmpdir/profile-instruction-source" --config "$tmpdir/chezmoi.toml" --override-data '{"accounts":{"instructions":"","empty":{"tools":["codex"]}}}' execute-template --file "$tmpdir/profile-instruction-source/home/.chezmoiscripts/setup.tmpl" >"$tmpdir/empty-profile-setup.sh"
  python3 -c 'import pathlib,sys; text=pathlib.Path(sys.argv[1]).read_text().replace("$HOME", sys.argv[2]); pathlib.Path(sys.argv[3]).write_text(text)' "$tmpdir/empty-profile-setup.sh" "$tmpdir/empty-profile-home" "$tmpdir/empty-profile-setup-isolated.sh"
  ! grep -F '/Users/sio' "$tmpdir/empty-profile-setup-isolated.sh" >/dev/null
  sh -n "$tmpdir/empty-profile-setup-isolated.sh"
  HOME="$tmpdir/empty-profile-home" sh "$tmpdir/empty-profile-setup-isolated.sh"
  test -L "$tmpdir/empty-profile-home/.config/profiles/empty/codex/AGENTS.md"
  test "$(readlink "$tmpdir/empty-profile-home/.config/profiles/empty/codex/AGENTS.md")" = "$tmpdir/empty-profile-home/.codex/AGENTS.md"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"path":{"profiles":"~/.config/profiles/"}}' execute-template --file home/.chezmoitemplates/path/profiles-dir >"$tmpdir/profiles-dir-trailing-slash"
  test "$(cat "$tmpdir/profiles-dir-trailing-slash")" = '.config/profiles'
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_TEST_DATA" cat ~/.config/zsh/aliases.zsh >"$tmpdir/aliases"
  grep -Fx 'alias c="claude"' "$tmpdir/aliases" >/dev/null
  grep -Fx "alias code='profile-use vscode Default'" "$tmpdir/aliases" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$MULTI_TOOL_ALIAS_TEST_DATA" execute-template --file home/dot_config/zsh/aliases.zsh.tmpl >"$tmpdir/multi-tool-aliases"
  grep -Fx "alias codex-work='profile-use codex work'" "$tmpdir/multi-tool-aliases" >/dev/null
  grep -Fx "alias claude-work='profile-use claude work'" "$tmpdir/multi-tool-aliases" >/dev/null
  grep -Fx "alias copilot-work='profile-use copilot work'" "$tmpdir/multi-tool-aliases" >/dev/null
  grep -Fx "alias gemini-work='profile-use gemini work'" "$tmpdir/multi-tool-aliases" >/dev/null
  zsh -fc 'source "$1"; alias -L codex-work' _ "$tmpdir/multi-tool-aliases" | grep -Fx "alias codex-work='profile-use codex work'" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$ARRAY_PROFILE_TEST_DATA" execute-template --file home/dot_config/zsh/aliases.zsh.tmpl >"$tmpdir/array-profile-aliases"
  grep -Fx "alias codex-array-profile='profile-use codex array-profile'" "$tmpdir/array-profile-aliases" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$ARRAY_PROFILE_TEST_DATA" cat ~/.config/git/config >"$tmpdir/array-profile-git-config"
  grep -F 'array-gh = "!f() { unset GH_TOKEN' "$tmpdir/array-profile-git-config" >/dev/null
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/array-profile/gh\" git' "$tmpdir/array-profile-git-config" >/dev/null
  grep -F -- '-c user.signingkey=\"~/.ssh/array-signing.pub\" -c commit.gpgsign=true' "$tmpdir/array-profile-git-config" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$ARRAY_PROFILE_TEST_DATA" cat ~/.config/gh/config.yml >"$tmpdir/array-profile-gh-config"
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/array-profile/gh\"' "$tmpdir/array-profile-gh-config" >/dev/null
  "$CHEZMOI" --source "$tmpdir/profile-instruction-source" --config "$tmpdir/chezmoi.toml" --override-data "$ARRAY_PROFILE_TEST_DATA" execute-template --file "$tmpdir/profile-instruction-source/home/.chezmoiscripts/setup.tmpl" >"$tmpdir/array-profile-setup.sh"
  grep -F "create_profile gh 'array-profile'" "$tmpdir/array-profile-setup.sh" >/dev/null
  ! grep -E "alias (git|gh)-review-account=" "$tmpdir/aliases" >/dev/null
  if "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"editor":"code --wait","accounts":{"bad":{"alias":"bad alias","tools":["git"]}}}' cat ~/.config/git/config >"$tmpdir/invalid-profile-alias" 2>&1; then
    printf '%s\n' 'Invalid profile alias was accepted.' >&2
    exit 1
  fi
  grep -F 'invalid profile alias' "$tmpdir/invalid-profile-alias" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$NUMERIC_PROFILE_TEST_DATA" cat ~/.config/git/config >"$tmpdir/numeric-git-config"
  grep -F 'profile-123 = ' "$tmpdir/numeric-git-config" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_TEST_DATA" cat ~/.config/git/config >"$tmpdir/git-config"
  grep -F 'review-account = "!f() { unset GH_TOKEN' "$tmpdir/git-config" >/dev/null
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/review/gh\" git' "$tmpdir/git-config" >/dev/null
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/gh-git-default/gh\" git' "$tmpdir/git-config" >/dev/null
  grep -F -- '-c user.name=\"Review User\" -c user.email=\"review@example.test\"' "$tmpdir/git-config" >/dev/null
  grep -F 'git-only = "!f() { git -c user.email=\"git-only@example.test\"' "$tmpdir/git-config" >/dev/null
  mkdir -p "$tmpdir/gh-bin"
  printf '%s\n' '#!/bin/sh' 'exit 0' >"$tmpdir/gh-bin/gh"
  chmod +x "$tmpdir/gh-bin/gh"
  PATH="$tmpdir/gh-bin:$PATH" GIT_CONFIG_GLOBAL="$tmpdir/git-config" GIT_CONFIG_SYSTEM=/dev/null git review-account config user.name | grep -Fx 'Review User' >/dev/null
  PATH="$tmpdir/gh-bin:$PATH" GIT_CONFIG_GLOBAL="$tmpdir/git-config" GIT_CONFIG_SYSTEM=/dev/null git review-account config user.email | grep -Fx 'review@example.test' >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_TEST_DATA" cat ~/.config/gh/config.yml >"$tmpdir/gh-config"
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/review/gh\"' "$tmpdir/gh-config" >/dev/null
  grep -F 'GIT_CONFIG_PARAMETERS=' "$tmpdir/gh-config" >/dev/null
  GIT_CONFIG_PARAMETERS="'user.name=Review User' 'user.email=review@example.test'" git config user.name | grep -Fx 'Review User' >/dev/null
  GIT_CONFIG_PARAMETERS="'user.name=Review User' 'user.email=review@example.test'" git config user.email | grep -Fx 'review@example.test' >/dev/null
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/gh-default/gh\"' "$tmpdir/gh-config" >/dev/null
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/gh-git-default/gh\"' "$tmpdir/gh-config" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$NUMERIC_PROFILE_TEST_DATA" cat ~/.config/gh/config.yml >"$tmpdir/numeric-gh-config"
  grep -F 'GH_CONFIG_DIR=\"$HOME/.config/profiles/numeric/gh\"' "$tmpdir/numeric-gh-config" >/dev/null
  mkdir -p "$tmpdir/numeric-gh-config-dir"
  cp "$tmpdir/numeric-gh-config" "$tmpdir/numeric-gh-config-dir/config.yml"
  GH_CONFIG_DIR="$tmpdir/numeric-gh-config-dir" gh alias list | grep -F '123' >/dev/null
  mkdir -p "$tmpdir/gh-config-dir"
  cp "$tmpdir/gh-config" "$tmpdir/gh-config-dir/config.yml"
  GH_CONFIG_DIR="$tmpdir/gh-config-dir" gh alias list | grep -F 'review-account' >/dev/null
  mkdir -p "$tmpdir/gh-home"
  printf '%s\n' '#!/bin/sh' 'printf "%s|%s|%s|%s\n" "${GH_CONFIG_DIR-}" "${GH_TOKEN-}" "$*" "${GIT_CONFIG_PARAMETERS-}" >> "$GH_TEST_LOG"' 'printf "%s\n" "${GH_CONFIG_DIR-}" "$*"' >"$tmpdir/gh-bin/gh"
  chmod +x "$tmpdir/gh-bin/gh"
  REAL_GH=$(command -v gh)
  PATH="$tmpdir/gh-bin:$PATH" HOME="$tmpdir/gh-home" GH_CONFIG_DIR="$tmpdir/gh-config-dir" GH_TOKEN=shared-token GH_TEST_LOG="$tmpdir/gh-test-log" "$REAL_GH" review-account auth status >"$tmpdir/gh-alias-result"
  grep -F "$tmpdir/gh-home/.config/profiles/review/gh||auth status|" "$tmpdir/gh-test-log" >/dev/null
  grep -F "'user.name=Review User' 'user.email=review@example.test'" "$tmpdir/gh-test-log" >/dev/null
  grep -Fx 'auth status' "$tmpdir/gh-alias-result" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"accounts":null}' cat ~/.config/zsh/aliases.zsh >"$tmpdir/aliases-no-profiles"
  ! grep -F 'alias dotfiles-' "$tmpdir/aliases-no-profiles" >/dev/null
  mkdir -p "$tmpdir/init-config-source/home/.chezmoidata"
  printf '%s\n' home >"$tmpdir/init-config-source/.chezmoiroot"
  cp home/.chezmoi.yaml.tmpl "$tmpdir/init-config-source/home/"
  copy_accounts_template "$tmpdir/init-config-source"
  printf '%s\n' 'name: Fixture User' 'email: fixture@example.test' >"$tmpdir/init-config-source/home/.chezmoidata/99-local.yaml"
  "$CHEZMOI" --source "$tmpdir/init-config-source" --config "$tmpdir/chezmoi.toml" --override-data '{"name":"Stale Config User","email":"stale-config@example.test"}' execute-template --init --file home/.chezmoi.yaml.tmpl >"$tmpdir/chezmoi-init-config.yaml"
  grep -F '  name: Fixture User' "$tmpdir/chezmoi-init-config.yaml" >/dev/null
  grep -F '  email: fixture@example.test' "$tmpdir/chezmoi-init-config.yaml" >/dev/null
  grep -F '  hasMultiAccounts: false' "$tmpdir/chezmoi-init-config.yaml" >/dev/null
  ! grep -E '^[[:space:]]*$' "$tmpdir/chezmoi-init-config.yaml" >/dev/null
  ! grep -E '^(name|email):' "$tmpdir/chezmoi-init-config.yaml" >/dev/null
  ! grep -F 'stale-config@example.test' "$tmpdir/chezmoi-init-config.yaml" >/dev/null
  "$CHEZMOI" --source "$tmpdir/init-config-source" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_TEST_DATA" execute-template --init --file home/.chezmoi.yaml.tmpl >"$tmpdir/chezmoi.yaml"
  ! grep -F 'defaultProfile:' "$tmpdir/chezmoi.yaml" >/dev/null
  grep -F 'name: Fixture User' "$tmpdir/chezmoi.yaml" >/dev/null
  grep -F 'email: fixture@example.test' "$tmpdir/chezmoi.yaml" >/dev/null
  grep -F 'hasMultiAccounts: true' "$tmpdir/chezmoi.yaml" >/dev/null
  ! grep -F 'ollamaHost:' "$tmpdir/chezmoi.yaml" >/dev/null
  ! grep -E '^  accounts:' "$tmpdir/chezmoi.yaml" >/dev/null
  mkdir -p "$tmpdir/config-source"
  "$CHEZMOI" --source "$tmpdir/config-source" --config "$tmpdir/chezmoi.yaml" data --format=json >"$tmpdir/chezmoi-config-data.json"
  python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert data["name"] == "Fixture User" and data["email"] == "fixture@example.test"; assert "defaultProfile" not in data and "vscode" not in data and "workspaceDir" not in data and "profilesDir" not in data and "accounts" not in data' "$tmpdir/chezmoi-config-data.json"
  grep -F "alias dotfiles='profile-use vscode Default" "$tmpdir/aliases" >/dev/null
  grep -F "alias dotfiles-review='profile-use vscode review" "$tmpdir/aliases" >/dev/null
  grep -F 'alias ws='\''builtin cd -- "$HOME"/"Workspace"'\''' "$tmpdir/aliases" >/dev/null
  grep -F 'alias projects='\''builtin cd -- "$HOME"/"Projects"'\''' "$tmpdir/aliases" >/dev/null
  grep -F 'alias home='\''builtin cd -- "$HOME"'\''' "$tmpdir/aliases" >/dev/null
  grep -F 'alias root='\''builtin cd -- "/"'\''' "$tmpdir/aliases" >/dev/null
  ! grep -F 'ws() {' "$tmpdir/aliases" >/dev/null
  chezmoi --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$SPECIAL_PATH_TEST_DATA" cat ~/.config/zsh/aliases.zsh >"$tmpdir/aliases-special-path"
  zsh -n "$tmpdir/aliases-special-path"
  mkdir -p "$tmpdir/special-path-home/John's folder/\$HOME"
  HOME="$tmpdir/special-path-home" zsh -fic 'source "$1"; eval ws; test "$PWD" = "$2"' _ "$tmpdir/aliases-special-path" "$tmpdir/special-path-home/John's folder/\$HOME"
  if "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$ALIAS_COLLISION_TEST_DATA" cat ~/.config/zsh/aliases.zsh >"$tmpdir/alias-collision" 2>&1; then
    printf '%s\n' 'Expected a path alias colliding with a profile alias to fail template validation.' >&2
    exit 1
  fi
  grep -F 'path alias "code-review" conflicts with another generated alias' "$tmpdir/alias-collision" >/dev/null
  if "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"path":{"aliases":{"c":"~/Workspace"}}}' cat ~/.config/zsh/aliases.zsh >"$tmpdir/static-alias-collision" 2>&1; then
    printf '%s\n' 'Expected a path alias colliding with a built-in alias to fail template validation.' >&2
    exit 1
  fi
  grep -F 'path alias "c" conflicts with another generated alias' "$tmpdir/static-alias-collision" >/dev/null
  if "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"path":{"profiles":"relative"}}' execute-template --file home/.chezmoiscripts/run_onchange_setup-profiles.sh.tmpl >"$tmpdir/invalid-profiles-path" 2>&1; then
    printf '%s\n' 'Expected a relative profile path to fail template validation.' >&2
    exit 1
  fi
  grep -F 'path.profiles must be a home-relative path starting with ~/' "$tmpdir/invalid-profiles-path" >/dev/null
  grep -F '$(dirname "$(chezmoi source-path)")' "$tmpdir/aliases" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"editor":"code --wait","host":{}}' cat ~/.config/zsh/exports.zsh >"$tmpdir/exports"
  grep -F 'export OLLAMA_HOST="127.0.0.1:11434"' "$tmpdir/exports" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_TEST_DATA" cat ~/.config/zsh/functions.zsh >"$tmpdir/functions"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"accounts":null}' cat ~/.config/zsh/functions.zsh >"$tmpdir/functions-no-profiles"
  ! grep -E '^(profile-enabled|profile-git-config|profile-clear-environment|profile-clear-gh-environment|profile-use-gh|profile-use-vscode|profile-use-git|profile-use-cli|profile-use)\(\)' "$tmpdir/functions-no-profiles" >/dev/null
  mkdir -p "$tmpdir/profile-gh-home" "$tmpdir/profile-gh-bin"
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" "${GH_TOKEN-}" "${GH_CONFIG_DIR-}" "${GIT_CONFIG_PARAMETERS-}" "$*"' >"$tmpdir/profile-gh-bin/gh"
  chmod +x "$tmpdir/profile-gh-bin/gh"
  PATH="$tmpdir/profile-gh-bin:$PATH" HOME="$tmpdir/profile-gh-home" GH_TOKEN=shared-token zsh -c 'source "$1"; profile-use gh review auth status' _ "$tmpdir/functions" >"$tmpdir/profile-gh-auth"
  test -z "$(sed -n '1p' "$tmpdir/profile-gh-auth")"
  test "$(sed -n '2p' "$tmpdir/profile-gh-auth")" = "$tmpdir/profile-gh-home/.config/profiles/review/gh"
  grep -F "'user.name=Review User' 'user.email=review@example.test'" "$tmpdir/profile-gh-auth" >/dev/null
  grep -Fx 'auth status' "$tmpdir/profile-gh-auth" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" cat ~/.config/zsh/integrations.zsh >"$tmpdir/integrations"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"accounts":null}' cat ~/.config/zsh/integrations.zsh >"$tmpdir/integrations-no-profiles"
  grep -F 'vscode_profile="Review Profile"' "$tmpdir/functions" >/dev/null
  grep -F 'GH_CONFIG_DIR=$HOME/.config/profiles/review/gh' "$tmpdir/functions" >/dev/null
  grep -F 'GH_CONFIG_DIR=$HOME/.config/profiles/git_only/gh' "$tmpdir/functions" >/dev/null
  grep -F 'GH_CONFIG_DIR=$HOME/.config/profiles/vscode_only/gh' "$tmpdir/functions" >/dev/null
  grep -F 'CODEX_HOME=$HOME/.config/profiles/review/codex' "$tmpdir/functions" >/dev/null
  grep -F 'CODEX_HOME=$HOME/.config/profiles/default/codex' "$tmpdir/functions" >/dev/null
  grep -F 'git_config_parameters="${git_config_parameters}${git_config_parameters:+ }'\''user.name=Review User'\''"' "$tmpdir/functions" >/dev/null
  grep -F 'git_config_parameters="${git_config_parameters}${git_config_parameters:+ }'\''user.email=review@example.test'\''"' "$tmpdir/functions" >/dev/null
  GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_KEY_1=credential.helper GIT_CONFIG_VALUE_1=stale zsh -c 'source "$1"; profile-git-config review; test -z "${GIT_CONFIG_VALUE_0+x}"; test "$(git config user.name)" = "Review User"; test "$(git config user.email)" = "review@example.test"; git config --get-all credential.helper | grep -Fx "!gh auth git-credential" > /dev/null' _ "$tmpdir/functions"
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" "${GIT_CONFIG_PARAMETERS-}" "${GH_CONFIG_DIR-}" "${GH_TOKEN-}"' >"$tmpdir/profile-gh-bin/code"
  chmod +x "$tmpdir/profile-gh-bin/code"
  PATH="$tmpdir/profile-gh-bin:$PATH" HOME="$tmpdir/profile-gh-home" GH_CONFIG_DIR="$tmpdir/stale-gh-config" GH_TOKEN=stale-token zsh -c 'source "$1"; profile-use vscode git_only' _ "$tmpdir/functions" >"$tmpdir/profile-vscode-git-only"
  grep -F "'user.email=git-only@example.test'" "$tmpdir/profile-vscode-git-only" >/dev/null
  ! grep -F 'credential.helper' "$tmpdir/profile-vscode-git-only" >/dev/null
  test "$(sed -n '2p' "$tmpdir/profile-vscode-git-only")" = "$tmpdir/profile-gh-home/.config/profiles/git_only/gh"
  test -z "$(sed -n '3p' "$tmpdir/profile-vscode-git-only")"
  PATH="$tmpdir/profile-gh-bin:$PATH" HOME="$tmpdir/profile-gh-home" GH_CONFIG_DIR="$tmpdir/stale-gh-config" GH_TOKEN=stale-token zsh -c 'source "$1"; profile-use vscode vscode_only' _ "$tmpdir/functions" >"$tmpdir/profile-vscode-only"
  test "$(sed -n '2p' "$tmpdir/profile-vscode-only")" = "$tmpdir/profile-gh-home/.config/profiles/vscode_only/gh"
  test -z "$(sed -n '3p' "$tmpdir/profile-vscode-only")"
  PATH="$tmpdir/profile-gh-bin:$PATH" HOME="$tmpdir/profile-gh-home" GH_CONFIG_DIR="$tmpdir/stale-gh-config" GH_TOKEN=stale-token zsh -c 'source "$1"; profile-use vscode review' _ "$tmpdir/functions" >"$tmpdir/profile-vscode-review"
  test "$(sed -n '2p' "$tmpdir/profile-vscode-review")" = "$tmpdir/profile-gh-home/.config/profiles/review/gh"
  grep -F 'profile-clear-environment() {' "$tmpdir/functions" >/dev/null
  test "$(grep -F -c 'profile-clear-environment' "$tmpdir/functions")" -eq 2
  grep -F 'profile-clear-gh-environment() {' "$tmpdir/functions" >/dev/null
  test "$(grep -F -c 'profile-clear-gh-environment' "$tmpdir/functions")" -eq 4
  ! grep -F 'unset GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN' "$tmpdir/functions" >/dev/null
  grep -F 'profile-enabled() {' "$tmpdir/functions" >/dev/null
  ! grep -F 'ai-profile-enabled' "$tmpdir/functions" >/dev/null
  ! grep -F 'ai-use() {' "$tmpdir/functions" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "$PROFILE_TEST_DATA" execute-template --file home/.chezmoiscripts/run_onchange_setup-profiles.sh.tmpl >"$tmpdir/setup-profiles.sh"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"configDir":".local/profiles/review","profileDirectory":"~/.config/profiles/review","tools":["codex","gh","git"],"terminalEnvironmentPlatform":"linux","gitIdentity":{"name":"Review User","email":"review@example.test"}}' execute-template --file home/.chezmoitemplates/Code/settings-profile.json >"$tmpdir/vscode-profile-settings.json"
  python3 -c 'import json,sys; settings=json.load(open(sys.argv[1])); assert settings["chat.instructionsFilesLocations"] == {".github/instructions":True,".claude/rules":True,"~/.local/profiles/review/copilot":True,"~/.local/profiles/review/claude":True}; env=settings["terminal.integrated.env.linux"]; assert env["CODEX_HOME"] == "~/.config/profiles/review/codex" and env["GH_CONFIG_DIR"] == "~/.config/profiles/review/gh"; assert env["GIT_CONFIG_COUNT"] == "4" and env["GIT_CONFIG_VALUE_2"] == "Review User" and env["GIT_CONFIG_VALUE_3"] == "review@example.test"; assert env["GH_TOKEN"] is None and env["GIT_CONFIG_PARAMETERS"] is None' "$tmpdir/vscode-profile-settings.json"
  profile_setup_checksum=$(python3 -c 'import hashlib,pathlib; print(hashlib.sha256(pathlib.Path("scripts/configure-vscode-profiles.py").read_bytes()).hexdigest())')
  grep -F "# VS Code profile setup checksum: $profile_setup_checksum" "$tmpdir/setup-profiles.sh" >/dev/null
}

check_platforms() {
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" execute-template --file home/.chezmoiscripts/darwin/run_onchange_before_install-packages.sh.tmpl >"$tmpdir/darwin-packages.sh"
  test ! -e home/.chezmoidata/.gitignore
  git check-ignore -q home/.chezmoidata/99-local.yaml
  ! git check-ignore -q home/.chezmoidata/00-defaults.yaml
  ! git check-ignore -q home/.chezmoidata/packages.yaml
  ! grep -Fx '        - chezmoi' home/.chezmoidata/packages.yaml >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" execute-template --file home/dot_config/mise/config.toml.tmpl >"$tmpdir/mise-config.toml"
  grep -Fx 'atuin = "latest"' "$tmpdir/mise-config.toml" >/dev/null
  grep -Fx 'starship = "latest"' "$tmpdir/mise-config.toml" >/dev/null
  grep -F '"npm:@openai/codex" = "latest"' "$tmpdir/mise-config.toml" >/dev/null
  grep -F 'https://ollama.com/install.sh' home/.chezmoidata/packages.yaml >/dev/null
  grep -F '        - ollama' home/.chezmoidata/packages.yaml >/dev/null
  grep -F '      - Ollama.Ollama' home/.chezmoidata/packages.yaml >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"linux"}}' execute-template --file home/.chezmoiscripts/linux/run_onchange_before_install-packages.sh.tmpl >"$tmpdir/linux-packages.sh"
  sh -n "$tmpdir/linux-packages.sh"
  grep -F 'apt-get install -y ca-certificates curl git gnupg neovim zsh' "$tmpdir/linux-packages.sh" >/dev/null
  grep -F 'pacman -S --needed --noconfirm' "$tmpdir/linux-packages.sh" >/dev/null
  grep -F 'https://ollama.com/install.sh' "$tmpdir/linux-packages.sh" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file home/.chezmoiscripts/windows/run_onchange_before_install-packages.ps1.tmpl >"$tmpdir/windows-packages.ps1"
  test -s "$tmpdir/windows-packages.ps1"
  grep -F "'jdx.mise'" "$tmpdir/windows-packages.ps1" >/dev/null
  grep -F "'Ollama.Ollama'" "$tmpdir/windows-packages.ps1" >/dev/null
  grep -F "'Microsoft.VisualStudioCode'" "$tmpdir/windows-packages.ps1" >/dev/null
  grep -F "'Obsidian.Obsidian'" "$tmpdir/windows-packages.ps1" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file home/.chezmoiscripts/windows/run_onchange_after_install-mise-tools.ps1.tmpl >"$tmpdir/windows-mise-tools.ps1"
  grep -F 'exec bun --' "$tmpdir/windows-mise-tools.ps1" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file home/.chezmoiscripts/windows/run_onchange_before_install-zsh.ps1.tmpl >"$tmpdir/windows-zsh.ps1"
  grep -F "'zsh,git,curl'" "$tmpdir/windows-zsh.ps1" >/dev/null
  grep -F 'db_shell' "$tmpdir/windows-zsh.ps1" >/dev/null
  grep -F '/bin/zsh' "$tmpdir/windows-zsh.ps1" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"linux"}}' execute-template --file home/.chezmoiscripts/windows/run_onchange_before_install-zsh.ps1.tmpl >"$tmpdir/non-windows-zsh.ps1"
  test ! -s "$tmpdir/non-windows-zsh.ps1"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file home/.chezmoiscripts/windows/run_onchange_after_install-oh-my-zsh.ps1.tmpl >"$tmpdir/windows-oh-my-zsh.ps1"
  grep -F 'https://install.ohmyz.sh/' "$tmpdir/windows-oh-my-zsh.ps1" >/dev/null
  grep -F -- '--unattended' "$tmpdir/windows-oh-my-zsh.ps1" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"linux"}}' execute-template --file home/.chezmoiscripts/windows/run_onchange_after_install-oh-my-zsh.ps1.tmpl >"$tmpdir/non-windows-oh-my-zsh.ps1"
  test ! -s "$tmpdir/non-windows-oh-my-zsh.ps1"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file home/.chezmoiscripts/run_onchange_after_install-mise-tools.sh.tmpl >"$tmpdir/windows-mise-tools.sh"
  test ! -s "$tmpdir/windows-mise-tools.sh"
  if command -v pwsh >/dev/null 2>&1; then
    for powershell_file in \
      "$tmpdir/windows-packages.ps1" \
      "$tmpdir/windows-mise-tools.ps1" \
      "$tmpdir/windows-zsh.ps1" \
      "$tmpdir/windows-oh-my-zsh.ps1"; do
      CHEZMOI_CHECK_FILE="$powershell_file" pwsh -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile($env:CHEZMOI_CHECK_FILE, [ref]$tokens, [ref]$errors) > $null; if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }'
    done
  fi
  for os in linux darwin windows; do
    "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "{\"chezmoi\":{\"os\":\"$os\"}}" execute-template --file home/.chezmoiscripts/linux/run_after_sync-vscode-wsl-settings.sh.tmpl >"$tmpdir/vscode-wsl-settings-$os.sh"
  done
  test -s "$tmpdir/vscode-wsl-settings-linux.sh"
  test ! -s "$tmpdir/vscode-wsl-settings-darwin.sh"
  test ! -s "$tmpdir/vscode-wsl-settings-windows.sh"
  sh -n "$tmpdir/vscode-wsl-settings-linux.sh"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"windows"}}' execute-template --file home/.chezmoiignore.tmpl >"$tmpdir/ignore-windows"
  grep -Fx '.config/ghostty/' "$tmpdir/ignore-windows" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"chezmoi":{"os":"linux"}}' execute-template --file home/.chezmoiignore.tmpl >"$tmpdir/ignore-linux"
  ! grep -Fx '.config/ghostty/' "$tmpdir/ignore-linux" >/dev/null
  if [ -s "$tmpdir/darwin-packages.sh" ]; then
    sh -n "$tmpdir/darwin-packages.sh"
    grep -Fx 'brew cleanup --prune=all' "$tmpdir/darwin-packages.sh" >/dev/null
    grep -Fx 'brew "ollama"' "$tmpdir/darwin-packages.sh" >/dev/null
    ! grep -F 'brew services start ollama' "$tmpdir/darwin-packages.sh" >/dev/null
  fi
  grep -F '/.config/profiles"' "$tmpdir/setup-profiles.sh" >/dev/null
  ! grep -F 'code --profile' "$tmpdir/setup-profiles.sh" >/dev/null
  grep -F "create_profile gh 'review'" "$tmpdir/setup-profiles.sh" >/dev/null
}

check_ssh_keys() {
  mkdir -p "$tmpdir/ssh-keygen-bin" "$tmpdir/ssh-key-home"
  mkdir -p "$tmpdir/ssh-key-source/home/.chezmoiscripts"
  printf '%s\n' home >"$tmpdir/ssh-key-source/.chezmoiroot"
  cp home/.chezmoiscripts/run_onchange_before_generate-ssh-keys.sh.tmpl "$tmpdir/ssh-key-source/home/.chezmoiscripts/"
  cat >"$tmpdir/ssh-keygen-bin/ssh-keygen" <<'SH'
#!/bin/sh
set -eu
if [ "${SSH_KEYGEN_SHOULD_NOT_RUN:-0}" = 1 ]; then
  printf '%s\n' 'ssh-keygen was called for an existing key.' >&2
  exit 1
fi
key_path=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -f) key_path=$2; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$key_path" ]
printf '%s\n' 'test private key' >"$key_path"
printf '%s\n' 'test public key' >"$key_path.pub"
SH
  chmod +x "$tmpdir/ssh-keygen-bin/ssh-keygen"
"$CHEZMOI" --source "$tmpdir/ssh-key-source" --config "$tmpdir/chezmoi.toml" --destination "$tmpdir/ssh-key-home" --override-data '{"ssh":{"gh":{"accounts":[{"username":"fixture-root","sshKey":"~/.ssh/signing"},{"username":"fixture-profile","sshKey":"~/.ssh/profile"}]}}}' execute-template --file home/.chezmoiscripts/run_onchange_before_generate-ssh-keys.sh.tmpl >"$tmpdir/ssh-keys-enabled.sh"
"$CHEZMOI" --source "$tmpdir/ssh-key-source" --config "$tmpdir/chezmoi.toml" --destination "$tmpdir/ssh-key-home" --override-data '{"ssh":{"gh":{"accounts":[]}}}' execute-template --file home/.chezmoiscripts/run_onchange_before_generate-ssh-keys.sh.tmpl >"$tmpdir/ssh-keys-disabled.sh"
grep -F '# SSH key paths and file state checksum:' "$tmpdir/ssh-keys-enabled.sh" >"$tmpdir/ssh-keys-enabled-checksum"
grep -F '# SSH key paths and file state checksum:' "$tmpdir/ssh-keys-disabled.sh" >"$tmpdir/ssh-keys-disabled-checksum"
  ! cmp -s "$tmpdir/ssh-keys-enabled-checksum" "$tmpdir/ssh-keys-disabled-checksum"
"$CHEZMOI" --source "$tmpdir/ssh-key-source" --config "$tmpdir/chezmoi.toml" --destination "$tmpdir/ssh-key-home" --override-data '{"ssh":{"gh":{"accounts":[{"username":"fixture-root","sshKey":"~/.ssh/signing"},{"username":"fixture-profile","sshKey":"~/.ssh/profile"}]}}}' execute-template --file home/.chezmoiscripts/run_onchange_before_generate-ssh-keys.sh.tmpl >"$tmpdir/ssh-keys-override-enabled.sh"
grep -F '# SSH key paths and file state checksum:' "$tmpdir/ssh-keys-override-enabled.sh" >"$tmpdir/ssh-keys-override-enabled-checksum"
  cmp -s "$tmpdir/ssh-keys-enabled-checksum" "$tmpdir/ssh-keys-override-enabled-checksum"
  sh -n "$tmpdir/ssh-keys-enabled.sh"
test "$(head -n 1 "$tmpdir/ssh-keys-enabled.sh")" = '#!/bin/sh'
  HOME="$tmpdir/ssh-key-home" PATH="$tmpdir/ssh-keygen-bin:$PATH" sh "$tmpdir/ssh-keys-enabled.sh"
  test -f "$tmpdir/ssh-key-home/.ssh/signing"
  test -f "$tmpdir/ssh-key-home/.ssh/signing.pub"
test -f "$tmpdir/ssh-key-home/.ssh/profile"
test -f "$tmpdir/ssh-key-home/.ssh/profile.pub"
"$CHEZMOI" --source "$tmpdir/ssh-key-source" --config "$tmpdir/chezmoi.toml" --destination "$tmpdir/ssh-key-home" --override-data '{"ssh":{"gh":{"accounts":[{"username":"fixture-root","sshKey":"~/.ssh/signing"},{"username":"fixture-profile","sshKey":"~/.ssh/profile"}]}}}' execute-template --file home/.chezmoiscripts/run_onchange_before_generate-ssh-keys.sh.tmpl >"$tmpdir/ssh-keys-existing.sh"
grep -F '# SSH key paths and file state checksum:' "$tmpdir/ssh-keys-existing.sh" >"$tmpdir/ssh-keys-existing-checksum"
! cmp -s "$tmpdir/ssh-keys-enabled-checksum" "$tmpdir/ssh-keys-existing-checksum"
SSH_KEYGEN_SHOULD_NOT_RUN=1 HOME="$tmpdir/ssh-key-home" PATH="$tmpdir/ssh-keygen-bin:$PATH" sh "$tmpdir/ssh-keys-existing.sh"
}

check_init_ssh_config() {
  mkdir -p "$tmpdir/ssh-config-source/home/.chezmoidata"
  printf '%s\n' home >"$tmpdir/ssh-config-source/.chezmoiroot"
  cp home/.chezmoi.yaml.tmpl "$tmpdir/ssh-config-source/home/"
  cp home/.chezmoidata/00-defaults.yaml "$tmpdir/ssh-config-source/home/.chezmoidata/"
  copy_accounts_template "$tmpdir/ssh-config-source"
  cat >"$tmpdir/ssh-config-source/home/.chezmoidata/99-local.yaml" <<'YAML'
name: Fixture User
email: fixture@example.test
git:
  gpgsign: false
gh:
  username: fixture-root
  gpgsign: true
accounts:
  - id: explicit
    email: explicit@example.test
    git:
      email: explicit-git@example.test
      gpgsign: true
    gh:
      username: explicit
      gpgsign: true
      sshKey: ~/.custom/id_explicit
      signingKey: ~/.custom/id_explicit.pub
  - id: generated
    email: generated@example.test
    git:
      gpgsign: true
    gh:
      username: generated
  - id: custom_key
    email: custom-key@example.test
    git:
      gpgsign: true
    gh:
      username: custom-key
      gpgsign: true
      sshKey: ~/.custom/id_custom
  - id: custom_signing
    email: custom-signing@example.test
    git:
      gpgsign: true
    gh:
      username: custom-signing
      gpgsign: true
      signingKey: ~/.custom/id_custom_signing.pub
  - id: disabled
    git:
      gpgsign: true
    gh:
      username: disabled
      gpgsign: false
  - id: without_gh
    tools: [git]
YAML
  "$CHEZMOI" --source "$tmpdir/ssh-config-source" --config "$tmpdir/chezmoi.toml" execute-template --init --file home/.chezmoi.yaml.tmpl >"$tmpdir/ssh-config.yaml"
  "$CHEZMOI" --source "$tmpdir/ssh-config-source" --config "$tmpdir/ssh-config.yaml" data --format=json >"$tmpdir/ssh-config-data.json"
  python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); accounts={item["username"]:item for item in data["ssh"]["gh"]["accounts"]}; assert set(accounts) == {"fixture-root","explicit","generated","custom-key","custom-signing"}; assert accounts["fixture-root"]["isRoot"] is True; assert all(item["isRoot"] is False for name,item in accounts.items() if name != "fixture-root"); assert accounts["fixture-root"]["email"] == "fixture@example.test"; assert accounts["explicit"]["email"] == "explicit-git@example.test"; assert accounts["generated"]["email"] == "generated@example.test"; assert accounts["custom-key"]["email"] == "custom-key@example.test"; assert accounts["custom-signing"]["email"] == "custom-signing@example.test"; assert accounts["fixture-root"]["sshKey"] == "~/.config/gh/ssh/id_ed25519_github_fixture-root" and accounts["fixture-root"]["signingKey"] == "~/.config/gh/ssh/id_ed25519_github_fixture-root.pub"; assert accounts["explicit"]["sshKey"] == "~/.custom/id_explicit" and accounts["explicit"]["signingKey"] == "~/.custom/id_explicit.pub"; assert accounts["generated"]["sshKey"] == "~/.config/gh/ssh/id_ed25519_github_generated" and accounts["generated"]["signingKey"] == "~/.config/gh/ssh/id_ed25519_github_generated.pub"; assert accounts["custom-key"]["sshKey"] == "~/.custom/id_custom" and accounts["custom-key"]["signingKey"] == "~/.custom/id_custom.pub"; assert accounts["custom-signing"]["sshKey"] == "~/.config/gh/ssh/id_ed25519_github_custom-signing" and accounts["custom-signing"]["signingKey"] == "~/.custom/id_custom_signing.pub"' "$tmpdir/ssh-config-data.json"
  python3 -c 'import json,sys; gh=json.load(open(sys.argv[1]))["ssh"]["gh"]; assert gh["path"] == "~/.config/gh/ssh/" and gh["signer"] == "~/.config/gh/ssh/allowed_signer"' "$tmpdir/ssh-config-data.json"
  mkdir -p "$tmpdir/ssh-config-source/home/dot_config/private_gh/private_ssh"
  cp home/dot_config/private_gh/private_ssh/private_config.tmpl "$tmpdir/ssh-config-source/home/dot_config/private_gh/private_ssh/private_config.tmpl"
  "$CHEZMOI" --source "$tmpdir/ssh-config-source" --config "$tmpdir/ssh-config.yaml" execute-template --file home/dot_config/private_gh/private_ssh/private_config.tmpl >"$tmpdir/ssh-config-rendered"
  grep -Fx 'Host github.com' "$tmpdir/ssh-config-rendered" >/dev/null
  grep -F 'IdentityFile ~/.config/gh/ssh/id_ed25519_github_fixture-root' "$tmpdir/ssh-config-rendered" >/dev/null
  grep -Fx 'Host github.com-explicit' "$tmpdir/ssh-config-rendered" >/dev/null
  grep -F 'IdentityFile ~/.custom/id_explicit' "$tmpdir/ssh-config-rendered" >/dev/null
  grep -Fx 'Host github.com-generated' "$tmpdir/ssh-config-rendered" >/dev/null
  grep -F 'IdentityFile ~/.config/gh/ssh/id_ed25519_github_generated' "$tmpdir/ssh-config-rendered" >/dev/null
  grep -Fx 'Host github.com-custom-key' "$tmpdir/ssh-config-rendered" >/dev/null
  mkdir -p "$tmpdir/ssh-public"
  printf '%s\n' 'ssh-ed25519 fixture-root' >"$tmpdir/ssh-public/root.pub"
  printf '%s\n' 'ssh-ed25519 fixture-explicit' >"$tmpdir/ssh-public/explicit.pub"
  printf '%s\n' 'ssh-ed25519 fixture-generated' >"$tmpdir/ssh-public/generated.pub"
  printf '%s\n' 'ssh-ed25519 fixture-custom-key' >"$tmpdir/ssh-public/custom-key.pub"
  printf '%s\n' 'ssh-ed25519 fixture-custom-signing' >"$tmpdir/ssh-public/custom-signing.pub"
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data "{\"ssh\":{\"gh\":{\"accounts\":[{\"email\":\"fixture@example.test\",\"signingKey\":\"$tmpdir/ssh-public/root.pub\"},{\"email\":\"explicit-git@example.test\",\"signingKey\":\"$tmpdir/ssh-public/explicit.pub\"},{\"email\":\"generated@example.test\",\"signingKey\":\"$tmpdir/ssh-public/generated.pub\"},{\"email\":\"custom-key@example.test\",\"signingKey\":\"$tmpdir/ssh-public/custom-key.pub\"},{\"email\":\"custom-signing@example.test\",\"signingKey\":\"$tmpdir/ssh-public/custom-signing.pub\"}]}}}" execute-template --file home/dot_config/private_gh/private_ssh/private_allowed_signer.tmpl >"$tmpdir/ssh-allowed-signers"
  grep -Fx 'fixture@example.test ssh-ed25519 fixture-root' "$tmpdir/ssh-allowed-signers" >/dev/null
  grep -Fx 'explicit-git@example.test ssh-ed25519 fixture-explicit' "$tmpdir/ssh-allowed-signers" >/dev/null
  grep -Fx 'generated@example.test ssh-ed25519 fixture-generated' "$tmpdir/ssh-allowed-signers" >/dev/null
  grep -Fx 'custom-key@example.test ssh-ed25519 fixture-custom-key' "$tmpdir/ssh-allowed-signers" >/dev/null
  grep -Fx 'custom-signing@example.test ssh-ed25519 fixture-custom-signing' "$tmpdir/ssh-allowed-signers" >/dev/null

  mkdir -p "$tmpdir/ssh-config-disabled-source/home/.chezmoidata"
  printf '%s\n' home >"$tmpdir/ssh-config-disabled-source/.chezmoiroot"
  cp home/.chezmoi.yaml.tmpl "$tmpdir/ssh-config-disabled-source/home/"
  copy_accounts_template "$tmpdir/ssh-config-disabled-source"
  cat >"$tmpdir/ssh-config-disabled-source/home/.chezmoidata/99-local.yaml" <<'YAML'
name: Fixture User
email: fixture@example.test
git:
  gpgsign: true
gh:
  gpgsign: false
accounts:
  disabled:
    git:
      gpgsign: true
    gh:
      username: disabled
      gpgsign: false
YAML
  "$CHEZMOI" --source "$tmpdir/ssh-config-disabled-source" --config "$tmpdir/chezmoi.toml" execute-template --init --file home/.chezmoi.yaml.tmpl >"$tmpdir/ssh-config-disabled.yaml"
  "$CHEZMOI" --source "$tmpdir/ssh-config-disabled-source" --config "$tmpdir/ssh-config-disabled.yaml" data --format=json >"$tmpdir/ssh-config-disabled-data.json"
  python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert "ssh" not in data' "$tmpdir/ssh-config-disabled-data.json"
}

check_profile_state() {
  mkdir -p "$tmpdir/profile-cleanup-home/.config/gh" "$tmpdir/profile-cleanup-home/.config/profiles/review/gh" "$tmpdir/profile-cleanup-home/.config/profiles/git_only/gh"
  touch "$tmpdir/profile-cleanup-home/.config/gh/config.yml"
  ln -s "$tmpdir/profile-cleanup-home/.config/gh/config.yml" "$tmpdir/profile-cleanup-home/.config/profiles/review/gh/config.yml"
  mkdir -p "$tmpdir/profile-cleanup-home/.config/profiles/default/codex" "$tmpdir/profile-cleanup-home/.config/profiles/review/codex"
  cat >"$tmpdir/profile-cleanup-home/.config/profiles/default/codex/config.toml" <<'EOF'
cli_auth_credentials_store = "file"

[tui]
notifications = true
EOF
  cat >"$tmpdir/profile-cleanup-home/.config/profiles/review/codex/config.toml" <<'EOF'
cli_auth_credentials_store = "file"

[projects."/workspace/review"]
trust_level = "trusted"
EOF
  printf '%s\n' 'preserve custom account data' >"$tmpdir/profile-cleanup-home/.config/profiles/git_only/gh/hosts.yml"
  mkdir -p "$tmpdir/vscode-profile-storage/User/globalStorage" "$tmpdir/vscode-profile-storage/User/profiles/existing-review"
  printf '%s\n' '{"sentinel":"preserve","userDataProfiles":[{"name":"Review Profile","location":"existing-review","useDefaultFlags":{"settings":true,"extensions":true}},{"name":"Unmanaged","location":"existing-unmanaged"}]}' >"$tmpdir/vscode-profile-storage/User/globalStorage/storage.json"
  printf '%s\n' '{"editor.formatOnSave":true,"git.autofetch":true,"chat.instructionsFilesLocations":{".github/instructions":true,".claude/rules":true,"~/.copilot/instructions":true,"~/.claude/rules":true}}' >"$tmpdir/vscode-profile-storage/User/settings.json"
  cat >"$tmpdir/vscode-profile-storage/User/profiles/existing-review/settings.json" <<'EOF'
{
  // VS Code settings allow comments and trailing commas.
  "custom.profileSetting": true,
  "custom.url": "https://example.test/path//value",
  /* Keep comment markers in strings intact. */
  "custom.commentMarkers": "/* value */",
  "chat.instructionsFilesLocations": {"old/location": true,},
  "terminal.integrated.env.linux": {
    "CUSTOM_TERMINAL_VALUE": "retained",
    "CODEX_HOME": "old-profile",
  },
}
EOF
  mkdir -p "$tmpdir/vscode-bin"
  printf '%s\n' '#!/bin/sh' 'if [ "$1" = --version ]; then printf "%s\\n" "${CHEZMOI_VSCODE_TEST_VERSION:-1.115.0}"; exit 0; fi' 'printf "%s\\n" "$*" >> "$CHEZMOI_VSCODE_TEST_LOG"' >"$tmpdir/vscode-bin/code"
  chmod +x "$tmpdir/vscode-bin/code"
  HOME="$tmpdir/profile-cleanup-home" CHEZMOI_PROFILE_SETUP_TESTING=1 CHEZMOI_VSCODE_PROFILE_STORAGE_PATH="$tmpdir/vscode-profile-storage/User/globalStorage/storage.json" CHEZMOI_VSCODE_CLI="$tmpdir/vscode-bin/code" CHEZMOI_VSCODE_TEST_LOG="$tmpdir/vscode-install.log" sh "$tmpdir/setup-profiles.sh"
  python3 - "$tmpdir/vscode-profile-storage/User/profiles/existing-review/settings.json" "$tmpdir/profile-cleanup-home" <<'PY'
import json
import os
import subprocess
import sys

settings = json.loads(open(sys.argv[1], encoding="utf-8").read())
profile_home = sys.argv[2]
terminal_settings = [
    key
    for key, value in settings.items()
    if key.startswith("terminal.integrated.env.")
    and value.get("CODEX_HOME") == f"{profile_home}/.config/profiles/review/codex"
]
assert len(terminal_settings) == 1
terminal_setting = terminal_settings[0]
environment = settings[terminal_setting]
assert environment["CODEX_HOME"] == f"{profile_home}/.config/profiles/review/codex"
assert environment["GH_CONFIG_DIR"] == f"{profile_home}/.config/profiles/review/gh"
assert environment["GH_TOKEN"] is None
assert environment["GITHUB_TOKEN"] is None
assert environment["GIT_CONFIG_PARAMETERS"] is None
assert environment["GIT_CONFIG_COUNT"] == "4"
assert environment["GIT_CONFIG_KEY_0"] == "credential.helper"
assert environment["GIT_CONFIG_VALUE_0"] == ""
assert environment["GIT_CONFIG_KEY_1"] == "credential.helper"
assert environment["GIT_CONFIG_VALUE_1"] == "!gh auth git-credential"
assert environment["GIT_CONFIG_KEY_2"] == "user.name"
assert environment["GIT_CONFIG_VALUE_2"] == "Review User"
assert environment["GIT_CONFIG_KEY_3"] == "user.email"
assert environment["GIT_CONFIG_VALUE_3"] == "review@example.test"
process_environment = os.environ.copy()
for key, value in environment.items():
    if value is None:
        process_environment.pop(key, None)
    else:
        process_environment[key] = value
assert subprocess.run(
    ["git", "config", "user.name"], check=True, capture_output=True, text=True, env=process_environment
).stdout.strip() == "Review User"
credential_helpers = subprocess.run(
    ["git", "config", "--get-all", "credential.helper"],
    check=True,
    capture_output=True,
    text=True,
    env=process_environment,
).stdout.splitlines()
assert credential_helpers[-2:] == ["", "!gh auth git-credential"]
PY
  test -L "$tmpdir/profile-cleanup-home/.config/profiles/review/gh/config.yml"
  test "$(readlink "$tmpdir/profile-cleanup-home/.config/profiles/review/gh/config.yml")" = "$tmpdir/profile-cleanup-home/.config/gh/config.yml"
  test -L "$tmpdir/profile-cleanup-home/.config/profiles/git_only/gh/config.yml"
  test -L "$tmpdir/profile-cleanup-home/.config/profiles/vscode_only/gh/config.yml"
  grep -Fx 'preserve custom account data' "$tmpdir/profile-cleanup-home/.config/profiles/git_only/gh/hosts.yml" >/dev/null
  test -L "$tmpdir/profile-cleanup-home/.config/profiles/default/codex/config.toml"
  test -L "$tmpdir/profile-cleanup-home/.config/profiles/review/codex/config.toml"
  test "$(readlink "$tmpdir/profile-cleanup-home/.config/profiles/review/codex/config.toml")" = "$tmpdir/profile-cleanup-home/.config/codex/config.toml"
  python3 - "$tmpdir/profile-cleanup-home/.config/codex/config.toml" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config_file:
    config = tomllib.load(config_file)
assert config["cli_auth_credentials_store"] == "file"
assert config["tui"]["notifications"] is True
assert config["projects"]["/workspace/review"]["trust_level"] == "trusted"
PY
  HOME="$tmpdir/profile-cleanup-home" CHEZMOI_PROFILES_DIR="$tmpdir/profile-cleanup-home/.config/profiles" python3 "$CHEZMOI_SOURCE/scripts/share-codex-config.py" <<'EOF'
["default", "review"]
EOF
  mkdir -p "$tmpdir/codex-conflict-home/.config/codex" "$tmpdir/codex-conflict-home/.config/profiles/conflict/codex"
  printf '%s\n' 'model = "common-model"' 'cli_auth_credentials_store = "file"' >"$tmpdir/codex-conflict-home/.config/codex/config.toml"
  printf '%s\n' 'model = "profile-model"' 'cli_auth_credentials_store = "file"' >"$tmpdir/codex-conflict-home/.config/profiles/conflict/codex/config.toml"
  if HOME="$tmpdir/codex-conflict-home" CHEZMOI_PROFILES_DIR="$tmpdir/codex-conflict-home/.config/profiles" python3 "$CHEZMOI_SOURCE/scripts/share-codex-config.py" <<'EOF' >"$tmpdir/codex-conflict.log" 2>&1
["conflict"]
EOF
  then
    exit 1
  fi
  ! grep -F 'conflicting settings' "$tmpdir/codex-conflict.log" >/dev/null
  test ! -L "$tmpdir/codex-conflict-home/.config/profiles/conflict/codex/config.toml"
  grep -Fx 'model = "common-model"' "$tmpdir/codex-conflict-home/.config/codex/config.toml" >/dev/null
  grep -Fx 'model = "profile-model"' "$tmpdir/codex-conflict-home/.config/profiles/conflict/codex/config.toml" >/dev/null
  grep -Fx -- '--install-extension GitHub.copilot --profile Review Profile' "$tmpdir/vscode-install.log" >/dev/null
  grep -Fx -- '--install-extension GitHub.copilot-chat --profile git_only' "$tmpdir/vscode-install.log" >/dev/null
  grep -Fx -- '--install-extension GitHub.copilot' "$tmpdir/vscode-install.log" >/dev/null
  cat <<'EOF' | HOME="$tmpdir/profile-cleanup-home" CHEZMOI_PROFILE_SETUP_TESTING=1 CHEZMOI_VSCODE_PROFILE_STORAGE_PATH="$tmpdir/vscode-profile-storage/User/globalStorage/storage.json" CHEZMOI_VSCODE_CLI="$tmpdir/vscode-bin/code" CHEZMOI_VSCODE_TEST_VERSION=1.145.0 CHEZMOI_VSCODE_TEST_LOG="$tmpdir/vscode-builtin-install.log" python3 "$CHEZMOI_SOURCE/scripts/configure-vscode-profiles.py"
[
  {
    "id": "review",
    "name": "Review Profile",
    "settings": {
      "chat.instructionsFilesLocations": {
        ".github/instructions": true,
        ".claude/rules": true,
        "~/.config/profiles/review/copilot": true,
        "~/.config/profiles/review/claude": true
      },
      "terminal.integrated.env.linux": {
        "CODEX_HOME": "~/.config/profiles/review/codex",
        "CLAUDE_CONFIG_DIR": null,
        "COPILOT_HOME": null,
        "GEMINI_CLI_HOME": null,
        "GH_CONFIG_DIR": "~/.config/profiles/review/gh",
        "GIT_CONFIG_COUNT": "4",
        "GIT_CONFIG_KEY_0": "credential.helper",
        "GIT_CONFIG_VALUE_0": "",
        "GIT_CONFIG_KEY_1": "credential.helper",
        "GIT_CONFIG_VALUE_1": "!gh auth git-credential",
        "GIT_CONFIG_KEY_2": "user.name",
        "GIT_CONFIG_VALUE_2": "Review User",
        "GIT_CONFIG_KEY_3": "user.email",
        "GIT_CONFIG_VALUE_3": "review@example.test",
        "GIT_CONFIG_PARAMETERS": null,
        "GH_TOKEN": null,
        "GITHUB_TOKEN": null,
        "GH_ENTERPRISE_TOKEN": null,
        "GITHUB_ENTERPRISE_TOKEN": null
      }
    }
  },
  {
    "id": "new-profile",
    "name": "New Profile",
    "settings": {
      "chat.instructionsFilesLocations": {
        ".github/instructions": true,
        ".claude/rules": true,
        "~/.config/profiles/new-profile/copilot": true,
        "~/.config/profiles/new-profile/claude": true
      },
      "terminal.integrated.env.windows": {
        "CODEX_HOME": null,
        "CLAUDE_CONFIG_DIR": "~/.config/profiles/new-profile/claude",
        "COPILOT_HOME": "~/.config/profiles/new-profile/copilot",
        "GEMINI_CLI_HOME": "~/.config/profiles/new-profile/gemini",
        "GH_CONFIG_DIR": null,
        "GIT_CONFIG_COUNT": null,
        "GIT_CONFIG_PARAMETERS": null,
        "GH_TOKEN": null,
        "GITHUB_TOKEN": null,
        "GH_ENTERPRISE_TOKEN": null,
        "GITHUB_ENTERPRISE_TOKEN": null
      }
    }
  }
]
EOF
  test ! -s "$tmpdir/vscode-builtin-install.log"
  python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); profiles=data["userDataProfiles"]; assert data["sentinel"] == "preserve"; assert any(p["name"] == "Unmanaged" for p in profiles); assert any(p["name"] == "git_only" for p in profiles); assert not any(p["name"] == "Default" for p in profiles); expected_shared=("keybindings","tasks","mcp","snippets","prompts","languageModels"); for_profile=lambda p: p["useDefaultFlags"]; review=next(p for p in profiles if p["name"] == "Review Profile"); new=next(p for p in profiles if p["name"] == "New Profile"); assert review["useDefaultFlags"]["settings"] is False and new["useDefaultFlags"]["settings"] is False; assert all(for_profile(p)[key] is True for p in (review,new) for key in expected_shared); assert all(for_profile(p)["extensions"] is False for p in (review,new))' "$tmpdir/vscode-profile-storage/User/globalStorage/storage.json"
  python3 - "$tmpdir/vscode-profile-storage/User/profiles/existing-review/settings.json" <<'PY'
import json
import sys

settings = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert settings["custom.profileSetting"] is True
assert settings["custom.url"] == "https://example.test/path//value"
assert settings["custom.commentMarkers"] == "/* value */"
assert settings["chat.instructionsFilesLocations"]["old/location"] is True
assert settings["chat.instructionsFilesLocations"]["~/.config/profiles/review/copilot"] is True
environment = settings["terminal.integrated.env.linux"]
assert environment["CUSTOM_TERMINAL_VALUE"] == "retained"
assert environment["CODEX_HOME"].endswith("/.config/profiles/review/codex")
assert environment["GH_CONFIG_DIR"].endswith("/.config/profiles/review/gh")
assert environment["GIT_CONFIG_VALUE_2"] == "Review User"
assert environment["GIT_CONFIG_VALUE_3"] == "review@example.test"
PY
  python3 - "$tmpdir/vscode-profile-storage/User/profiles/chezmoi-new-profile/settings.json" <<'PY'
import json
import sys

settings = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert settings["chat.instructionsFilesLocations"]["~/.config/profiles/new-profile/copilot"] is True
environment = settings["terminal.integrated.env.windows"]
assert environment["CLAUDE_CONFIG_DIR"].endswith("/.config/profiles/new-profile/claude")
assert environment["COPILOT_HOME"].endswith("/.config/profiles/new-profile/copilot")
assert environment["GEMINI_CLI_HOME"].endswith("/.config/profiles/new-profile/gemini")
assert environment["CODEX_HOME"] is None
assert environment["GH_CONFIG_DIR"] is None
assert environment["GIT_CONFIG_COUNT"] is None
PY
  python3 - "$CHEZMOI_SOURCE/scripts/configure-vscode-profiles.py" "$tmpdir" <<'PY'
import importlib.util
import os
import pathlib
import sys
from unittest import mock

script, temp = sys.argv[1:]
spec = importlib.util.spec_from_file_location("configure_vscode_profiles", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# Portable installs keep their user data beside the CLI.
portable = pathlib.Path(temp) / "portable"
(portable / "bin").mkdir(parents=True)
(portable / "data" / "user-data").mkdir(parents=True)
cli = portable / "bin" / "code"
cli.touch()
assert module.storage_path(str(cli)) == (
    portable.resolve() / "data" / "user-data" / "User" / "globalStorage" / "storage.json"
)

# WSL launching Windows VS Code must use Windows APPDATA, converted to WSL form.
windows_cli = "/mnt/c/Program Files/Microsoft VS Code/bin/code"
appdata = pathlib.Path(temp) / "windows-appdata"
with mock.patch.object(module, "is_wsl", return_value=True), mock.patch.object(
    module, "windows_appdata_from_wsl", return_value=appdata
), mock.patch.dict(os.environ, {"CHEZMOI_VSCODE_VARIANT": "insiders"}):
    assert module.storage_path(windows_cli) == (
        appdata / "Code - Insiders" / "User" / "globalStorage" / "storage.json"
    )

# Native Linux stable and OSS variants honor XDG_CONFIG_HOME.
config_home = pathlib.Path(temp) / "xdg"
with mock.patch.object(module, "is_wsl", return_value=False), mock.patch.object(
    module.sys, "platform", "linux"
), mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(config_home)}, clear=False):
    assert module.storage_path("/usr/bin/code") == (
        config_home / "Code" / "User" / "globalStorage" / "storage.json"
    )
    assert module.storage_path("/usr/bin/code-oss") == (
        config_home / "Code - OSS" / "User" / "globalStorage" / "storage.json"
    )

# macOS exposes VS Code helper processes with capitalized names to pgrep.
def fake_pgrep(command, **_kwargs):
    return mock.Mock(returncode=0 if command[-1] == "Code Helper" else 1)

with mock.patch.object(module.sys, "platform", "darwin"), mock.patch.object(
    module, "is_wsl", return_value=False
), mock.patch.object(module.shutil, "which", return_value="/usr/bin/pgrep"), mock.patch.object(
    module.subprocess, "run", side_effect=fake_pgrep
):
    assert module.vscode_is_running("/opt/homebrew/bin/code")
PY
}

check_vscode() {
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" --override-data '{"accounts":null}' execute-template --file home/.chezmoiscripts/run_onchange_setup-profiles.sh.tmpl >"$tmpdir/setup-profiles-empty.sh"
  grep -F 'scripts/share-codex-config.py' "$tmpdir/setup-profiles.sh" >/dev/null
  grep -F 'shared_config["cli_auth_credentials_store"] = "file"' "$CHEZMOI_SOURCE/scripts/share-codex-config.py" >/dev/null
  "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" cat ~/.gemini/settings.json >"$tmpdir/gemini-settings.json"
  mkdir -p "$tmpdir/bin"
  printf '%s\n' '#!/bin/sh' '[ "$#" -eq 2 ] && [ "$1" = which ] && [ "$2" = rg ] || exit 1' 'printf "%s\n" "/mise-test/ripgrep/rg"' >"$tmpdir/bin/mise"
  printf '%s\n' '#!/bin/sh' '[ "$#" -eq 2 ] && [ "$1" = --locate-extension ] && [ "$2" = continue.continue ] || exit 1' 'printf "%s\n" "${CHEZMOI_VSCODE_TEST_EXTENSION_PATH:-/mise-test/vscode/extensions/continue.continue}"' >"$tmpdir/bin/code"
  chmod +x "$tmpdir/bin/mise" "$tmpdir/bin/code"
  PATH="$tmpdir/bin:$PATH" "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" execute-template --file 'home/private_Library/private_Application Support/private_Code/User/settings.json.tmpl' >"$tmpdir/vscode-settings.json"
  python3 -c 'import json,sys; settings=json.load(open(sys.argv[1])); workspace=json.load(open(sys.argv[2])); associations=workspace["files.associations"]; assert "**/.chezmoitemplates/Code/settings.json" not in settings["files.associations"]; assert associations["**/*.tmpl"] == "go-template"; assert associations["**/.chezmoitemplates/**"] == "go-template"' "$tmpdir/vscode-settings.json" .vscode/settings.json
  python3 -m json.tool "$tmpdir/vscode-settings.json" >/dev/null
  python3 -c 'import json,sys; settings=json.load(open(sys.argv[1])); keys=set(settings)-{"yaml.schemas","workbench.settings.applyToAllProfiles","chat.instructionsFilesLocations"}; shared=set(settings["workbench.settings.applyToAllProfiles"]); assert keys == shared, "VS Code shared settings must be listed in applyToAllProfiles"; assert "chat.instructionsFilesLocations" not in shared, "VS Code instruction locations must remain profile-specific"; assert settings["todo-tree.ripgrep.ripgrep"] == "/mise-test/ripgrep/rg", "VS Code ripgrep path must come from mise which rg"; assert "file:///mise-test/vscode/extensions/continue.continue/config-yaml-schema.json" in settings["yaml.schemas"], "Continue schema path must come from code --locate-extension"' "$tmpdir/vscode-settings.json"
  for template in 'home/dot_config/Code/User/settings.json.tmpl' 'home/AppData/Roaming/Code/User/settings.json.tmpl'; do
    PATH="$tmpdir/bin:$PATH" "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" execute-template --file "$template" >"$tmpdir/vscode-platform-settings.json"
    cmp -s "$tmpdir/vscode-settings.json" "$tmpdir/vscode-platform-settings.json"
  done
  CHEZMOI_VSCODE_TEST_EXTENSION_PATH='C:\Users\Jane Doe\.vscode\extensions\continue.continue' PATH="$tmpdir/bin:$PATH" "$CHEZMOI" --source "$CHEZMOI_SOURCE" --config "$tmpdir/chezmoi.toml" execute-template --file 'home/AppData/Roaming/Code/User/settings.json.tmpl' >"$tmpdir/vscode-windows-settings.json"
  python3 -m json.tool "$tmpdir/vscode-windows-settings.json" >/dev/null
  python3 -c 'import json,sys; settings=json.load(open(sys.argv[1])); assert "file:///C:/Users/Jane%20Doe/.vscode/extensions/continue.continue/config-yaml-schema.json" in settings["yaml.schemas"]' "$tmpdir/vscode-windows-settings.json"
  for file in home/dot_zprofile home/dot_zshrc "$tmpdir/aliases" "$tmpdir/aliases-no-profiles" "$tmpdir/exports" "$tmpdir/functions" "$tmpdir/functions-no-profiles" "$tmpdir/integrations" "$tmpdir/integrations-no-profiles"; do
    zsh -n "$file"
  done
  sh -n "$tmpdir/setup-profiles.sh" "$tmpdir/setup-profiles-empty.sh" home/.chezmoiscripts/run_after_lint-zsh.sh install.sh scripts/copy-example-data.sh
  grep -Fx '#!/bin/sh' "$tmpdir/setup-profiles-empty.sh" >/dev/null
  python3 -m json.tool "$tmpdir/gemini-settings.json" >/dev/null
  GIT_CONFIG_PARAMETERS="'credential.helper=' 'credential.helper=!gh auth git-credential'" git config --get-all credential.helper | grep -Fx '!gh auth git-credential' >/dev/null
}

run_suite() {
  case $1 in
  all)
    check_bootstrap
    check_profiles
    check_init_ssh_config
    check_ssh_keys
    check_platforms
    check_profile_state
    check_vscode
    git diff --check
    printf '%s\n' \
      'PASS examples/.chezmoidata/*.example and scripts/copy-example-data.sh' \
      'PASS remote install bootstrap repository-root resolution' \
      'PASS home/dot_gitconfig.tmpl and home/dot_config/git/config.tmpl' \
      'PASS home/dot_config/private_gh/private_config.yml.tmpl' \
      'PASS home/.chezmoiscripts/run_onchange_setup-profiles.sh.tmpl' \
      'PASS home/.chezmoiscripts/run_onchange_before_generate-ssh-keys.sh.tmpl' \
      'PASS home/.chezmoi.yaml.tmpl SSH signing data generation' \
      'PASS home/dot_config/zsh/aliases.zsh.tmpl' \
      'PASS home/dot_config/zsh/exports.zsh.tmpl' \
      'PASS home/dot_config/zsh/functions.zsh.tmpl and integrations.zsh' \
      'PASS home/.chezmoidata/packages.yaml and platform package setup templates' \
      'PASS home/dot_config/mise/config.toml.tmpl' \
      'PASS home/.chezmoiignore.tmpl' \
      'PASS scripts/configure-vscode-profiles.py and VS Code profile setup template' \
      'PASS home/private_dot_gemini/settings.json' \
      'PASS home/.chezmoitemplates/Code/settings.json and platform settings templates' \
      'PASS .vscode/settings.json workspace settings'
    printf '%s\n' 'Repository checks passed.'
    ;;
  bootstrap)
    check_bootstrap
    ;;
  profiles)
    check_profiles
    ;;
  platforms)
    check_profiles
    check_platforms
    ;;
  profile-state)
    check_profiles
    check_profile_state
    ;;
  vscode)
    check_profiles
    check_profile_state
    check_vscode
    ;;
  esac

  if [ "$1" != all ]; then
    printf 'Check suite passed: %s\n' "$1"
  fi
}

run_suite "$suite"
