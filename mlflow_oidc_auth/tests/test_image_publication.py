import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest
import yaml


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = "europe-west3-docker.pkg.dev/prokube"
SHA = "a" * 40


@dataclass(frozen=True, slots=True)
class GitHubEvent:
    name: str
    ref_type: str
    ref_name: str
    oidc_version: str = "11.0.2"


def route(event: GitHubEvent) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(ROOT / "scripts/image-tags.sh")],
        env={
            "PATH": os.environ["PATH"],
            "EVENT_NAME": event.name,
            "REF_TYPE": event.ref_type,
            "REF_NAME": event.ref_name,
            "SOURCE_SHA": SHA,
            "OIDC_VERSION": event.oidc_version,
        },
        text=True,
        capture_output=True,
        check=False,
        timeout=10,
    )


@pytest.mark.parametrize("event_name", ["push", "workflow_dispatch"])
def test_branch_builds_publish_only_development_aliases(event_name: str) -> None:
    result = route(GitHubEvent(event_name, "branch", "feature/mlflow-upgrade"))

    assert result.returncode == 0, result.stderr
    outputs = dict(line.split("=", 1) for line in result.stdout.splitlines())
    assert outputs == {
        "publish": "true",
        "release": "false",
        "image_tag": f"{REGISTRY}/development/mlflow-oidc-auth:branch-feature-mlflow-upgrade",
        "commit_tag": f"{REGISTRY}/development/mlflow-oidc-auth:commit-{SHA}",
    }


def test_manual_run_on_release_tag_still_publishes_development() -> None:
    result = route(GitHubEvent("workflow_dispatch", "tag", "v11.0.2_v0.3.0"))

    assert result.returncode == 0, result.stderr
    outputs = dict(line.split("=", 1) for line in result.stdout.splitlines())
    assert outputs["release"] == "false"
    assert all("/development/" in outputs[key] for key in ("image_tag", "commit_tag"))


@pytest.mark.parametrize("tag", ["v11.0.2_v0.3.0", "v11.0.2_v0.3.0-rc1"])
def test_release_push_publishes_exactly_the_git_tag(tag: str) -> None:
    result = route(GitHubEvent("push", "tag", tag))

    assert result.returncode == 0, result.stderr
    outputs = dict(line.split("=", 1) for line in result.stdout.splitlines())
    assert outputs == {
        "publish": "true",
        "release": "true",
        "image_tag": f"{REGISTRY}/releases/mlflow-oidc-auth:{tag}",
        "commit_tag": "",
    }


@pytest.mark.parametrize("tag", ["latest", "v11.0.2", "v11.0.2_v0.3.0-latest", "v11.0.2_v0.3.0-rc", "v7.19.0_v0.3.0"])
def test_invalid_or_mismatched_release_is_rejected_without_falling_back_to_development(tag: str) -> None:
    result = route(GitHubEvent("push", "tag", tag))

    assert result.returncode != 0
    assert result.stdout == ""


def test_pull_request_build_cannot_publish() -> None:
    result = route(GitHubEvent("pull_request", "branch", "feature/mlflow-upgrade"))

    assert result.returncode == 0
    assert result.stdout == "publish=false\n"


def test_branch_alias_is_a_valid_bounded_docker_tag() -> None:
    result = route(GitHubEvent("push", "branch", ".release/" + "x" * 200 + ";$(exit 99)"))

    assert result.returncode == 0, result.stderr
    outputs = dict(line.split("=", 1) for line in result.stdout.splitlines())
    tag = outputs["image_tag"].rsplit(":", 1)[1]
    assert re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}", tag)


def test_publication_credentials_and_network_writes_are_gated() -> None:
    workflow = yaml.load((ROOT / ".github/workflows/pk-build.yaml").read_text(), Loader=yaml.BaseLoader)

    assert "pull_request_target" not in workflow["on"]
    assert workflow["permissions"] == {"contents": "read"}
    steps = workflow["jobs"]["build"]["steps"]
    sensitive = [step for step in steps if "secrets.GCP_SA_KEY" in str(step) or "docker push" in step.get("run", "")]
    assert len(sensitive) == 3
    guard = "github.repository == 'prokube/mlflow-oidc-auth' && github.event_name != 'pull_request' && steps.image.outputs.publish == 'true'"
    assert all(step["if"] == guard for step in sensitive)
    release_guard = next(step for step in steps if step.get("id") == "release-source")
    assert release_guard["if"] == "steps.image.outputs.release == 'true'"
    assert release_guard["run"] == "git merge-base --is-ancestor HEAD origin/pk-main"
