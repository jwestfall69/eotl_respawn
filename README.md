# eotl_respawn

This is a TF2 sourcemod plugin I wrote for the [EOTL](https://www.endofthelinegaming.com/) community.

This is meant to be a drop in replacement for the [TF2 Respawn System](https://forums.alliedmods.net/showthread.php?p=612221), but has a number of changes over the original to better fit our communities needs on the payload server.

  * Rewritten in new style sourcemod syntax
  * Support for OnTeamRolled forward from eotl_rolled plugin
  * Auto adjusting respawn times if a rolled/stuff event happened last round
  * Removed some unneeded features

### Dependencies
<hr>

If you are trying to compile this it has a dependency on eotl_rolled.inc which is part of the eotl_rolled plugin.

### Say Commands
<hr>

**!rro**

"rolled respawn offset"

This command will display to the client the current respawn times and if any rolled offset is applied.

### ConVars
<hr>

With eotl_respawn meant to be a drop in replacement for the TF2 Respawn System plugin it has a number of the same convars instead of the expected eotl_respawn_* ones.

**sm_respawn_time_enabled [0/1]**

If this plugin should be enabled.

Default: 1 (enabled)

**sm_respawn_time_blue [seconds]**

The respawn time for the blue team in seconds (float)

default: 10

**sm_respawn_time_red [seconds]**

The respawn time for the red team in seconds (float)

default: 10

**eotl_respawn_stuffed_offset [seconds]**

When a stuffed event happens this is the number of seconds that respawn times will be adjusted for both teams.  The team that got stuffed will have their respawn time go down by this much, and stuffing team increased by this much.

default: 1

**eotl_respawn_rolled_offset [seconds]**

When a rolled event happens this is the number of seconds that respawn times will be adjusted for both teams.  The team that got rolled will have their respawn time go down by this much, and stuffing team increased by this much.

default: 1

**eotl_respawn_debug [0/1]**

Disable/Enable debug logging

Default: 0 (disabled)