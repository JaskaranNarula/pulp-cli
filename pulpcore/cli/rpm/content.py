import gettext
from typing import IO, Optional, Union

import click

from pulpcore.cli.common.context import (
    PulpContext,
    PulpEntityContext,
    pass_entity_context,
    pass_pulp_context,
)
from pulpcore.cli.common.generic import (
    chunk_size_option,
    create_command,
    href_option,
    list_command,
    show_command,
)
from pulpcore.cli.core.context import PulpArtifactContext
from pulpcore.cli.rpm.context import PulpRpmPackageContext

_ = gettext.gettext


def _relative_path_callback(ctx: click.Context, param: click.Parameter, value: str) -> str:
    if value is not None:
        entity_ctx = ctx.find_object(PulpEntityContext)
        assert entity_ctx is not None
        entity_ctx.entity = {"relative_path": value}
    return value


def _sha256_callback(ctx: click.Context, param: click.Parameter, value: str) -> str:
    if value is not None:
        entity_ctx = ctx.find_object(PulpEntityContext)
        assert entity_ctx is not None
        entity_ctx.entity = {"sha256": value}
    return value


def _sha256_artifact_callback(
    ctx: click.Context, param: click.Parameter, value: Optional[str]
) -> Optional[Union[str, PulpEntityContext]]:
    # Pass None and "" verbatim
    if value:
        pulp_ctx = ctx.find_object(PulpContext)
        assert pulp_ctx is not None
        return PulpArtifactContext(pulp_ctx, entity={"sha256": value})
    return value


@click.group()
@click.option(
    "-t",
    "--type",
    "content_type",
    type=click.Choice(["package"], case_sensitive=False),
    default="package",
)
@pass_pulp_context
@click.pass_context
def content(ctx: click.Context, pulp_ctx: PulpContext, content_type: str) -> None:
    if content_type == "package":
        ctx.obj = PulpRpmPackageContext(pulp_ctx)
    else:
        raise NotImplementedError()


list_options = [
    click.option("--arch"),
    click.option("--arch-in", "arch__in"),
    click.option("--epoch"),
    click.option("--epoch-in", "epoch__in"),
    click.option("--fields"),
    click.option("--name"),
    click.option("--name-in", "name__in"),
    click.option("--package-href"),
    click.option("--release"),
    click.option("--release-in", "release__in"),
    click.option("--repository-version"),
    click.option("--version"),
    click.option("--version-in", "version__in"),
]
lookup_options = [
    href_option,
    click.option("--relative-path", callback=_relative_path_callback, expose_value=False),
    click.option("--sha256", callback=_sha256_callback, expose_value=False),
]
create_options = [
    click.option("--relative-path", required=True),
    click.option(
        "--sha256",
        "artifact",
        required=True,
        help=_("Digest of the artifact to use"),
        callback=_sha256_artifact_callback,
    ),
]


content.add_command(list_command(decorators=list_options))
content.add_command(show_command(decorators=lookup_options))
content.add_command(create_command(decorators=create_options))


@content.command()
@click.option("--relative-path", required=True)
@click.option("--file", type=click.File("rb"), required=True)
@chunk_size_option
@pass_entity_context
@pass_pulp_context
def upload(
    pulp_ctx: PulpContext,
    entity_ctx: PulpRpmPackageContext,
    relative_path: str,
    file: IO[bytes],
    chunk_size: int,
) -> None:
    """Create an rpm package content unit by uploading a file"""
    artifact_href = PulpArtifactContext(pulp_ctx).upload(file, chunk_size)
    content = {"relative_path": relative_path, "artifact": artifact_href}
    result = entity_ctx.create(body=content)
    pulp_ctx.output_result(result)
