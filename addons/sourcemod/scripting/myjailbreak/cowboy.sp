/*
 * MyJailbreak - Cowboy Event Day Plugin.
 * by: shanapu
 * https://github.com/shanapu/myjailbreak/
 * 
 * Copyright (C) 2016-2017 Thomas Schmidt (shanapu)
 *
 * This file is part of the MyJailbreak SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

/******************************************************************************
                   STARTUP
******************************************************************************/

// Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <emitsoundany>
#include <colors>
#include <autoexecconfig>
#include <mystocks>

// Optional Plugins
#undef REQUIRE_PLUGIN
#include <hosties>
#include <lastrequest>
#include <warden>
#include <myjailbreak>
#include <myweapons>
#define REQUIRE_PLUGIN

// Compiler Options
#pragma semicolon 1
#pragma newdecls required

// Booleans
bool g_bIsLateLoad = false;
bool g_bIsCowBoy = false;
bool g_bStartCowBoy = false;
bool g_bIsRoundEnd = true;

// Plugin bools
bool gp_bWarden;
bool gp_bHosties;
bool gp_bMyJailbreak;
bool gp_bMyWeapons;

// Console Variables
ConVar gc_bPlugin;
ConVar gc_bSetW;
ConVar gc_iCooldownStart;
ConVar gc_bSetA;
ConVar gc_bSetABypassCooldown;
ConVar gc_bVote;
ConVar gc_fBeaconTime;
ConVar gc_iWeapon;
ConVar gc_bRandom;
ConVar gc_iCooldownDay;
ConVar gc_iRoundTime;
ConVar gc_iTruceTime;
ConVar gc_bOverlays;
ConVar gc_bSoundsHit;
ConVar gc_sOverlayStartPath;
ConVar gc_bSounds;
ConVar gc_sSoundStartPath;
ConVar gc_iRounds;
ConVar gc_sAdminFlag;
ConVar gc_bAllowLR;
ConVar gc_sCustomCommandVote;
ConVar gc_sCustomCommandSet;

ConVar gc_bBeginSetA;
ConVar gc_bBeginSetW;
ConVar gc_bBeginSetV;
ConVar gc_bBeginSetVW;


// Extern Convars
//ConVar g_iMPRoundTime;
ConVar g_iTerrorForLR;

// Integers
//int g_iOldRoundTime;
int g_iCoolDown;
int g_iTruceTime;
int g_iVoteCount;
int g_iRound;
int g_iMaxRound;
int g_iTsLR;
int g_iCollision_Offset;

// Handles
Handle g_hTimerTruce;
Handle g_hTimerBeacon;

// Floats
float g_fPos[3];

// Strings
char g_sHasVoted[1500];
char g_sSoundStartPath[256];
char g_sWeapon[32];
char g_sEventsLogFile[PLATFORM_MAX_PATH];
char g_sAdminFlag[64];
char g_sOverlayStartPath[256];

// Info
public Plugin myinfo = {
	name = "MyJailbreak - CowBoy",
	author = "shanapu",
	description = "Event Day for Jailbreak Server",
	version = MYJB_VERSION,
	url = MYJB_URL_LINK
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bIsLateLoad = late;

	return APLRes_Success;
}

