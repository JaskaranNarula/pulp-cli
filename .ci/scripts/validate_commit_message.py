import os
import re
import subprocess
import sys
from pathlib import Path

from github import Github

KEYWORDS = ["fixes", "closes"]
NO_ISSUE = "[noissue]"
CHANGELOG_EXTS = [".feature", ".bugfix", ".doc", ".removal", ".misc", ".deprecation"]

sha = sys.argv[1]
project = "pulp-cli"
message = subprocess.check_output(["git", "log", "--format=%B", "-n 1", sha]).decode("utf-8")

g = Github(os.environ.get("GITHUB_TOKEN"))
repo = g.get_repo("pulp/pulp-cli")


def __check_status(issue):
    gi = repo.get_issue(int(issue))
    if gi.pull_request:
        sys.exit(f"Error: issue #{issue} is a pull request.")
    if gi.closed_at:
        sys.exit(f"Error: issue #{issue} is closed.")


def __check_changelog(issue):
    matches = list(Path("CHANGES").rglob(f"{issue}.*"))

    if len(matches) < 1:
        sys.exit(f"Could not find changelog entry in CHANGES/ for {issue}.")
    for match in matches:
        if match.suffix not in CHANGELOG_EXTS:
            sys.exit(f"Invalid extension for changelog entry '{match}'.")


print("Checking commit message for {sha}.".format(sha=sha[0:7]))

# validate the issue attached to the commit
regex = r"(?:{keywords})[\s:]+#(\d+)".format(keywords=("|").join(KEYWORDS))
pattern = re.compile(regex, re.IGNORECASE)

issues = pattern.findall(message)

if issues:
    for issue in pattern.findall(message):
        __check_status(issue)
        __check_changelog(issue)
else:
    if NO_ISSUE in message:
        print("Commit {sha} has no issues but is tagged {tag}.".format(sha=sha[0:7], tag=NO_ISSUE))
    else:
        sys.exit(
            "Error: no attached issues found for {sha}. If this was intentional, add "
            " '{tag}' to the commit message.".format(sha=sha[0:7], tag=NO_ISSUE)
        )

print("Commit message for {sha} passed.".format(sha=sha[0:7]))
