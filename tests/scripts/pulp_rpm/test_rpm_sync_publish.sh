#!/bin/bash

# shellcheck source=tests/scripts/config.source
. "$(dirname "$(dirname "$(realpath "$0")")")"/config.source

pulp debug has-plugin --name "rpm" || exit 3

cleanup() {
  pulp rpm distribution destroy --name "cli_test_rpm_distro" || true
  pulp rpm repository destroy --name "cli_test_rpm_repository" || true
  pulp rpm remote destroy --name "cli_test_rpm_remote" || true
}
trap cleanup EXIT

if [ "$VERIFY_SSL" = "false" ]
then
  curl_opt="-k"
else
  curl_opt=""
fi

expect_succ pulp rpm remote create --name "cli_test_rpm_remote" --url "$RPM_REMOTE_URL"
expect_succ pulp rpm remote show --name "cli_test_rpm_remote"
expect_succ pulp rpm repository create --name "cli_test_rpm_repository" --remote "cli_test_rpm_remote" --description "cli test repository"
expect_succ pulp rpm repository update --name "cli_test_rpm_repository" --description ""
expect_succ pulp rpm repository show --name "cli_test_rpm_repository"
test "$(echo "$OUTPUT" | jq -r '.description')" = "null"

# skip-types is broken in 3.12.0
if pulp debug has-plugin --name "rpm" --min-version "3.12.0" --max-version "3.12.1"
then
  expect_succ pulp rpm repository sync --name "cli_test_rpm_repository"
else
  expect_succ pulp rpm repository sync --name "cli_test_rpm_repository" --skip-type srpm
fi

expect_succ pulp rpm publication create --repository "cli_test_rpm_repository"
PUBLICATION_HREF=$(echo "$OUTPUT" | jq -r .pulp_href)
expect_succ pulp rpm publication create --repository "cli_test_rpm_repository" --version 0
PUBLICATION_VER_HREF=$(echo "$OUTPUT" | jq -r .pulp_href)

expect_succ pulp rpm distribution create --name "cli_test_rpm_distro" \
  --base-path "cli_test_rpm_distro" \
  --publication "$PUBLICATION_HREF"

expect_succ curl "$curl_opt" --head --fail "$PULP_BASE_URL/pulp/content/cli_test_rpm_distro/config.repo"

expect_succ pulp rpm repository version list --repository "cli_test_rpm_repository"
expect_succ pulp rpm repository version repair --repository "cli_test_rpm_repository" --version 1

expect_succ pulp rpm repository update --name "cli_test_rpm_repository" --retain-package-versions 2
expect_succ pulp rpm repository show --name "cli_test_rpm_repository"
test "$(echo "$OUTPUT" | jq -r '.retain_package_versions')" = "2"

expect_succ pulp rpm distribution destroy --name "cli_test_rpm_distro"
expect_succ pulp rpm publication destroy --href "$PUBLICATION_HREF"
expect_succ pulp rpm publication destroy --href "$PUBLICATION_VER_HREF"
expect_succ pulp rpm repository destroy --name "cli_test_rpm_repository"
expect_succ pulp rpm remote destroy --name "cli_test_rpm_remote"

# auto-publish
if pulp debug has-plugin --name "rpm" --min-version "3.12.0"
then
  expect_succ pulp rpm remote create --name "cli_test_rpm_remote" --url "$RPM_REMOTE_URL"
  expect_succ pulp rpm repository create --name "cli_test_rpm_repository" --remote "cli_test_rpm_remote" --autopublish

  expect_succ pulp rpm distribution create --name "cli_test_rpm_distro" \
    --base-path "cli_test_rpm_distro" \
    --repository "cli_test_rpm_repository"

  expect_succ pulp rpm repository sync --name "cli_test_rpm_repository"
  expect_succ pulp rpm publication list
  test "$(echo "$OUTPUT" | jq -r length)" -eq 1
  if pulp debug has-plugin --name "rpm" --max-version "3.13.0.dev"
  then
    expect_succ pulp rpm distribution show --name "cli_test_rpm_distro"
    echo "$OUTPUT" | jq -r ".publication" | grep -q '/pulp/api/v3/publications/rpm/rpm/'
  fi
fi