// Start
public void OnPluginStart()
{
	// Translation
	LoadTranslations("MyJailbreak.Warden.phrases");
	LoadTranslations("MyJailbreak.CowBoy.phrases");

	// Client Commands
	RegConsoleCmd("sm_setcowboy", Command_SetCowBoy, "Allows the Admin or Warden to set cowboy as next round");
	RegConsoleCmd("sm_cowboy", Command_VoteCowBoy, "Allows players to vote for a cowboy");

	// AutoExecConfig
	AutoExecConfig_SetFile("cowboy", "myjailbreak/eventdays");
	AutoExecConfig_SetCreateFile(true);

	AutoExecConfig_CreateConVar("sm_cowboy_version", MYJB_VERSION, "The version of this MyJailbreak SourceMod plugin", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gc_bPlugin = AutoExecConfig_CreateConVar("sm_cowboy_enable", "1", "0 - disabled, 1 - enable this MyJailbreak SourceMod plugin", _, true, 0.0, true, 1.0);
	gc_sCustomCommandVote = AutoExecConfig_CreateConVar("sm_cowboy_cmds_vote", "cow", "Set your custom chat command for Event voting(!cowboy (no 'sm_'/'!')(seperate with comma ', ')(max. 12 commands))");
	gc_sCustomCommandSet = AutoExecConfig_CreateConVar("sm_cowboy_cmds_set", "scow, setcow", "Set your custom chat command for set Event (!setcowboy (no 'sm_'/'!')(seperate with comma ', ')(max. 12 commands))");
	gc_bSetW = AutoExecConfig_CreateConVar("sm_cowboy_warden", "1", "0 - disabled, 1 - allow warden to set cowboy round", _, true, 0.0, true, 1.0);
	gc_bSetA = AutoExecConfig_CreateConVar("sm_cowboy_admin", "1", "0 - disabled, 1 - allow admin/vip to set cowboy round", _, true, 0.0, true, 1.0);
	gc_sAdminFlag = AutoExecConfig_CreateConVar("sm_cowboy_flag", "g", "Set flag for admin/vip to set this Event Day.");
	gc_bVote = AutoExecConfig_CreateConVar("sm_cowboy_vote", "1", "0 - disabled, 1 - allow player to vote for cowboy", _, true, 0.0, true, 1.0);

	gc_bBeginSetA = AutoExecConfig_CreateConVar("sm_cowboy_begin_admin", "1", "When admin set event (!setcowboy) = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);
	gc_bBeginSetW = AutoExecConfig_CreateConVar("sm_cowboy_begin_warden", "1", "When warden set event (!setcowboy) = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);
	gc_bBeginSetV = AutoExecConfig_CreateConVar("sm_cowboy_begin_vote", "0", "When users vote for event (!cowboy) = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);
	gc_bBeginSetVW = AutoExecConfig_CreateConVar("sm_cowboy_begin_daysvote", "0", "When warden/admin start eventday voting (!sm_voteday) and event wins = 0 - start event next round, 1 - start event current round", _, true, 0.0, true, 1.0);

	gc_iRounds = AutoExecConfig_CreateConVar("sm_cowboy_rounds", "1", "Rounds to play in a row", _, true, 1.0);
	gc_iWeapon = AutoExecConfig_CreateConVar("sm_cowboy_weapon", "1", "1 - Revolver / 2 - Dual Barettas", _, true, 1.0, true, 2.0);
	gc_bRandom = AutoExecConfig_CreateConVar("sm_cowboy_random", "1", "get a random weapon (revolver, duals) ignore: sm_cowboy_weapon", _, true, 0.0, true, 1.0);
	gc_iRoundTime = AutoExecConfig_CreateConVar("sm_cowboy_roundtime", "5", "Round time in minutes for a single cowboy round", _, true, 1.0);
	gc_fBeaconTime = AutoExecConfig_CreateConVar("sm_cowboy_beacon_time", "240", "Time in seconds until the beacon turned on (set to 0 to disable)", _, true, 0.0);
	gc_iTruceTime = AutoExecConfig_CreateConVar("sm_cowboy_trucetime", "15", "Time in seconds players can't deal damage", _, true, 0.0);
	gc_iCooldownDay = AutoExecConfig_CreateConVar("sm_cowboy_cooldown_day", "3", "Rounds cooldown after a event until event can be start again", _, true, 0.0);
	gc_iCooldownStart = AutoExecConfig_CreateConVar("sm_cowboy_cooldown_start", "3", "Rounds until event can be start after mapchange.", _, true, 0.0);
	gc_bSetABypassCooldown = AutoExecConfig_CreateConVar("sm_cowboy_cooldown_admin", "1", "0 - disabled, 1 - ignore the cooldown when admin/vip set cowboy round", _, true, 0.0, true, 1.0);
	gc_bSounds = AutoExecConfig_CreateConVar("sm_cowboy_sounds_enable", "1", "0 - disabled, 1 - enable sounds ", _, true, 0.1, true, 1.0);
	gc_sSoundStartPath = AutoExecConfig_CreateConVar("sm_cowboy_sounds_start", "music/myjailbreak/Yeehaw.mp3", "Path to the soundfile which should be played for a start.");
	gc_bSoundsHit = AutoExecConfig_CreateConVar("sm_cowboy_sounds_bling", "1", "0 - disabled, 1 - enable bling - hitsound sounds ", _, true, 0.1, true, 1.0);
	gc_bOverlays = AutoExecConfig_CreateConVar("sm_cowboy_overlays_enable", "1", "0 - disabled, 1 - enable overlays", _, true, 0.0, true, 1.0);
	gc_sOverlayStartPath = AutoExecConfig_CreateConVar("sm_cowboy_overlays_start", "overlays/myjailbreak/start", "Path to the start Overlay DONT TYPE .vmt or .vft");
	gc_bAllowLR = AutoExecConfig_CreateConVar("sm_cowboy_allow_lr", "0", "0 - disabled, 1 - enable LR for last round and end eventday", _, true, 0.0, true, 1.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	// Hooks
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookConVarChange(gc_sOverlayStartPath, OnSettingChanged);
	HookConVarChange(gc_sSoundStartPath, OnSettingChanged);
	HookConVarChange(gc_sAdminFlag, OnSettingChanged);

	// Find
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iTruceTime = gc_iTruceTime.IntValue;
//	g_iMPRoundTime = FindConVar("mp_roundtime");
	gc_sOverlayStartPath.GetString(g_sOverlayStartPath, sizeof(g_sOverlayStartPath));
	gc_sSoundStartPath.GetString(g_sSoundStartPath, sizeof(g_sSoundStartPath));
	gc_sAdminFlag.GetString(g_sAdminFlag, sizeof(g_sAdminFlag));

	// Offsets
	g_iCollision_Offset = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");

	//Logs
	SetLogFile(g_sEventsLogFile, "events", "myjailbreak");

	// Late loading
	if (g_bIsLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}

		g_bIsLateLoad = false;
	}
}

// ConVarChange for Strings
public void OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gc_sOverlayStartPath)
	{
		strcopy(g_sOverlayStartPath, sizeof(g_sOverlayStartPath), newValue);
		if (gc_bOverlays.BoolValue)
		{
			PrecacheDecalAnyDownload(g_sOverlayStartPath);
		}
	}
	else if (convar == gc_sSoundStartPath)
	{
		strcopy(g_sSoundStartPath, sizeof(g_sSoundStartPath), newValue);
		if (gc_bSounds.BoolValue)
		{
			PrecacheSoundAnyDownload(g_sSoundStartPath);
		}
	}
	else if (convar == gc_sAdminFlag)
	{
		strcopy(g_sAdminFlag, sizeof(g_sAdminFlag), newValue);
	}
}

public void OnAllPluginsLoaded()
{
	gp_bWarden = LibraryExists("warden");
	gp_bHosties = LibraryExists("lastrequest");

	gp_bMyJailbreak = LibraryExists("myjailbreak");
	gp_bMyWeapons = LibraryExists("myweapons");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "warden"))
		gp_bWarden = false;

	if (StrEqual(name, "lastrequest"))
		gp_bHosties = false;




	if (StrEqual(name, "myjailbreak"))
		gp_bMyJailbreak = false;

	if (StrEqual(name, "myweapons"))
		gp_bMyWeapons = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "warden"))
		gp_bWarden = true;

	if (StrEqual(name, "lastrequest"))
		gp_bHosties = true;




	if (StrEqual(name, "myjailbreak"))
		gp_bMyJailbreak = true;

	if (StrEqual(name, "myweapons"))
		gp_bMyWeapons = true;
}

