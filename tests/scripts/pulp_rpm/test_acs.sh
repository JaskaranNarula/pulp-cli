#!/bin/bash

# shellcheck source=tests/scripts/config.source
. "$(dirname "$(dirname "$(realpath "$0")")")"/config.source

pulp debug has-plugin --name "rpm" --min-version "3.17.0.dev" || exit 3

acs_remote="cli_test_rpm_acs_remote"
acs="cli_test_acs"

cleanup() {
  pulp rpm acs destroy --name $acs || true
  pulp rpm remote destroy --name $acs_remote || true
  pulp rpm repository destroy --name "cli-repo-metadata-only" || true
  pulp rpm remote destroy --name "cli-remote-metadata-only" || true
  pulp orphans delete || true
}
trap cleanup EXIT

cleanup

expect_succ pulp rpm remote create --name $acs_remote --url "$PULP_FIXTURES_URL" --policy "on_demand"

expect_succ pulp rpm acs create --name $acs --remote $acs_remote --path "rpm-unsigned/" --path "rpm-richnweak-deps/"
expect_succ pulp rpm acs list
test "$(echo "$OUTPUT" | jq -r length)" -ge 1
expect_succ pulp rpm acs show --name $acs
test "$(echo "$OUTPUT" | jq ".paths | length")" -eq 2

# manipulate paths
expect_succ pulp rpm acs path add --name $acs --path "rpm-invalid/"
expect_succ pulp rpm acs show --name $acs
test "$(echo "$OUTPUT" | jq ".paths | length")" -eq 3
expect_succ pulp rpm acs path remove --name $acs --path "rpm-invalid/"
expect_succ pulp rpm acs show --name $acs
test "$(echo "$OUTPUT" | jq ".paths | length")" -eq 2

# test refresh
expect_succ pulp rpm acs refresh --name $acs
task_group=$(echo "$ERROUTPUT" | grep -E -o "/pulp/api/v3/task-groups/[-[:xdigit:]]*/")
expect_succ pulp task-group show --href "$task_group"
test "$(echo "$OUTPUT" | jq ".tasks | length")" -eq 2

# create a remote with metadata only and sync it
expect_succ pulp rpm remote create --name "cli-remote-metadata-only" --url "$PULP_FIXTURES_URL/rpm-unsigned-meta-only/"
remote_href="$(echo "$OUTPUT" | jq -r ".pulp_href")"
expect_succ pulp rpm repository create --name "cli-repo-metadata-only" --remote "$remote_href"
expect_succ pulp rpm repository sync --name "cli-repo-metadata-only"

# test refresh with bad paths
expect_succ pulp rpm acs path add --name $acs --path "bad-path/"
expect_fail pulp rpm acs refresh --name $acs

expect_succ pulp rpm acs destroy --name $acs
