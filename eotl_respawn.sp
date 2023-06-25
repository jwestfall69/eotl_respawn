#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_AUTHOR "ack"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include "../eotl_rolled/eotl_rolled.inc"

public Plugin myinfo = {
	name = "eotl_respawn",
	author = PLUGIN_AUTHOR,
	description = "Eotl Respawn w/auto adjust for stuff/roll rounds",
	version = PLUGIN_VERSION,
	url = ""
};

bool g_bSpawnEnabled = false;
int g_iTF2GameRulesEntity;

ConVar g_cvEnabled;
ConVar g_cvDebug;
ConVar g_cvBlueRespawnTime;
ConVar g_cvRedRespawnTime;
float g_BlueRespawnOffset;
float g_RedRespawnOffset;

ConVar g_cvStuffedRespawnOffset;
ConVar g_cvRolledRespawnOffset;

public void OnPluginStart() {
	LogMessage("version %s starting", PLUGIN_VERSION);

	RegConsoleCmd("sm_rro", CommandRRO);

	HookEvent("player_death", EventPlayerDeath);
	HookEvent("player_team", EventPlayerTeam);
	HookEvent("teamplay_round_start", EventRoundStart, EventHookMode_PostNoCopy);

	HookEvent("teamplay_round_stalemate", EventDisableSpawn, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", EventDisableSpawn, EventHookMode_PostNoCopy);
	HookEvent("teamplay_game_over", EventDisableSpawn, EventHookMode_PostNoCopy);

	g_cvEnabled = CreateConVar("sm_respawn_time_enabled", "1", "Enable or disable the plugin 1=On, 0=Off", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDebug = CreateConVar("eotl_respawn_debug", "0", "0/1 enable debug output", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvBlueRespawnTime = CreateConVar("sm_respawn_time_blue", "10", "blue teams minimum spawn time", FCVAR_NOTIFY, true, 0.0);
	g_cvRedRespawnTime = CreateConVar("sm_respawn_time_red", "10", "red teams minimum spawn time", FCVAR_NOTIFY, true, 0.0);

	g_cvStuffedRespawnOffset = CreateConVar("eotl_respawn_stuffed_offset", "1", "If blue was stuffed last round.  This round, red respawn will go down by this much, and blue will increase by this much");
	g_cvRolledRespawnOffset = CreateConVar("eotl_respawn_rolled_offset", "1", "If red was rolled last round. This round, blue respawn will go down by this much, and red will increase by this much");

}

public void OnMapStart() {

	// force disable if arena mode
	if(FindEntityByClassname(-1, "tf_logic_arena") >= 0) {
		SetConVarInt(g_cvEnabled, 0);
	}

	g_iTF2GameRulesEntity = FindEntityByClassname(-1, "tf_gamerules");
	if(g_iTF2GameRulesEntity == -1) {
		LogMessage("Couldn't find tf_gamerules (won't be able to adjust the maps' spawn wave times)");
	}

	g_BlueRespawnOffset = 0.0;
	g_RedRespawnOffset = 0.0;
	g_bSpawnEnabled = true;
}

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	g_bSpawnEnabled = true;
	return Plugin_Continue;
}

// events that should trigger us to stop (re)spawning players
public Action EventDisableSpawn(Handle event, const char[] name, bool dontBroadcast) {
	g_bSpawnEnabled = false;
	return Plugin_Continue;
}

// if a player switches from spec to a team we need to create a timer to spawn them
// or the game may subject them to the really high spawnwave time we set
public Action EventPlayerTeam(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	TFTeam team = TF2_GetClientTeam(client);

	if (team != TFTeam_Blue && team != TFTeam_Red) {
		return Plugin_Continue;
	}

	float respawnTime;
	if(team == TFTeam_Blue) {
		respawnTime = g_cvBlueRespawnTime.FloatValue + g_BlueRespawnOffset;
	} else {
		respawnTime = g_cvRedRespawnTime.FloatValue + g_RedRespawnOffset;
	}

	CreateTimer(respawnTime, SpawnPlayerTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action EventPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {

	if(!g_cvEnabled.BoolValue || !g_bSpawnEnabled) {
		return Plugin_Continue;
	}

	if((GetEventInt(event, "death_flags") & TF_DEATHFLAG_DEADRINGER) == TF_DEATHFLAG_DEADRINGER) {
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	TFTeam team = TF2_GetClientTeam(client);

	float respawnTime;
	if(team == TFTeam_Blue) {
		respawnTime = g_cvBlueRespawnTime.FloatValue + g_BlueRespawnOffset;
	} else {
		respawnTime = g_cvRedRespawnTime.FloatValue + g_RedRespawnOffset;
	}

	// being a little lazy here, its possible that a map maker could change
	// the spawnwave times mid map, so we just make sure they are set right
	// each player death.
	SetSpawnWaves();

	CreateTimer(respawnTime, SpawnPlayerTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action SpawnPlayerTimer(Handle timer, int client) {

	if(!g_bSpawnEnabled || !IsClientConnected(client) || !IsClientInGame(client) || IsPlayerAlive(client)) {
		return Plugin_Continue;
	}

	TFTeam team = TF2_GetClientTeam(client);
	if (team == TFTeam_Blue || team == TFTeam_Red) {
		LogDebug("spawning client %d (team: %s)", client, (team == TFTeam_Blue ? "blue" : "red"));
		TF2_RespawnPlayer(client);
	}
	return Plugin_Continue;
}

// set spawn wave values to be 0.5 * respawnTime to better line up with actual respawn time.
// what is displayed to the client will still be a bit off (higher) then the actual time
// respawn time.
void SetSpawnWaves() {

	if(g_iTF2GameRulesEntity < 0) {
		return;
	}

	if(!g_cvEnabled.BoolValue) {
		return;
	}

	float respawnWave = (g_cvBlueRespawnTime.FloatValue + g_BlueRespawnOffset) * 0.5;
	SetVariantFloat(respawnWave);
	AcceptEntityInput(g_iTF2GameRulesEntity, "SetBlueTeamRespawnWaveTime", -1, -1, 0);

	respawnWave = (g_cvRedRespawnTime.FloatValue + g_RedRespawnOffset) * 0.5;
	SetVariantFloat(respawnWave);
	AcceptEntityInput(g_iTF2GameRulesEntity, "SetRedTeamRespawnWaveTime", -1, -1, 0);
}

public void OnTeamRolled(int rollType, bool isMiniRound) {
	LogMessage("OnTeamRolled: rollType: %d, isMiniRound: %d", rollType, isMiniRound);

	switch(rollType) {
		case ROLL_TYPE_ROLLED: {
			LogMessage("OnTeamRolled: Red got rolled");
			// if this is a mini-round the teams dont swap so we need to
			// apply the +offset to blue and -offset red.
			if(isMiniRound) {
				g_BlueRespawnOffset = g_cvStuffedRespawnOffset.FloatValue;
				g_RedRespawnOffset = -g_cvStuffedRespawnOffset.FloatValue;
			} else {
				g_BlueRespawnOffset = -g_cvRolledRespawnOffset.FloatValue;
				g_RedRespawnOffset = g_cvRolledRespawnOffset.FloatValue;
			}
		}
		case ROLL_TYPE_STUFFED: {
			LogMessage("OnTeamRolled: Blue got stuffed");
			if(isMiniRound) {
				LogMessage("onTeamRolled: ERROR mini-round + blue was stuffed!? setting offsets to 0");
				g_BlueRespawnOffset = 0.0;
				g_RedRespawnOffset = 0.0;
			} else {
				g_BlueRespawnOffset = g_cvStuffedRespawnOffset.FloatValue;
				g_RedRespawnOffset = -g_cvStuffedRespawnOffset.FloatValue;
			}
		}
		case ROLL_TYPE_NONE: {
			LogMessage("OnTeamRolled: No roll or stuff happened, setting offsets to 0");
			g_BlueRespawnOffset = 0.0;
			g_RedRespawnOffset = 0.0;
		}
		default: {
			LogMessage("OnTeamRolled: Invalid rollType %d, setting offsets to 0", rollType);
			g_BlueRespawnOffset = 0.0;
			g_RedRespawnOffset = 0.0;
		}
	}

	// if appying the offset results in a negative respawn time value, adjust
	// it so the result is a respawn time of 0.1 seconds
	if(g_cvBlueRespawnTime.FloatValue + g_BlueRespawnOffset < 0.0) {
		g_BlueRespawnOffset = (-g_cvBlueRespawnTime.FloatValue) + 0.1;
	}

	if(g_cvRedRespawnTime.FloatValue + g_RedRespawnOffset < 0.0) {
		g_RedRespawnOffset = (-g_cvRedRespawnTime.FloatValue) + 0.1;
	}

	LogMessage("Adjusting respawn times (blue: %.1f -> %.1f, red: %.1f -> %.1f)", g_cvBlueRespawnTime.FloatValue, g_cvBlueRespawnTime.FloatValue + g_BlueRespawnOffset, g_cvRedRespawnTime.FloatValue, g_cvRedRespawnTime.FloatValue + g_RedRespawnOffset);
}

public Action CommandRRO(int client, int args) {
	PrintToChat(client, "\x01[\x03rro\x01] Blue respawn : %.1fs (rro: %s%.1fs)", g_cvBlueRespawnTime.FloatValue + g_BlueRespawnOffset, (g_BlueRespawnOffset > 0 ? "+" : ""), g_BlueRespawnOffset);
	PrintToChat(client, "\x01[\x03rro\x01] Red respawn : %.1fs (rro: %s%.1fs)", g_cvRedRespawnTime.FloatValue + g_RedRespawnOffset, (g_RedRespawnOffset > 0 ? "+" : ""), g_RedRespawnOffset);
	return Plugin_Handled;
}

void LogDebug(char []fmt, any...) {

    if(!g_cvDebug.BoolValue) {
        return;
    }

    char message[128];
    VFormat(message, sizeof(message), fmt, 2);
    LogMessage(message);
}