// Initialize Plugin
public void OnConfigsExecuted()
{
	g_iTruceTime = gc_iTruceTime.IntValue;
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iMaxRound = gc_iRounds.IntValue;

	if (gc_iWeapon.IntValue == 1)
	{
		g_sWeapon = "weapon_revolver";
	}

	if (gc_iWeapon.IntValue == 2)
	{
		g_sWeapon = "weapon_elite";
	}

	// FindConVar
	if (gp_bHosties)
	{
		g_iTerrorForLR = FindConVar("sm_hosties_lr_ts_max");
	}

	// Set custom Commands
	int iCount = 0;
	char sCommands[128], sCommandsL[12][32], sCommand[32];

	// vote
	gc_sCustomCommandVote.GetString(sCommands, sizeof(sCommands));
	ReplaceString(sCommands, sizeof(sCommands), " ", "");
	iCount = ExplodeString(sCommands, ",", sCommandsL, sizeof(sCommandsL), sizeof(sCommandsL[]));

	for (int i = 0; i < iCount; i++)
	{
		Format(sCommand, sizeof(sCommand), "sm_%s", sCommandsL[i]);
		if (GetCommandFlags(sCommand) == INVALID_FCVAR_FLAGS)  // if command not already exist
		{
			RegConsoleCmd(sCommand, Command_VoteCowBoy, "Allows players to vote for a cowboy");
		}
	}

	// set
	gc_sCustomCommandSet.GetString(sCommands, sizeof(sCommands));
	ReplaceString(sCommands, sizeof(sCommands), " ", "");
	iCount = ExplodeString(sCommands, ",", sCommandsL, sizeof(sCommandsL), sizeof(sCommandsL[]));

	for (int i = 0; i < iCount; i++)
	{
		Format(sCommand, sizeof(sCommand), "sm_%s", sCommandsL[i]);
		if (GetCommandFlags(sCommand) == INVALID_FCVAR_FLAGS)  // if command not already exist
		{
			RegConsoleCmd(sCommand, Command_SetCowBoy, "Allows the Admin or Warden to set cowboy as next round");
		}
	}
}

