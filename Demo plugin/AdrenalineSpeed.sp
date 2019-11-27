/*  
*    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <weaponhandling>

#pragma semicolon 1

#pragma newdecls required

#define PLUGIN_VERSION "1.0"

static float g_fAdrenSpeedUp;
static float g_fAdrenSpeedUpTime;
static float g_fPillsSpeedUp;
static float g_fPillsSpeedUpTime;

static bool g_bScaleAutoWeapons;

static ConVar hCvar_AdrenSpeedUp;
static ConVar hCvar_AdrenSpeedUpTime;
static ConVar hCvar_PillsSpeedUp;
static ConVar hCvar_PillsSpeedUpTime;

static ConVar hCvar_ScaleAutoWeapons;

static float g_fAdrenalineUseTime[MAXPLAYERS+1];
static float g_fPillsUseTime[MAXPLAYERS+1];

bool g_bIsL4D2;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion iEngineVersion = GetEngineVersion();
	if(iEngineVersion == Engine_Left4Dead2)
	{
		g_bIsL4D2 = true;
	}
	else if(iEngineVersion == Engine_Left4Dead)
	{
		g_bIsL4D2 = false;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1/2");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "AdrenalineSpeed",
	author = "Lux",
	description = "Speedup weapon handling with adrenaline & pills!",
	version = PLUGIN_VERSION,
	url = "-"
};


public void OnPluginStart()
{
	CreateConVar("adrenalinespeed_version", PLUGIN_VERSION, "", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_AdrenSpeedUp = CreateConVar("as_adrenaline_speedup_multiplier", "1.6", "", FCVAR_NOTIFY, true, 0.0001, true, 100.0);
	hCvar_AdrenSpeedUpTime = CreateConVar("as_adrenaline_speedup_time", "15.0", "", FCVAR_NOTIFY, true, 0.0001);
	
	hCvar_PillsSpeedUp = CreateConVar("as_pills_speedup_multiplier", "1.2", "", FCVAR_NOTIFY, true, 0.0001, true, 100.0);
	hCvar_PillsSpeedUpTime = CreateConVar("as_Pills_speedup_time", "45.0", "", FCVAR_NOTIFY, true, 0.0001);
	
	hCvar_ScaleAutoWeapons = CreateConVar("as_scale_automatic_weapons", "0", "1 = (Allow scaling firerate of automatic weapons e.g. smg, rifle, ect) 0 = (don't scale firerate of automatic weapons)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	hCvar_AdrenSpeedUp.AddChangeHook(eConvarChanged);
	hCvar_AdrenSpeedUpTime.AddChangeHook(eConvarChanged);
	hCvar_PillsSpeedUp.AddChangeHook(eConvarChanged);
	hCvar_PillsSpeedUpTime.AddChangeHook(eConvarChanged);
	hCvar_ScaleAutoWeapons.AddChangeHook(eConvarChanged);
	
	if(g_bIsL4D2)
	{
		HookEvent("adrenaline_used", eAdrenalineUsed);
	}
	HookEvent("pills_used", ePillsUsed);
	HookEvent("player_spawn", ePlayerSpawn);
	
	CvarsChanged();
	AutoExecConfig(true, "AdrenalineSpeed");
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	g_fAdrenSpeedUp = hCvar_AdrenSpeedUp.FloatValue;
	g_fAdrenSpeedUpTime = hCvar_AdrenSpeedUpTime.FloatValue;
	g_fPillsSpeedUp = hCvar_PillsSpeedUp.FloatValue;
	g_fPillsSpeedUpTime = hCvar_PillsSpeedUpTime.FloatValue;
	g_bScaleAutoWeapons = hCvar_ScaleAutoWeapons.IntValue > 0;
}

//WeaponHandling forwards

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	speedmodifier = PillsOrAdrenModifier(client, speedmodifier);
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = PillsOrAdrenModifier(client, speedmodifier);
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = PillsOrAdrenModifier(client, speedmodifier);
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = PillsOrAdrenModifier(client, speedmodifier);
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	switch(weapontype)
	{
		case L4D2WeaponType_Rifle, L4D2WeaponType_RifleDesert, L4D2WeaponType_RifleSg552, 
			L4D2WeaponType_SMG, L4D2WeaponType_RifleAk47, L4D2WeaponType_SMGMp5, 
			L4D2WeaponType_SMGSilenced, L4D2WeaponType_RifleM60:
		{
			if(!g_bScaleAutoWeapons)
				return;
		}
	}
	
	speedmodifier = PillsOrAdrenModifier(client, speedmodifier);
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	speedmodifier = PillsOrAdrenModifier(client, speedmodifier);
}

float PillsOrAdrenModifier(int iClient, float speedmodifier)
{
	if(g_fAdrenalineUseTime[iClient] > GetGameTime()) 
	{
		speedmodifier = speedmodifier * g_fAdrenSpeedUp;// multiply current modifier
	}
	else if(g_fPillsUseTime[iClient] > GetGameTime()) 
	{
		speedmodifier = speedmodifier * g_fPillsSpeedUp;
	}
	return speedmodifier;
}

//credit timocop

#define INSTRUCTOR_HINT_ICON_TIP 						"icon_tip"
#define INSTRUCTOR_HINT_ICON_INFO 						"icon_info"
#define INSTRUCTOR_HINT_ICON_SHIELD 					"icon_shield"
#define INSTRUCTOR_HINT_ICON_ALERT 						"icon_alert"
#define INSTRUCTOR_HINT_ICON_ALERT_RED 					"icon_alert_red"
#define INSTRUCTOR_HINT_ICON_SKULL 						"icon_skull"
#define INSTRUCTOR_HINT_ICON_NO 						"icon_no"
#define INSTRUCTOR_HINT_ICON_INTERACT 					"icon_interact"
#define INSTRUCTOR_HINT_ICON_BUTTON 					"icon_button"
#define INSTRUCTOR_HINT_ICON_DOOR 						"icon_door"
#define INSTRUCTOR_HINT_ICON_ARROW_PLAIN 				"icon_arrow_plain"
#define INSTRUCTOR_HINT_ICON_ARROW_PLAIN_WHITE_DOWN 	"icon_arrow_plain_white_dn"
#define INSTRUCTOR_HINT_ICON_ARROW_PLAIN_WHITE_UP 		"icon_arrow_plain_white_up"
#define INSTRUCTOR_HINT_ICON_ARROW_UP 					"icon_arrow_up"

enum InstructorHintType {
	InstructorHintType_Normal = 0,
	InstructorHintType_SingleOpen,		//Prevents new hints from opening
	InstructorHintType_FixedReplace,	//Ends other hints when a new one is shown
	InstructorHintType_SingleActive,	//Hides other hints when a new one is shown
}

stock int DisplayInstructorHint(int iClient, int iTarget=-1, const char[] sName, const char sText[100], const char[] sBind="", int iTimeout=5, const char[] sIcon=INSTRUCTOR_HINT_ICON_TIP, const char[] sColour="255 255 255", int iHintRange=1000, InstructorHintType iType=InstructorHintType_Normal)
{
	if(iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient) || IsFakeClient(iClient))
		return -1;
	
	int iHint = CreateEntityByName("env_instructor_hint");
	if(iHint == -1)
		return -1;

	static char sTargetNewName[64];
	Format(sTargetNewName, sizeof(sTargetNewName), "chint|%d", iHint);

	static char sTargetOldName[64];

	if(iTarget > -1) 
	{
		Entity_GetName(iTarget, sTargetOldName, sizeof(sTargetOldName));
		Entity_SetName(iTarget, sTargetNewName);
	}
	else 
	{
		Entity_GetName(iClient, sTargetOldName, sizeof(sTargetOldName));
		Entity_SetName(iClient, sTargetNewName);
	}

	DispatchKeyValue(iHint, "hint_target", sTargetNewName);
	DispatchKeyValue(iHint, "hint_color", sColour);
	DispatchKeyValue(iHint, "hint_name", sName);

	static char sType[64];
	IntToString(view_as<int>(iType), sType, sizeof(sType));
	DispatchKeyValue(iHint, "hint_instance_type", sType);

	if(iTimeout < 0)
		iTimeout = 0;

	static char sInt[32];
	IntToString(iTimeout, sInt, 32);
	DispatchKeyValue(iHint, "hint_timeout", sInt);
	DispatchKeyValue(iHint, "hint_caption", sText);

	if(sBind[0] == 0) 
	{
		DispatchKeyValue(iHint, "hint_icon_onscreen", sIcon);
	}
	else 
	{
		DispatchKeyValue(iHint, "hint_icon_onscreen", "use_binding");
		DispatchKeyValue(iHint, "hint_binding", sBind);
	}

	static char sHintRange[64];
	IntToString(iHintRange, sHintRange, sizeof(sHintRange));
	DispatchKeyValue(iHint, "hint_range", sHintRange);

	DispatchSpawn(iHint);
	ActivateEntity(iHint);

	//(Valve Developper Comunity) Bug: In <Left 4 Dead 2>, hints triggered by the ShowHint input are only visible to the player who activated the I/O chain.
	//It's not a Bug, it's a feature!

	AcceptEntityInput(iHint, "ShowHint", iClient);

	if(iTarget > -1) 
	{
		Entity_SetName(iTarget, sTargetOldName);
	}
	else 
	{
		Entity_SetName(iClient, sTargetOldName);
	}

	if(iTimeout > 0)
		Entity_KillTimer(iHint, float(iTimeout) + 0.1);

	return iHint;
}

public void ePlayerSpawn(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || !IsClientInGame(iClient))
		return;
	
	g_fAdrenalineUseTime[iClient] = 0.0;
	g_fPillsUseTime[iClient] = 0.0;
}

public void ePillsUsed(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || !IsClientInGame(iClient))
		return;
	
	if(g_bIsL4D2)
	{
		if(g_fPillsUseTime[iClient] < GetGameTime())
			DisplayInstructorHint(iClient, -1, "PillsReloadBoostHint", "After using pain pills you can reload and shoot a bit faster!", "", 5, INSTRUCTOR_HINT_ICON_TIP, "255 255 255");
	}
	
	g_fPillsUseTime[iClient] = (GetGameTime() + g_fPillsSpeedUpTime);
}

public void eAdrenalineUsed(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(iClient < 1 || !IsClientInGame(iClient))
		return;
	
	if(g_fAdrenalineUseTime[iClient] < GetGameTime())
		DisplayInstructorHint(iClient, -1, "AdrenalineReloadBoostHint", "After using adrenaline you can reload and shoot extremely faster!", "", 5, INSTRUCTOR_HINT_ICON_TIP, "255 255 255");
	
	g_fAdrenalineUseTime[iClient] = (GetGameTime() + g_fAdrenSpeedUpTime);
}

public void OnMapStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		g_fAdrenalineUseTime[i] = 0.0;
		g_fPillsUseTime[i] = 0.0;
	}
}

stock void Entity_KillTimer(int Entity, float CallTime, bool bActivate=true)
{
	static char SetStrInput[32];
	static char SetStrFloat[16];

	FloatToString(CallTime, SetStrFloat, sizeof(SetStrFloat));

	Format(SetStrInput, sizeof(SetStrInput), "OnUser1 !self:Kill::%s:1", SetStrFloat);

	SetVariantString(SetStrInput);
	AcceptEntityInput(Entity, "AddOutput");

	if(bActivate)
		AcceptEntityInput(Entity, "FireUser1");
}

stock int Entity_GetName(int entity, char[] buffer, int size)
{
	return GetEntPropString(entity, Prop_Data, "m_iName", buffer, size);
}

stock bool Entity_SetName(int entity, const char[] name, any ...)
{
	char format[128];
	VFormat(format, sizeof(format), name, 3);

	return DispatchKeyValue(entity, "targetname", format);
}