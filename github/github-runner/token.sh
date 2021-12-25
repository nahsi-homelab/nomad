#! /usr/bin/env bash

header="Accept: application/vnd.github.v3+json"
url=https://$TOKEN@api.github.com/orgs/nahsi-homelab/actions/runners/registration-token

if code=$(curl -sS -X POST -H "$header" -w '%{http_code}\n' --output output "$url" 2>&1); then
  case $code in
    201)
      echo "Successfully created token"
      jq -r .token output > alloc/data/token
      sleep 10
      exit
      ;;
    *)
      echo "Failed to create token"
      jq . output
      exit 1
      ;;
  esac
else
  echo "Failed to create token"
  echo $code
  exit 1
fi