/******************************************************************************
                   COMMANDS
******************************************************************************/

// Admin & Warden set Event
public Action Command_SetCowBoy(int client, int args)
{
	if (!gc_bPlugin.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_disabled");
		return Plugin_Handled;
	}

	if (client == 0)
	{
		StartEventRound(gc_bBeginSetVW.BoolValue);

		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}

		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event CowBoy was started by groupvoting");
		}
	}
	else if (CheckVipFlag(client, g_sAdminFlag)) // Called by admin/VIP
	{
		if (!gc_bSetA.BoolValue)
		{
			CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_setbyadmin");
			return Plugin_Handled;
		}

		if (GetTeamClientCount(CS_TEAM_CT) == 0 || GetTeamClientCount(CS_TEAM_T) == 0)
		{
			CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_minplayer");
			return Plugin_Handled;
		}

		if (gp_bMyJailbreak)
		{
			char EventDay[64];
			MyJailbreak_GetEventDayName(EventDay);

			if (!StrEqual(EventDay, "none", false))
			{
				CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_progress", EventDay);
				return Plugin_Handled;
			}
		}

		if (g_iCoolDown > 0 && !gc_bSetABypassCooldown.BoolValue)
		{
			CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_wait", g_iCoolDown);
			return Plugin_Handled;
		}

		StartEventRound(gc_bBeginSetA.BoolValue);

		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}

		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event CowBoy was started by admin %L", client);
		}
	}
	else if (gp_bWarden) // Called by warden
	{
		if (!warden_iswarden(client))
		{
			CReplyToCommand(client, "%t %t", "warden_tag", "warden_notwarden");
			return Plugin_Handled;
		}

		if (!gc_bSetW.BoolValue)
		{
			CReplyToCommand(client, "%t %t", "warden_tag", "cowboy_setbywarden");
			return Plugin_Handled;
		}

		if (GetTeamClientCount(CS_TEAM_CT) == 0 || GetTeamClientCount(CS_TEAM_T) == 0)
		{
			CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_minplayer");
			return Plugin_Handled;
		}

		if (gp_bMyJailbreak)
		{
			char EventDay[64];
			MyJailbreak_GetEventDayName(EventDay);

			if (!StrEqual(EventDay, "none", false))
			{
				CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_progress", EventDay);
				return Plugin_Handled;
			}
		}

		if (g_iCoolDown > 0)
		{
			CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_wait", g_iCoolDown);
			return Plugin_Handled;
		}

		StartEventRound(gc_bBeginSetW.BoolValue);

		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}

		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event CowBoy was started by warden %L", client);
		}
	}
	else
	{
		CReplyToCommand(client, "%t %t", "warden_tag", "warden_notwarden");
	}

	return Plugin_Handled;
}

