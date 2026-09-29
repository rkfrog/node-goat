#!/usr/bin/env bash
#
# Create missing JFrog resources from a small JSON file. The script expands
# project, package types, and stages into repositories, global lifecycle
# stages, and an AppTrust application. Existing resources are never changed.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-jfrog.sh --config FILE [--server-id ID] [--dry-run] [--yes]

The target is the default JFrog CLI server unless --server-id is supplied.
The configuration file must be JSON with version: 1, project (used as both
the project key and name), repo_prefix, package_types, and optional stages.

A live run prints a plan after validation and waits for confirmation before
creating anything. Use --yes to skip the prompt. --dry-run prints the plan
and does not create resources.
EOF
}

LOG_FILE=

timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%z'
}

log_line() {
  [[ -n "$LOG_FILE" ]] || return 0
  printf '%s %s\n' "$(timestamp)" "$*" >>"$LOG_FILE"
}

log_block() {
  local title=$1
  local body=$2
  [[ -n "$LOG_FILE" ]] || return 0
  {
    printf '%s === %s ===\n' "$(timestamp)" "$title"
    printf '%s\n' "$body"
    printf '\n'
  } >>"$LOG_FILE"
}

fail() {
  log_line "ERROR: $*"
  printf 'ERROR: %s\n' "$*" >&2
  [[ -n "$LOG_FILE" ]] && printf 'Log file: %s\n' "$LOG_FILE" >&2
  exit 1
}

CONFIG=
SERVER_ID=
DRY_RUN=false
ASSUME_YES=false

