import gettext

from pulpcore.cli.common import main
from pulpcore.cli.common.context import PluginRequirement, PulpContext, pass_pulp_context
from pulpcore.cli.rpm.acs import acs
from pulpcore.cli.rpm.content import content
from pulpcore.cli.rpm.distribution import distribution
from pulpcore.cli.rpm.publication import publication
from pulpcore.cli.rpm.remote import remote
from pulpcore.cli.rpm.repository import repository

_ = gettext.gettext


@main.group()
@pass_pulp_context
def rpm(pulp_ctx: PulpContext) -> None:
    pulp_ctx.needs_plugin(PluginRequirement("rpm", min="3.9"))


rpm.add_command(repository)
rpm.add_command(remote)
rpm.add_command(publication)
rpm.add_command(distribution)
rpm.add_command(content)
rpm.add_command(acs)