// Voting for Event
public Action Command_VoteCowBoy(int client, int args)
{
	if (!gc_bPlugin.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_disabled");
		return Plugin_Handled;
	}

	if (!gc_bVote.BoolValue)
	{
		CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_voting");
		return Plugin_Handled;
	}

	if (GetTeamClientCount(CS_TEAM_CT) == 0 || GetTeamClientCount(CS_TEAM_T) == 0)
	{
		CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_minplayer");
		return Plugin_Handled;
	}

	if (gp_bMyJailbreak)
	{
		char EventDay[64];
		MyJailbreak_GetEventDayName(EventDay);

		if (!StrEqual(EventDay, "none", false))
		{
			CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_progress", EventDay);
			return Plugin_Handled;
		}
	}

	if (g_iCoolDown > 0)
	{
		CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_wait", g_iCoolDown);
		return Plugin_Handled;
	}

	char steamid[24];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

	if (StrContains(g_sHasVoted, steamid, true) != -1)
	{
		CReplyToCommand(client, "%t %t", "cowboy_tag", "cowboy_voted");
		return Plugin_Handled;
	}

	int playercount = (GetClientCount(true) / 2);
	g_iVoteCount += 1;

	int Missing = playercount - g_iVoteCount + 1;
	Format(g_sHasVoted, sizeof(g_sHasVoted), "%s, %s", g_sHasVoted, steamid);

	if (g_iVoteCount > playercount)
	{
		StartEventRound(gc_bBeginSetV.BoolValue);

		if (!gp_bMyJailbreak)
		{
			return Plugin_Handled;
		}

		if (MyJailbreak_ActiveLogging())
		{
			LogToFileEx(g_sEventsLogFile, "Event CowBoy was started by voting");
		}
	}
	else
	{
		CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_need", Missing, client);
	}

	return Plugin_Handled;
}

/******************************************************************************
                   EVENTS
******************************************************************************/

// Round start
public void Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	g_bIsRoundEnd = false;

	if (!g_bStartCowBoy && !g_bIsCowBoy)
	{
		if (gp_bMyJailbreak)
		{
			char EventDay[64];
			MyJailbreak_GetEventDayName(EventDay);

			if (!StrEqual(EventDay, "none", false))
			{
				g_iCoolDown = gc_iCooldownDay.IntValue + 1;
			}
			else if (g_iCoolDown > 0)
			{
				g_iCoolDown -= 1;
			}
		}
		else if (g_iCoolDown > 0)
		{
			g_iCoolDown -= 1;
		}

		return;
	}

	g_bIsCowBoy = true;
	g_bStartCowBoy = false;

	PrepareDay(false);
}

