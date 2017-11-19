/*
 * MyJailbreak - Warden - No Block Module.
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
#include <colors>
#include <autoexecconfig>
#include <warden>
#include <mystocks>

// Compiler Options
#pragma semicolon 1
#pragma newdecls required

// Console Variables
ConVar gc_bNoBlock;
ConVar gc_bNoBlockDeputy;
ConVar gc_sCustomCommandNoBlock;


// Booleans
bool g_bNoBlock = true;

// Integers
int g_iCollision_Offset;

// Start
public void NoBlock_OnPluginStart()
{
	// Client commands
	RegConsoleCmd("sm_noblock", Command_ToggleNoBlock, "Allows the Warden to toggle no block");

	// AutoExecConfig
	gc_bNoBlock = AutoExecConfig_CreateConVar("sm_warden_noblock", "1", "0 - disabled, 1 - enable noblock toggle for warden", _, true, 0.0, true, 1.0);
	gc_bNoBlockDeputy = AutoExecConfig_CreateConVar("sm_warden_noblock_deputy", "1", "0 - disabled, 1 - enable noblock toggle for deputy, too", _, true, 0.0, true, 1.0);
	gc_sCustomCommandNoBlock = AutoExecConfig_CreateConVar("sm_warden_cmds_noblock", "block, unblock, collision", "Set your custom chat command for toggle no block (!noblock (no 'sm_'/'!')(seperate with comma ', ')(max. 12 commands))");

	// Offsets
	g_iCollision_Offset = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
}

/******************************************************************************
                   COMMANDS
******************************************************************************/

public Action Command_ToggleNoBlock(int client, int args)
{
	if (gc_bNoBlock.BoolValue) 
	{
		if (IsClientWarden(client) || (IsClientDeputy(client) && gc_bNoBlockDeputy.BoolValue))
		{
			if (!g_bNoBlock) 
			{
				g_bNoBlock = true;
				CPrintToChatAll("%t %t", "warden_tag", "warden_noblockon");
				for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i, true, true))
				{
					SetEntData(i, g_iCollision_Offset, 2, 4, true);
				}
			}
			else
			{
				g_bNoBlock = false;
				CPrintToChatAll("%t %t", "warden_tag", "warden_noblockoff");
				for (int i = 1; i <= MaxClients; i++) if (IsValidClient(i, true, true))
				{
					SetEntData(i, g_iCollision_Offset, 5, 4, true);
				}
			}
		}
		else CReplyToCommand(client, "%t %t", "warden_tag", "warden_notwarden");
	}

	return Plugin_Handled;
}

/******************************************************************************
                   FORWARDS LISTENING
******************************************************************************/

public void NoBlock_OnConfigsExecuted()
{
	// Set custom Commands
	int iCount = 0;
	char sCommands[128], sCommandsL[12][32], sCommand[32];

	// No Block
	gc_sCustomCommandNoBlock.GetString(sCommands, sizeof(sCommands));
	ReplaceString(sCommands, sizeof(sCommands), " ", "");
	iCount = ExplodeString(sCommands, ",", sCommandsL, sizeof(sCommandsL), sizeof(sCommandsL[]));

	for (int i = 0; i < iCount; i++)
	{
		Format(sCommand, sizeof(sCommand), "sm_%s", sCommandsL[i]);
		if (GetCommandFlags(sCommand) == INVALID_FCVAR_FLAGS)  // if command not already exist
			RegConsoleCmd(sCommand, Command_ToggleNoBlock, "Allows the Warden to toggle no block");
	}
}