while (($#)); do
  case "$1" in
    --config)
      (($# >= 2)) || fail "--config requires a file"
      CONFIG=$2
      shift 2
      ;;
    --server-id)
      (($# >= 2)) || fail "--server-id requires an ID"
      SERVER_ID=$2
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --yes|-y)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown option: $1"
      ;;
  esac
done

[[ -n "$CONFIG" ]] || fail "--config is required"
[[ -f "$CONFIG" ]] || fail "configuration file does not exist: $CONFIG"
command -v jq >/dev/null || fail "jq must be installed"
command -v jf >/dev/null || fail "JFrog CLI (jf) must be installed"
jq -e . "$CONFIG" >/dev/null || fail "configuration is not valid JSON"

mkdir -p logs
LOG_FILE="logs/jfrog-bootstrap-$(date '+%Y%m%d-%H%M%S').log"
log_line "bootstrap started"
log_line "config=$CONFIG dry_run=$DRY_RUN assume_yes=$ASSUME_YES"
log_block "input configuration" "$(jq . "$CONFIG")"
printf 'Log file: %s\n' "$LOG_FILE"

if [[ -z "$SERVER_ID" ]]; then
  SERVER_ID=$(jf config show 2>/dev/null |
    awk '/^Server ID:/{id=$NF} /^Default:[[:space:]]*true/{print id; exit}')
fi
[[ -n "$SERVER_ID" ]] || fail "no default JFrog CLI server; pass --server-id"

# Public registry URLs used for generated remote repositories.
REMOTE_URLS_JSON='{
  "alpine": "https://dl-cdn.alpinelinux.org/alpine",
  "bower": "https://registry.bower.io",
  "cargo": "https://index.crates.io",
  "chef": "https://supermarket.chef.io",
  "cocoapods": "https://cdn.cocoapods.org",
  "composer": "https://repo.packagist.org",
  "conan": "https://center.conan.io",
  "conda": "https://repo.anaconda.com/pkgs/main",
  "debian": "https://deb.debian.org/debian",
  "docker": "https://registry-1.docker.io",
  "gems": "https://rubygems.org",
  "generic": "https://github.com",
  "go": "https://proxy.golang.org",
  "gradle": "https://repo1.maven.org/maven2",
  "helm": "https://charts.helm.sh/stable",
  "ivy": "https://repo1.maven.org/maven2",
  "maven": "https://repo1.maven.org/maven2",
  "npm": "https://registry.npmjs.org",
  "nuget": "https://www.nuget.org/",
  "oci": "https://registry-1.docker.io",
  "pypi": "https://files.pythonhosted.org",
  "sbt": "https://repo1.maven.org/maven2",
  "terraform": "https://registry.terraform.io",
  "yum": "https://repo.almalinux.org/almalinux"
}'

SUPPORTED_TYPES=$(jq -r 'keys | join(", ")' <<<"$REMOTE_URLS_JSON")

validate_simple_config() {
  jq -e --argjson remotes "$REMOTE_URLS_JSON" '
    def pkg:
      ascii_downcase
      | if . == "python" then "pypi" else . end;
    .version == 1 and
    (.project | type == "string" and test("^[a-z][a-z0-9-]{0,30}[a-z0-9]$")) and
    (.repo_prefix | type == "string" and test("^[a-z][a-z0-9-]*[a-z0-9]$")) and
    (.package_types | type == "array" and length > 0) and
    ([.package_types[] | select(type != "string" or length == 0)] | length == 0) and
    ([.package_types[] | pkg] | unique | length == length) and
    ([.package_types[] | pkg] - ($remotes | keys) | length == 0) and
    ((.stages // ["DEV"]) | type == "array") and
    ([((.stages // ["DEV"])[]) | select(type != "string" or length == 0)] | length == 0) and
    ([((.stages // ["DEV"])[]) | ascii_upcase] | unique | length == length) and
    (.app_trust == true or .app_trust == false or .app_trust == null) and
    (if .app_trust == true then
      (.app_name | type == "string" and test("^[a-z][a-z0-9-]{0,62}[a-z0-9]$")) and
      ((.app_criticality // "unspecified") as $c | ["unspecified","low","medium","high","critical"] | index($c) != null) and
      ((.app_maturity // "unspecified") as $m | ["unspecified","experimental","production","end_of_life"] | index($m) != null) and
      ((.app_description // "") | type == "string") and
      ((.app_owner // "") | type == "string") and
      ((.app_labels // {}) | type == "object") and
      ([(.app_labels // {}) | to_entries[] | select(
        (.key | test("^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$") | not)
        or (.value | type != "string")
        or (.value | test("^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$") | not)
      )] | length == 0)
    else true end)
  ' "$CONFIG" >/dev/null
}

validate_simple_config || fail "configuration does not match the bootstrap schema. When app_trust is true, app_name must be a 2-64 character lowercase key, app_criticality must be unspecified/low/medium/high/critical, app_maturity must be unspecified/experimental/production/end_of_life, and app_labels must be an object whose keys and values use only letters, digits, '.', '_', and '-' (no @). Supported package types: $SUPPORTED_TYPES"

expand_config() {
  jq -c --argjson remotes "$REMOTE_URLS_JSON" '
    def pkg:
      ascii_downcase
      | if . == "python" then "pypi" else . end;
    def repo_stage:
      ascii_downcase
      | gsub("[^a-z0-9]"; "-") ;
    . as $in
    | $in.repo_prefix as $repo_prefix
    | $in.project as $project_key
    | ([($in.stages // ["DEV"])[] | ascii_upcase] | unique_by(.)) as $user_stages
    | (if ($user_stages | index("DEV")) then $user_stages
       else ["DEV"] + $user_stages end) as $stages
    | ([$in.package_types[] | pkg] | unique_by(.)) as $types
    | {
        project_key: $project_key,
        display_name: $in.project,
        project: {
          project_key: $project_key,
          display_name: $in.project,
          description: ("Project " + $in.project),
          admin_privileges: {
            manage_members: true,
            manage_resources: true,
            index_resources: true,
            manage_security_assets: true,
            allow_ignore_rules: false
          }
        },
        repositories: (
          [
            $types[] as $pkg
            | {
                key: ($repo_prefix + "-" + $pkg + "-remote"),
                configuration: {
                  key: ($repo_prefix + "-" + $pkg + "-remote"),
                  rclass: "remote",
                  packageType: $pkg,
                  url: $remotes[$pkg],
                  description: ($pkg + " remote for " + $in.project)
                }
              }
          ]
          + [
            $types[] as $pkg
            | $stages[] as $stage
            | ( $stage | repo_stage ) as $stage_key
            | {
                key: ($repo_prefix + "-" + $pkg + "-" + $stage_key + "-local"),
                configuration: {
                  key: ($repo_prefix + "-" + $pkg + "-" + $stage_key + "-local"),
                  rclass: "local",
                  packageType: $pkg,
                  description: ($pkg + " " + $stage + " local for " + $in.project)
                }
              }
          ]
          + [
            $types[] as $pkg
            | {
                key: ($repo_prefix + "-" + $pkg),
                configuration: (
                  {
                    key: ($repo_prefix + "-" + $pkg),
                    rclass: "virtual",
                    packageType: $pkg,
                    defaultDeploymentRepo: ($repo_prefix + "-" + $pkg + "-dev-local"),
                    repositories: (
                      [
                        $stages[] as $stage
                        | $repo_prefix + "-" + $pkg + "-" + ($stage | repo_stage) + "-local"
                      ]
                      + [$repo_prefix + "-" + $pkg + "-remote"]
                    ),
                    description: ($pkg + " virtual for " + $in.project + " (deploy to DEV)")
                  }
                )
              }
          ]
        ),
        global_lifecycle_stages: [
          $stages[] as $stage
          | {
              name: $stage,
              category: "promote",
              repositories: [
                $types[] as $pkg
                | $repo_prefix + "-" + $pkg + "-" + ($stage | repo_stage) + "-local"
              ]
            }
        ],
        app_trust: ($in.app_trust == true),
        application: (
          if $in.app_trust != true then null
          else
            {
              application_key: $in.app_name,
              application_name: $in.app_name,
              project_key: $project_key
            }
            + (if ($in.app_description // "") != "" then {description: $in.app_description} else {} end)
            + (if ($in.app_criticality // "") != "" then {criticality: $in.app_criticality} else {} end)
            + (if ($in.app_maturity // "") != "" then {maturity_level: $in.app_maturity} else {} end)
            + (if ($in.app_owner // "") != "" then {group_owners: [$in.app_owner]} else {} end)
            + (if ($in.app_labels // {}) == {} then {} else {labels: $in.app_labels} end)
          end
        )
      }
  ' "$CONFIG"
}

TMPDIR_BOOTSTRAP=$(mktemp -d "${TMPDIR:-/tmp}/jfrog-bootstrap.XXXXXX")
trap 'rm -rf "$TMPDIR_BOOTSTRAP"' EXIT
STATE="$TMPDIR_BOOTSTRAP/desired.json"
expand_config >"$STATE"
log_block "generated resource configuration" "$(jq . "$STATE")"
printf 'Generated resource configuration:\n'
jq . "$STATE"
printf '\n'

API_OUT=
API_ERR=
API_STATUS=
API_SEQUENCE=0

api_call() {
  local path=$1
  shift
  local payload_path= previous= arg
  API_SEQUENCE=$((API_SEQUENCE + 1))
  API_OUT="$TMPDIR_BOOTSTRAP/api-${API_SEQUENCE}.json"
  API_ERR="$TMPDIR_BOOTSTRAP/api-${API_SEQUENCE}.err"

  for arg in "$@"; do
    [[ $previous == --input ]] && payload_path=$arg
    previous=$arg
  done

  log_line "API request: $path $*"
  if [[ -n "$payload_path" && -f "$payload_path" ]]; then
    log_block "request payload $path" "$(jq . "$payload_path" 2>/dev/null || cat "$payload_path")"
  fi

  if jf api --server-id "$SERVER_ID" "$path" "$@" >"$API_OUT" 2>"$API_ERR"; then
    API_STATUS=0
  else
    API_STATUS=$?
  fi

  log_line "API result: exit=$API_STATUS http=$(http_status || true) $path"
  [[ -s "$API_ERR" ]] && log_block "response status $path" "$(cat "$API_ERR")"
  [[ -s "$API_OUT" ]] && log_block "response body $path" "$(jq . "$API_OUT" 2>/dev/null || cat "$API_OUT")"
  return "$API_STATUS"
}

http_status() {
  awk '/Http Status:/{print $NF; exit}' "$API_ERR"
}

# Artifactory GET /api/repositories/{key} returns 400 when the repository is
# missing. Access project GET returns 404. Accept both as "does not exist".
is_absent_status() {
  case "$(http_status || true)" in
    400|404) return 0 ;;
    *) return 1 ;;
  esac
}

report_api_error() {
  local resource=$1
  local status
  status=$(http_status || true)
  printf 'ERROR: %s failed (HTTP %s)\n' "$resource" "${status:-unknown}" >&2
  cat "$API_ERR" >&2
  [[ -s "$API_OUT" ]] && cat "$API_OUT" >&2
  exit 1
}

PLAN_FILE="$TMPDIR_BOOTSTRAP/plan.ndjson"
ASSOC_FILE="$TMPDIR_BOOTSTRAP/associate.txt"
: >"$PLAN_FILE"
: >"$ASSOC_FILE"

plan_associate_repository() {
  local repository_key=$1
  printf '%s\n' "$repository_key" >>"$ASSOC_FILE"
}

repository_assigned_to_project() {
  local assigned
  assigned=$(jq -r --arg project "$project_key" '
    (.projectKey // .project_key // "") as $key
    | if $key == $project then "yes" else "no" end
  ' "$API_OUT")
  [[ $assigned == yes ]]
}

append_plan() {
  local action=$1 kind=$2 name=$3 path=${4:-} method=${5:-} payload=${6:-null}
  jq -nc \
    --arg action "$action" \
    --arg kind "$kind" \
    --arg name "$name" \
    --arg path "$path" \
    --arg method "$method" \
    --argjson payload "$payload" \
    '{action:$action,kind:$kind,name:$name,path:$path,method:$method,payload:$payload}' \
    >>"$PLAN_FILE"
  local label
  label=$(printf '%s' "$action" | tr '[:lower:]' '[:upper:]')
  printf '  %s: %s %s\n' "$label" "$kind" "$name"
  log_line "PLAN $label $kind $name"
}

log_line "server_id=$SERVER_ID"
printf 'Target JFrog CLI server: %s\n' "$SERVER_ID"
printf 'Project key and name: %s\n' "$(jq -r '.project_key' "$STATE")"
printf 'Repository prefix: %s\n' "$(jq -r '.repositories[0].key | sub("-[^-]+-remote$"; "")' "$STATE")"

printf 'Checking Artifactory readiness...\n'
if api_call "/artifactory/api/system/ping"; then
  printf 'READY: Artifactory\n'
  log_line "Artifactory ping OK"
else
  report_api_error "Artifactory readiness ping"
fi

printf '\nAssessing resources:\n'

project=$(jq -c '.project' "$STATE")
project_key=$(jq -r '.project_key' "$STATE")
if api_call "/access/api/v1/projects/$project_key"; then
  append_plan exists project "$project_key"
else
  is_absent_status ||
    report_api_error "checking project $project_key"
  append_plan create project "$project_key" "/access/api/v1/projects" POST "$project"
fi

while IFS= read -r repository; do
  repository_key=$(jq -r '.key' <<<"$repository")
  repository_payload=$(jq -c '.configuration' <<<"$repository")
  if api_call "/artifactory/api/repositories/$repository_key"; then
    append_plan exists repository "$repository_key"
    if repository_assigned_to_project; then
      append_plan exists "project repository association" "$repository_key"
    else
      plan_associate_repository "$repository_key"
    fi
  else
    is_absent_status ||
      report_api_error "checking repository $repository_key"
    append_plan create repository "$repository_key" \
      "/artifactory/api/repositories/$repository_key" PUT "$repository_payload"
    plan_associate_repository "$repository_key"
  fi
done < <(jq -c '.repositories[]' "$STATE")

while IFS= read -r repository_key; do
  [[ -n "$repository_key" ]] || continue
  append_plan associate repository "$repository_key" \
    "/access/api/v1/projects/_/attach/repositories/${repository_key}/${project_key}?force=true" PUT
done <"$ASSOC_FILE"

api_call "/access/api/v2/stages?scope=global" || report_api_error "listing global lifecycle stages"
GLOBAL_STAGES_FILE=$API_OUT
while IFS= read -r stage; do
  stage_name=$(jq -r '.name' <<<"$stage")
  if jq -e --arg name "$stage_name" '.[] | select(.name == $name and .scope == "global")' \
      "$GLOBAL_STAGES_FILE" >/dev/null; then
    append_plan exists "global lifecycle stage" "$stage_name"
  else
    append_plan create "global lifecycle stage" "$stage_name" \
      "/access/api/v2/stages" POST "$stage"
  fi
done < <(jq -c '.global_lifecycle_stages[]' "$STATE")

if jq -e '.app_trust != true' "$STATE" >/dev/null; then
  append_plan skip "AppTrust application" "app_trust is not true"
elif ! api_call "/apptrust/api/v1/system/ping"; then
  ping_status=$(http_status || true)
  if [[ "$ping_status" == 404 || "$ping_status" == 503 ]]; then
    printf 'NOT READY: AppTrust (HTTP %s); application changes will be skipped\n' "$ping_status"
    log_line "AppTrust ping HTTP $ping_status"
    append_plan skip "AppTrust application" "AppTrust readiness check returned HTTP $ping_status"
  else
    report_api_error "AppTrust readiness ping"
  fi
else
  printf 'READY: AppTrust\n'
  log_line "AppTrust ping OK"
  application=$(jq -c '.application' "$STATE")
  application_key=$(jq -r '.application_key' <<<"$application")
  if api_call "/apptrust/api/v1/applications/$application_key"; then
    update_payload=$(jq -c --argjson desired "$application" '
      def labels_obj:
        if type == "array" then map(select(.key != null) | {(.key): .value}) | add // {}
        elif type == "object" then .
        else {} end;
      def same_labels:
        (($desired.labels // {}) | to_entries | sort_by(.key))
        == ((.labels | labels_obj) | to_entries | sort_by(.key));
      def same_groups:
        (($desired.group_owners // []) | sort)
        == ((.group_owners // []) | sort);
      {
        application_name: (if .application_name != $desired.application_name then $desired.application_name else empty end),
        description: (if (.description // "") != ($desired.description // "") then ($desired.description // "") else empty end),
        criticality: (if (.criticality // "unspecified") != ($desired.criticality // "unspecified") then ($desired.criticality // "unspecified") else empty end),
        maturity_level: (if (.maturity_level // "unspecified") != ($desired.maturity_level // "unspecified") then ($desired.maturity_level // "unspecified") else empty end),
        group_owners: (if same_groups then empty else ($desired.group_owners // []) end),
        labels: (if same_labels then empty else ($desired.labels // {}) end)
      }
    ' "$API_OUT")
    if [[ "$update_payload" == "{}" ]]; then
      append_plan exists "AppTrust application" "$application_key"
    else
      append_plan update "AppTrust application" "$application_key" \
        "/apptrust/api/v1/applications/$application_key" PATCH "$update_payload"
    fi
  elif is_absent_status; then
    append_plan create "AppTrust application" "$application_key" \
      "/apptrust/api/v1/applications" POST "$application"
  else
    report_api_error "checking AppTrust application $application_key"
  fi
fi

log_block "execution plan" "$(jq -s '.' "$PLAN_FILE")"
printf '\n'
create_count=$(jq -s '[.[] | select(.action=="create")] | length' "$PLAN_FILE")
associate_count=$(jq -s '[.[] | select(.action=="associate")] | length' "$PLAN_FILE")
update_count=$(jq -s '[.[] | select(.action=="update")] | length' "$PLAN_FILE")
exists_count=$(jq -s '[.[] | select(.action=="exists")] | length' "$PLAN_FILE")
skip_count=$(jq -s '[.[] | select(.action=="skip")] | length' "$PLAN_FILE")
printf 'Summary: %s to create, %s to update, %s to associate, %s already present, %s skipped\n' \
  "$create_count" "$update_count" "$associate_count" "$exists_count" "$skip_count"

if "$DRY_RUN"; then
  log_line "dry-run complete; no resources were created"
  printf 'Dry-run: no resources were created.\n'
  printf 'Log file: %s\n' "$LOG_FILE"
  exit 0
fi

if (( create_count + update_count + associate_count == 0 )); then
  log_line "nothing to create"
  printf 'Nothing to create.\n'
  printf 'Log file: %s\n' "$LOG_FILE"
  exit 0
fi

if ! "$ASSUME_YES"; then
  printf 'Apply this plan and create the missing resources? [y/N] '
  read -r reply || reply=
  case "$reply" in
    y|Y|yes|YES)
      log_line "plan confirmed by user"
      ;;
    *)
      log_line "plan rejected by user"
      fail "plan rejected; no resources were created"
      ;;
  esac
fi

while IFS= read -r item; do
  kind=$(jq -r '.kind' <<<"$item")
  name=$(jq -r '.name' <<<"$item")
  path=$(jq -r '.path' <<<"$item")
  method=$(jq -r '.method' <<<"$item")
  payload=$(jq -c '.payload' <<<"$item")
  action=$(jq -r '.action' <<<"$item")
  if [[ $payload == null ]]; then
    api_call "$path" -X "$method" ||
      report_api_error "${action}ing $kind $name"
  else
    payload_file="$TMPDIR_BOOTSTRAP/payload-$API_SEQUENCE.json"
    printf '%s\n' "$payload" >"$payload_file"
    api_call "$path" -X "$method" -H "Content-Type: application/json" --input "$payload_file" ||
      report_api_error "${action}ing $kind $name"
  fi
  if [[ $action == associate ]]; then
    log_line "ASSOCIATED $kind $name -> $project_key"
    printf 'ASSOCIATED: %s %s -> %s\n' "$kind" "$name" "$project_key"
  elif [[ $action == update ]]; then
    log_line "UPDATED $kind $name"
    printf 'UPDATED: %s %s\n' "$kind" "$name"
  else
    log_line "CREATED $kind $name"
    printf 'CREATED: %s %s\n' "$kind" "$name"
  fi
done < <(jq -c 'select(.action=="create" or .action=="update" or .action=="associate")' "$PLAN_FILE")
log_line "bootstrap completed"
printf 'Log file: %s\n' "$LOG_FILE"
