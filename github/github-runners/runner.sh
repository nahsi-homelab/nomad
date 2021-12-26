#! /usr/bin/env bash
# https://docs.github.com/en/rest/reference/actions#self-hosted-runners

[[ $DEBUG ]] && set -x

log() {
  echo "$1" >&2
}

required_vars=(
  "GITHUB_PAT"
  "RUNNER_TYPE"
  "RUNNER_DIR"
)

error=0
for var in ${required_vars[@]}; do
  if [[ -z ${!var} ]]; then
    log "$var must be defined"
    error=1
  fi
  ((error)) && exit 1
done

case $RUNNER_TYPE in
  org)
    if [[ -z $GITHUB_ORG ]]; then
      log "GITHUB_ORG must be defined when GITHUB_TYPE=org"
      exit 1
    else
      url="https://api.github.com/orgs/$GITHUB_ORG/actions/runners"
      RUNNER_URL="https://github.com/$GITHUB_ORG"
    fi
  ;;
  repo)
    if [[ -z $GITHUB_REPO ]]; then
      log "GITHUB_REPO must be defined when RUNNER_TYPE=repo"
      exit 1
    else
      url="https://api.github.com/repos/$GITHUB_REPO/actions/runners"
      RUNNER_URL="https://github.com/$GITHUB_REPO"
    fi
  ;;
  *)
    log "No such RUNNER_TYPE $RUNNER_TYPE"
    exit 1
  ;;
esac


api() {
  local url="$1"

  accept_header="Accept: application/vnd.github.v3+json"
  auth_header="Authorization: token $GITHUB_PAT"

  if code=$(curl -sS -X POST -H "$accept_header" -H "$auth_header" -w '%{http_code}\n' --output /tmp/output "$url" 2>&1); then
    case $code in
      20*)
        cat /tmp/output
        rm /tmp/output
        return 0
      ;;
      *)
        cat /tmp/output
        rm /tmp/output
        return 1
      ;;
    esac
  else
    log "curl command failed"
    log "code: $code"
    log "url: $url"
    exit 1
  fi
}

get_token() {
  case $1 in
    register) local url="${url}/registration-token" ;;
    remove) local url="${url}/remove-token" ;;
  esac

  if out="$(api ${url})"; then
    log "Successfully created token"
    RUNNER_TOKEN=$(echo $out | jq -r .token)
  else
    log "Failed to create token"
    log "$(echo $out | jq)"
    exit 1
  fi
}

register_runner() {
  get_token register
  ${RUNNER_DIR}/config.sh \
    --unattended \
    --token "$RUNNER_TOKEN" \
    --url "$RUNNER_URL" \
    --work ${RUNNER_DIR}/_work \
    --replace \
    --name "${NOMAD_ALLOC_ID}" \
    --labels "${RUNNER_LABELS}"
}

remove_runner() {
  get_token remove
  ${RUNNER_DIR}/config.sh remove \
    --unattended \
    --token "$RUNNER_TOKEN"
}

register_runner
trap 'remove_runner' INT TERM
${RUNNER_DIR}/bin/Runner.Listener run "$@" &
wait $!