// Round End
public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	g_bIsRoundEnd = true;

	if (g_bIsCowBoy)
	{
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
		{
			SetEntData(i, g_iCollision_Offset, 0, 4, true);
		}

		delete g_hTimerTruce;
		delete g_hTimerBeacon;

		int winner = event.GetInt("winner");
		if (winner == 2)
		{
			PrintCenterTextAll("%t", "cowboy_twin_nc");
		}
		if (winner == 3)
		{
			PrintCenterTextAll("%t", "cowboy_ctwin_nc");
		}

		if (g_iRound == g_iMaxRound)
		{
			g_bIsCowBoy = false;
			g_bStartCowBoy = false;
			g_iRound = 0;
			Format(g_sHasVoted, sizeof(g_sHasVoted), "");

			if (gp_bHosties)
			{
				SetCvar("sm_hosties_lr", 1);
			}

			if (gp_bWarden)
			{
				SetCvar("sm_warden_enable", 1);
			}

			if (gp_bMyWeapons)
			{
				MyWeapons_AllowTeam(CS_TEAM_T, false);
				MyWeapons_AllowTeam(CS_TEAM_CT, true);
			}

			if (gp_bMyJailbreak)
			{
				SetCvar("sm_menu_enable", 1);

				MyJailbreak_SetEventDayRunning(false, winner);
				MyJailbreak_SetEventDayName("none");
			}

			SetCvar("sv_infinite_ammo", 0);
			SetCvar("mp_teammates_are_enemies", 0);

//			g_iMPRoundTime.IntValue = g_iOldRoundTime;

			CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_end");
		}
	}

	if (g_bStartCowBoy)
	{
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
		{
			CreateInfoPanel(i);
		}

		CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_next");
		PrintCenterTextAll("%t", "cowboy_next_nc");
	}
}

// ding sound
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (gc_bSoundsHit.BoolValue && g_bIsCowBoy)
	{
		Handle data; // Delay it to a frame later. If we use IsPlayerAlive(victim) here, it would always return true.
		CreateDataTimer(0.0, Timer_Hitsound, data, TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(data, event.GetInt("attacker"));
		WritePackCell(data, event.GetInt("userid"));
		ResetPack(data);
	}
}

/******************************************************************************
                   FORWARDS LISTEN
******************************************************************************/

// Initialize Event
public void OnMapStart()
{
	g_iVoteCount = 0;
	g_iRound = 0;
	g_bIsCowBoy = false;
	g_bStartCowBoy = false;

	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iTruceTime = gc_iTruceTime.IntValue;

	if (gc_bSounds.BoolValue)
	{
		PrecacheSoundAnyDownload(g_sSoundStartPath);   // Add sound to download and precache table
	}

	if (gc_bOverlays.BoolValue)
	{
		PrecacheDecalAnyDownload(g_sOverlayStartPath);   // Add overlay to download and precache table
	}
}

// Map End
public void OnMapEnd()
{
	g_bIsCowBoy = false;
	g_bStartCowBoy = false;

	delete g_hTimerTruce;
	delete g_hTimerBeacon;

	g_iVoteCount = 0;
	g_iRound = 0;
	g_sHasVoted[0] = '\0';
}

// Listen for Last Lequest
public void OnAvailableLR(int Announced)
{
	if (g_bIsCowBoy && gc_bAllowLR.BoolValue && (g_iTsLR > g_iTerrorForLR.IntValue))
	{
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
		{
			SetEntData(i, g_iCollision_Offset, 0, 4, true);

			StripAllPlayerWeapons(i);

			if (GetClientTeam(i) == CS_TEAM_CT)
			{
				FakeClientCommand(i, "sm_weapons");
			}

			GivePlayerItem(i, "weapon_knife");
		}

		delete g_hTimerBeacon;
		delete g_hTimerTruce;

		if (g_iRound == g_iMaxRound)
		{
			g_bIsCowBoy = false;
			g_bStartCowBoy = false;
			g_iRound = 0;
			Format(g_sHasVoted, sizeof(g_sHasVoted), "");

			if (gp_bMyWeapons)
			{
				MyWeapons_AllowTeam(CS_TEAM_T, false);
				MyWeapons_AllowTeam(CS_TEAM_CT, true);
			}

			if (gp_bWarden)
			{
				SetCvar("sm_warden_enable", 1);
			}

			if (gp_bMyJailbreak)
			{
				SetCvar("sm_menu_enable", 1);

				MyJailbreak_SetEventDayName("none");
				MyJailbreak_SetEventDayRunning(false, 0);
			}

			SetCvar("sm_hosties_lr", 1);
			SetCvar("sv_infinite_ammo", 0);
			SetCvar("mp_teammates_are_enemies", 0);

//			g_iMPRoundTime.IntValue = g_iOldRoundTime;

			CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_end");
		}
	}
}

// Set Client Hook
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

// Scout only
public Action OnWeaponCanUse(int client, int weapon)
{
	if (g_bIsCowBoy)
	{
		char sWeapon[32];
		GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

		int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

		if (index == 64 || (StrEqual(sWeapon, "weapon_elite")))
			return Plugin_Continue;
		else return Plugin_Handled;
	}

	return Plugin_Continue;
}

/******************************************************************************
                   FUNCTIONS
******************************************************************************/

// Prepare Event
void StartEventRound(bool thisround)
{
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iVoteCount = 0;

	if (gp_bMyJailbreak)
	{
		char buffer[32];
		Format(buffer, sizeof(buffer), "%T", "cowboy_name", LANG_SERVER);
		MyJailbreak_SetEventDayName(buffer);
		MyJailbreak_SetEventDayPlanned(true);
	}

	if(thisround && g_bIsRoundEnd)
	{
		thisround = false;
	}

	if (thisround)
	{
		g_bIsCowBoy = true;

		for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i, true, false))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);

			SetEntityMoveType(i, MOVETYPE_NONE);
		}

		CreateTimer(3.0, Timer_PrepareEvent);

		CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_now");
		PrintCenterTextAll("%t", "cowboy_now_nc");
	}
	else
	{
		g_bStartCowBoy = true;
		g_iCoolDown++;

		CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_next");
		PrintCenterTextAll("%t", "cowboy_next_nc");
	}
}

public Action Timer_PrepareEvent(Handle timer)
{
	PrepareDay(true);
}

void PrepareDay(bool thisround)
{
	g_iRound++;

	if (thisround)
	{
		int RandomCT = 0;
		for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == CS_TEAM_CT)
			{
				CS_RespawnPlayer(i);
				RandomCT = i;
				break;
			}
		}

		if (RandomCT)
		{
			for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
			{
				GetClientAbsOrigin(RandomCT, g_fPos);
				
				g_fPos[2] = g_fPos[2] + 5;
				
				TeleportEntity(i, g_fPos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}

	if (gc_bRandom.BoolValue)
	{
		int randomnum = GetRandomInt(0, 1);

		if (randomnum == 0)
		{
			g_sWeapon = "weapon_revolver";
		}
		if (randomnum == 1)
		{
			g_sWeapon = "weapon_elite";
		}
	}

	for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
	{
		SetEntData(i, g_iCollision_Offset, 2, 4, true);

		SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);

		SetEntityMoveType(i, MOVETYPE_NONE);

		CreateInfoPanel(i);

		StripAllPlayerWeapons(i);
		GivePlayerItem(i, g_sWeapon);
	}

	if (gp_bMyJailbreak)
	{
		SetCvar("sm_menu_enable", 0);

		MyJailbreak_SetEventDayPlanned(false);
		MyJailbreak_SetEventDayRunning(true, 0);

		if (gc_fBeaconTime.FloatValue > 0.0)
		{
			g_hTimerBeacon = CreateTimer(gc_fBeaconTime.FloatValue, Timer_BeaconOn, TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	if (gp_bWarden)
	{
		SetCvar("sm_warden_enable", 0);
	}

	if (gp_bHosties)
	{
		SetCvar("sm_hosties_lr", 0);
	}

	if (gp_bMyWeapons)
	{
		MyWeapons_AllowTeam(CS_TEAM_T, false);
		MyWeapons_AllowTeam(CS_TEAM_CT, false);
	}

	if (gp_bHosties)
	{
		// enable lr on last round
		g_iTsLR = GetAlivePlayersCount(CS_TEAM_T);

		if (gc_bAllowLR.BoolValue)
		{
			if (g_iRound == g_iMaxRound && g_iTsLR > g_iTerrorForLR.IntValue)
			{
				SetCvar("sm_hosties_lr", 1);
			}
		}
	}

	CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_rounds", g_iRound, g_iMaxRound);

	GameRules_SetProp("m_iRoundTime", gc_iRoundTime.IntValue*60, 4, 0, true);

	SetCvar("sv_infinite_ammo", 2);
	SetCvar("mp_teammates_are_enemies", 1);

	g_hTimerTruce = CreateTimer(1.0, Timer_StartEvent, _, TIMER_REPEAT);
}



/******************************************************************************
                   MENUS
******************************************************************************/

void CreateInfoPanel(int client)
{
	// Create info Panel
	char info[255];

	Panel InfoPanel = new Panel();

	Format(info, sizeof(info), "%T", "cowboy_info_title", client);
	InfoPanel.SetTitle(info);

	InfoPanel.DrawText("                                   ");
	Format(info, sizeof(info), "%T", "cowboy_info_line1", client);
	InfoPanel.DrawText(info);
	InfoPanel.DrawText("-----------------------------------");
	Format(info, sizeof(info), "%T", "cowboy_info_line2", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "cowboy_info_line3", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "cowboy_info_line4", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "cowboy_info_line5", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "cowboy_info_line6", client);
	InfoPanel.DrawText(info);
	Format(info, sizeof(info), "%T", "cowboy_info_line7", client);
	InfoPanel.DrawText(info);
	InfoPanel.DrawText("-----------------------------------");

	Format(info, sizeof(info), "%T", "warden_close", client);
	InfoPanel.DrawItem(info);

	InfoPanel.Send(client, Handler_NullCancel, 20);
}

/******************************************************************************
                   TIMER
******************************************************************************/

// Start Timer
public Action Timer_StartEvent(Handle timer)
{
	if (g_iTruceTime > 0)
	{
		g_iTruceTime--;

		if (g_iTruceTime == gc_iTruceTime.IntValue-3)
		{
			for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i, true, false))
			{
				SetEntityMoveType(i, MOVETYPE_WALK);
			}
		}

		PrintCenterTextAll("%t", "cowboy_timeuntilstart_nc", g_iTruceTime);

		return Plugin_Continue;
	}

	g_iTruceTime = gc_iTruceTime.IntValue;

	for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i, true, false))
	{
		SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
		if (gc_bOverlays.BoolValue)
		{
			ShowOverlay(i, g_sOverlayStartPath, 2.0);
		}
	}

	if (gc_bSounds.BoolValue)
	{
		EmitSoundToAllAny(g_sSoundStartPath);
	}

	PrintCenterTextAll("%t", "cowboy_start_nc");

	CPrintToChatAll("%t %t", "cowboy_tag", "cowboy_start");

	g_hTimerTruce = null;

	return Plugin_Stop;
}

public Action Timer_BeaconOn(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i, true, false)) 
	{
		MyJailbreak_BeaconOn(i, 2.0);
	}

	g_hTimerBeacon = null;
}

public Action Timer_Hitsound(Handle timer, Handle data)
{
	int attacker	= GetClientOfUserId(ReadPackCell(data));
	int victim		= GetClientOfUserId(ReadPackCell(data));

	if (attacker <= 0 || attacker > MaxClients || victim <= 0 || victim > MaxClients || attacker == victim) 
		return;
	ClientCommand(attacker, "playgamesound training/bell_normal.wav");
}