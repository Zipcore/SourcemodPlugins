 //The original |CelMod| plugin was created by Celsius. This is a remake of that plugin & all code belongs to FusionLock.

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <geoip>

#define NAME "|CelMod|"
#define AUTHOR "FusionLock"
#define DESCRIPTION "A remake of the original |CelMod| plugin created by Celsius in late 2009."
#define VERSION "1.5.0.0"
#define URL "http://xfusionlockx.tk/celmod"
#define MAX_ENTITES 2048
#define RAINBOW_TICK 0.3

new g_iWhite[4] = {255, 255, 255, 200};
new g_iGray[4] = {255, 255, 255, 300};

new g_iHudRed[MAXPLAYERS + 1];
new g_iHudGreen[MAXPLAYERS + 1];
new g_iHudBlue[MAXPLAYERS + 1];

new g_iPropColor[MAX_ENTITES + 1][4];

new g_iHalo;
new g_iBeam;
new g_iPhys;
new g_iLaser;

new g_iRainbowHudNumber[MAXPLAYERS + 1];
new g_iRainbowNumber[MAXPLAYERS + 1];

new g_iOwner[MAX_ENTITES + 1];

new g_iPropCount[MAXPLAYERS + 1];
new g_iCelCount[MAXPLAYERS + 1];

new g_iPropLimit;
new g_iCelLimit;

new bool:g_bColorRainbow[MAX_ENTITES + 1];
new bool:g_bHudRainbow[MAXPLAYERS + 1];

new bool:g_bBlackEmblem[MAXPLAYERS + 1];

new bool:g_bMusicPlaying[MAX_ENTITES + 1];

new bool:g_bJustJoined[MAXPLAYERS + 1];

new Float:g_fSpawnTime[33];
new Float:g_fCommandTime[33];
new Float:g_fETime[33];

new Handle:g_hHudRainbow = INVALID_HANDLE;
new Handle:g_hRainbow = INVALID_HANDLE;

new Handle:g_hServerPropLimit = INVALID_HANDLE;
new Handle:g_hServerCelLimit = INVALID_HANDLE;

new String:g_sPropName[MAX_ENTITES + 1][128];
new String:g_sEmblemName[MAX_ENTITES + 1][128];
new String:g_sColorName[MAX_ENTITES + 1][128];
new String:g_sUrlName[MAX_ENTITES + 1][128];
new String:g_sSoundName[MAX_ENTITES + 1][128];
new String:g_sSoundPath[MAX_ENTITES + 1][128];
new String:g_sSongName[MAX_ENTITES + 1][128];
new String:g_sSongPath[MAX_ENTITES + 1][128];

new String:g_sPropsPath[128];
new String:g_sColorsPath[128];
new String:g_sDownloadsPath[128];
new String:g_sMusicPath[128];
new String:g_sSoundsPath[128];

public Plugin:myinfo = 
{
	name = NAME,
	author = AUTHOR,
	description = DESCRIPTION,
	version = VERSION,
	url = URL
}

public OnPluginStart()
{
	RegAdminCmd("cm_say", Command_ServerSay, ADMFLAG_RCON, "Sends a message using the server. Ex: |CM| Hawt.");
	RegAdminCmd("cm_specialspawn", Command_SpecialSpawn, ADMFLAG_RCON, "Spawns a special entity. (Emblems, delaware, hoopie, ect.)");
	//Headcrab Canister wont spawn. Command is commented out for the time being.
	//RegAdminCmd("cm_headcrabcan", Command_HeadcrabCan, ADMFLAG_RCON, "Spawns an headcrab canister.");
	
	RegConsoleCmd("sm_spawn", Command_Spawn, "Spawns a prop.");
	RegConsoleCmd("sm_delete", Command_Delete, "Removes an entity.");
	RegConsoleCmd("sm_deleteall", Command_DeleteAll, "Removes all your entities.");
	RegConsoleCmd("sm_freeze", Command_Freeze, "Freezes an entity.");
	RegConsoleCmd("sm_unfreeze", Command_UnFreeze, "Unfreezes an entity.");
	RegConsoleCmd("sm_fly", Command_Fly, "Enables noclip on a client.");
	RegConsoleCmd("sm_internet", Command_Internet, "Spawns an internet cel.");
	RegConsoleCmd("sm_seturl", Command_SetUrl, "Sets the URL of an internet cel.");
	RegConsoleCmd("sm_color", Command_Color, "Changes the color of an entity.");
	RegConsoleCmd("sm_hudcolor", Command_HudColor, "Changes the color of your hud.");
	RegConsoleCmd("sm_owner", Command_Owner, "Retrieves the owner of an entity.");
	RegConsoleCmd("sm_amt", Command_Alpha, "Changes the alpha transparency of an entity.");
	RegConsoleCmd("sm_solid", Command_Solid, "Changes the solidity of an entity.");
	RegConsoleCmd("sm_rotate", Command_Rotate, "Rotates an entity.");
	RegConsoleCmd("sm_flip", Command_Flip, "Flips an entity.");
	RegConsoleCmd("sm_roll", Command_Roll, "Rolls an entity.");
	RegConsoleCmd("sm_straight", Command_Straight, "Resets an entity's angle.");
	RegConsoleCmd("sm_smove", Command_SMove, "Alters the origin of an entity slightly.");
	RegConsoleCmd("sm_colorall", Command_ColorAll, "Changes the color of all your entitys.");
	RegConsoleCmd("sm_door", Command_Door, "Spawns an light cel.");
	RegConsoleCmd("sm_ignite", Command_Ignite, "Sets an entity on fire for x amount of seconds.");
	RegConsoleCmd("sm_sound", Command_Sound, "Spawns an sound cel.");
	RegConsoleCmd("sm_music", Command_Music, "Spawns an music cel.");

	LoadTranslations("common.phrases");

	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	
	AddCommandListener(HideChatTriggers, "say");
	AddCommandListener(HideChatTriggers, "say_team");  
	
	g_hServerPropLimit = CreateConVar("cm_prop_limit", "300", "Maxiumum number of props a player is allowed to spawn.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_hServerCelLimit = CreateConVar("cm_cel_limit", "50", "Maxiumum number of CelMod entities a client is allowed.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	
	HookConVarChange(g_hServerPropLimit, OnConvarsUpdated);
	HookConVarChange(g_hServerCelLimit, OnConvarsUpdated);
	
	g_iPropLimit = GetConVarInt(g_hServerPropLimit);
	g_iCelLimit = GetConVarInt(g_hServerPropLimit);
	
	SetCommandFlags("r_screenoverlay", (GetCommandFlags("r_screenoverlay") - FCVAR_CHEAT));

	BuildPath(Path_SM, g_sPropsPath, 128, "data/celmod/props.txt");
	BuildPath(Path_SM, g_sColorsPath, 128, "data/celmod/colors.txt");
	BuildPath(Path_SM, g_sDownloadsPath, 128, "data/celmod/downloads.txt");
	BuildPath(Path_SM, g_sMusicPath, 128, "data/celmod/music.txt");
	BuildPath(Path_SM, g_sSoundsPath, 128, "data/celmod/sounds.txt");

	DownloadFiles();
}

public OnClientAuthorized(iClient, const String:sAuth[])
{
	decl String:sAuthID[64], String:sIP[64], String:sCountry[4];

	GetClientAuthString(iClient, sAuthID, sizeof(sAuthID), true);
	GetClientIP(iClient, sIP, sizeof(sIP));
	GeoipCode3(sIP, sCountry);

	CPrintToChatAll("[C] {olive}%N{default} <{olive}%s{default}> | Country: {olive}%s{default}", iClient, sAuthID, sCountry);

	for (new i = 1; i < MaxClients; i++)
	{
		ClientCommand(i, "play npc/metropolice/vo/on1.wav");
	}
}

public OnClientPutInServer(iClient)
{
	g_fSpawnTime[iClient] = 0.0;
	g_fCommandTime[iClient] = 0.0;
	
	g_iPropCount[iClient] = 0;
	g_iCelCount[iClient] = 0;
	
	g_bColorRainbow[iClient] = false;
	g_bHudRainbow[iClient] = false;
	
	g_iRainbowHudNumber[iClient] = 0;
	g_iRainbowNumber[iClient] = 0;
	
	CreateTimer(0.01, Timer_PropHud, _, TIMER_REPEAT);
	
	ClientCommand(iClient, "r_screenoverlay celmod/cm_overlay2.vmt");
	ClientCommand(iClient, "play items/ammo_pickup.wav");

	CreateTimer(0.1, Timer_SpawnClient);

	g_bJustJoined[iClient] = true;
	
	ChooseHudColor(iClient);
}

public OnClientDisconnect(iClient)
{
	g_bColorRainbow[iClient] = false;
	g_bHudRainbow[iClient] = false;

	decl String:sClassname[256];
	
	if(g_iPropCount[iClient] > 0 || g_iCelCount[iClient] > 0)
	{
		for (new i = 0; i < GetMaxEntities(); i++)
		{
			if(CheckOwner(iClient, i))
			{
				GetEntityClassname(i, sClassname, sizeof(sClassname));
				if(IsValidProp(i))
				{
					CreateTimer(0.3, Timer_DelayRemove, i);
				}
				if(StrEqual(sClassname, "cel_sound", true))
				{
					StopSound(i, 0, g_sSoundPath[i]);
				}else if(StrEqual(sClassname, "cel_music", true))
				{
					StopSound(i, 0, g_sSongPath[i]);
					g_bMusicPlaying[i] = false;
				}else{

				}
			}
		}
	}

	decl String:sAuthID[64];

	GetClientAuthString(iClient, sAuthID, sizeof(sAuthID), true);

	CPrintToChatAll("[D] {olive}%N{default} <{olive}%s{default}>", iClient, sAuthID);

	for (new i = 1; i < MaxClients; i++)
	{
		ClientCommand(i, "play npc/metropolice/vo/off1.wav");
	}

	ClientCommand(iClient, "r_screenoverlay 0");
}

public OnMapStart()
{
	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", false);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", false);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate4.wav", false);
	
	g_iHalo = PrecacheModel("materials/sprites/halo01.vmt", true);
	g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	g_iPhys = PrecacheModel("materials/sprites/physbeam.vmt", true);
	g_iLaser = PrecacheModel("materials/sprites/laser.vmt", false);
	
	PrecacheModel("models/props_lab/monitor02.mdl", false);
	
	g_hHudRainbow = CreateTimer(RAINBOW_TICK, Timer_HudRainbow, _, TIMER_REPEAT);
	
	g_hRainbow = CreateTimer(RAINBOW_TICK, Timer_Rainbow, _, TIMER_REPEAT);
}

public OnMapEnd()
{
	if (g_hHudRainbow != INVALID_HANDLE) g_hHudRainbow = INVALID_HANDLE;
	
	if (g_hRainbow != INVALID_HANDLE) g_hRainbow = INVALID_HANDLE;
}

public OnConvarsUpdated(Handle:hConvar, const String:sOldData[], const String:sNewData[])
{
	if(hConvar == g_hServerPropLimit)
	{
		g_iPropLimit = StringToInt(sNewData);
	}else if(hConvar == g_hServerCelLimit)
	{
		g_iCelLimit = StringToInt(sNewData);
	}  
}

stock DownloadFiles()
{
	new Handle:hDownloadFiles = OpenFile(g_sDownloadsPath, "r");
	new String:sBuffer[256];
	while (ReadFileLine(hDownloadFiles, sBuffer, sizeof(sBuffer)))
	{
		new iLen = strlen(sBuffer);
		if (sBuffer[iLen-1] == '\n')
		{
			sBuffer[--iLen] = '\0';
		}
		
		if (FileExists(sBuffer))
		{
			AddFileToDownloadsTable(sBuffer);
		}
		
		if(StrContains(sBuffer, ".mdl", false) != -1)
		{
			PrecacheModel(sBuffer, true);
		}
		
		if (IsEndOfFile(hDownloadFiles))
		{
			break;
		} 
	}
}

stock ChooseHudColor(iClient)
{
	new iRandom = GetRandomInt(0, 6);
	switch(iRandom)
	{
		case 0:
		{
			g_iHudRed[iClient] = 255;
			g_iHudGreen[iClient] = 0;
			g_iHudBlue[iClient] = 0;
		}
		case 1:
		{
			g_iHudRed[iClient] = 255;
			g_iHudGreen[iClient] = 128;
			g_iHudBlue[iClient] = 0;
		}
		case 2:
		{
			g_iHudRed[iClient] = 255;
			g_iHudGreen[iClient] = 255;
			g_iHudBlue[iClient] = 0;
		}
		case 3:
		{
			g_iHudRed[iClient] = 0;
			g_iHudGreen[iClient] = 255;
			g_iHudBlue[iClient] = 0;
		}
		case 4:
		{
			g_iHudRed[iClient] = 0;
			g_iHudGreen[iClient] = 0;
			g_iHudBlue[iClient] = 255;
		}
		case 5:
		{
			g_iHudRed[iClient] = 255;
			g_iHudGreen[iClient] = 0;
			g_iHudBlue[iClient] = 255;
		}
		case 6:
		{
			g_iHudRed[iClient] = 128;
			g_iHudGreen[iClient] = 0;
			g_iHudBlue[iClient] = 255;
		}
		default:
		{
		}
	}
}

stock ChangeBeam(iClient, iEnt)
{
	decl Float:fAngles[3], Float:fOrigin[3], Float:fEOrigin[3];
	decl String:sSound[64];
	GetClientAbsOrigin(iClient, fOrigin);
	GetClientEyeAngles(iClient, fAngles);
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fEOrigin);
	TE_SetupBeamPoints(fOrigin, fEOrigin, g_iPhys, g_iHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, g_iWhite, 10);
	TE_SendToAll();
	TE_SetupSparks(fEOrigin, fAngles, 3, 2);
	TE_SendToAll();
	new iRandom = GetRandomInt(0, 1);
	switch(iRandom)
	{
		case 0:
		{
			Format(sSound, sizeof(sSound), "weapons/airboat/airboat_gun_lastshot1.wav");
		}
		case 1:
		{
			Format(sSound, sizeof(sSound), "weapons/airboat/airboat_gun_lastshot2.wav");
		}
		default:
		{
		}
	}
	EmitSoundToAll(sSound, iEnt, 2, 100, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

stock DeleteBeam(iClient, iEnt)
{
	new String:sBeamSound[128] = "ambient/levels/citadel/weapon_disintegrate4.wav";
	decl Float:fAngles[3], Float:fOrigin[3], Float:fEOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	GetClientEyeAngles(iClient, fAngles);
	GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fEOrigin);
	TE_SetupBeamPoints(fOrigin, fEOrigin, g_iLaser, g_iHalo, 0, 15, 0.25, 15.0, 15.0, 1, 0.0, g_iGray, 10);
	TE_SendToAll();
	TE_SetupBeamRingPoint(fEOrigin, 10.0, 60.0, g_iBeam, g_iHalo, 0, 15, 0.5, 5.0, 0.0, g_iGray, 10, 0);
	TE_SendToAll();
	EmitAmbientSound(sBeamSound, fEOrigin, iEnt, 100, 0, 1.0, 100, 0.0);
}

stock GetHitOrigin(iClient, Float:fOrigin[3])
{
	decl Float:fCOrigin[3], Float:fCAngles[3];
	GetClientEyePosition(iClient, fCOrigin);
	GetClientEyeAngles(iClient, fCAngles);
	new Handle:hTraceRay = TR_TraceRayFilterEx(fCOrigin, fCAngles, MASK_SOLID, RayType_Infinite, FilterPlayer);
	if(TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(fOrigin, hTraceRay);
		CloseHandle(hTraceRay);
		return;
	}
	CloseHandle(hTraceRay);
}

stock CelModClient(iClient, const String:sMessage[])
{
	CPrintToChat(iClient, "{blue}|CelMod|{default} %s", sMessage);
	new iRandom = GetRandomInt(0, 1);
	switch(iRandom)
	{
		case 0:
		{
			ClientCommand(iClient, "play npc/stalker/stalker_footstep_left1");
		}
		case 1:
		{
			ClientCommand(iClient, "play npc/stalker/stalker_footstep_right1");
		}
		default:
		{
		}
	}
}

stock CelModServer(const String:sMessage[])
{
	CPrintToChatAll("{blue}|CM|{default} %s", sMessage);
}

stock HudMessage(iClient, iChannel, 
Float:fX, Float:fY, 
iR, iG, iB, iA, 
iEffect, 
Float:fFadeIn, Float:fFadeOut, 
Float:fHoldTime, Float:fFxTime, 
const String:sMessage[])
{
	new Handle:hHudMessage;
	if(!iClient)
	{
		hHudMessage = StartMessageAll("HudMsg");
	}else{
		hHudMessage = StartMessageOne("HudMsg", iClient);
	}
	if(hHudMessage != INVALID_HANDLE)
	{
		BfWriteByte(hHudMessage, iChannel);
		BfWriteFloat(hHudMessage, fX);
		BfWriteFloat(hHudMessage, fY);
		BfWriteByte(hHudMessage, iR);
		BfWriteByte(hHudMessage, iG);
		BfWriteByte(hHudMessage, iB);
		BfWriteByte(hHudMessage, iA);
		BfWriteByte(hHudMessage, iR);
		BfWriteByte(hHudMessage, iG);
		BfWriteByte(hHudMessage, iB);
		BfWriteByte(hHudMessage, iA);
		BfWriteByte(hHudMessage, iEffect);
		BfWriteFloat(hHudMessage, fFadeIn);
		BfWriteFloat(hHudMessage, fFadeOut);
		BfWriteFloat(hHudMessage, fHoldTime);
		BfWriteFloat(hHudMessage, fFxTime);
		BfWriteString(hHudMessage, sMessage);
		EndMessage();
	}
}

stock TooFast(iClient)
{
	new iRandom = GetRandomInt(0, 2);
	switch(iRandom)
	{
		case 0:
		{
			CelModClient(iClient, "Where's the rush?");
		}
		case 1:
		{
			CelModClient(iClient, "Cool your jets, buddy.");
		}
		case 2:
		{
			CelModClient(iClient, "Woah, slow down there charlie.");
		}
		default:
		{
		}
	}
}

stock NotYours(iClient)
{
	CelModClient(iClient, "This entity does not belong to you.");
}

stock NotYourEmblem(iClient)
{
	CelModClient(iClient, "This emblem does not belong to you.");
}

stock NotLooking(iClient)
{
	CelModClient(iClient, "You are not looking at anything.");
}

stock CannotColorEmblems(iClient)
{
	CelModClient(iClient, "You cannot color emblems!");
}

stock CheckOwner(iClient, iEnt)
{
	if(g_iOwner[iEnt] == iClient)
	{
		return true;
	}
	return false;
}

stock ActivateEmblem(iClient, bool:bActivate)
{
	if(bActivate)
	{
		CPrintToChat(iClient, "{blue}|CelMod|{default} You have activated an emblem. Hit {green}E{default} on it again to deactivate it.");
	}else{
		CPrintToChat(iClient, "{blue}|CelMod|{default} You have deactivated an emblem. Hit {green}E{default} on it again to activate it.");
	}
}

stock DissolveEntity(iEnt)
{
	decl String:sTargetname[256];
	Format(sTargetname, sizeof(sTargetname), "dissolve%N%f", g_iOwner[iEnt], GetRandomFloat());
	DispatchKeyValue(iEnt, "targetname", sTargetname);
	new iDissolve = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(iDissolve, "dissolvetype", "3");
	DispatchKeyValue(iDissolve, "target", sTargetname);
	AcceptEntityInput(iDissolve, "dissolve");
	AcceptEntityInput(iDissolve, "kill");
}

stock IgniteEnt(iEnt, const String:sSeconds[])
{
	decl String:sTargetname[256];
	Format(sTargetname, sizeof(sTargetname), "ignite%N%f", g_iOwner[iEnt], GetRandomFloat());
	DispatchKeyValue(iEnt, "targetname", sTargetname);
	new iIgnite = CreateEntityByName("env_entity_igniter");
	DispatchKeyValue(iIgnite, "target", sTargetname);
	DispatchKeyValue(iIgnite, "lifetime", sSeconds);
	AcceptEntityInput(iIgnite, "ignite");
}

stock UseInternet(iClient, iEnt)
{
	decl String:sName[128];
	Format(sName, sizeof(sName), "%N's Internet", g_iOwner[iEnt]);
	ShowMOTDPanel(iClient, sName, g_sUrlName[iEnt], MOTDPANEL_TYPE_URL);
}

stock UseSound(iEnt)
{
	PrecacheSound(g_sSoundPath[iEnt]);
	EmitSoundToAll(g_sSoundPath[iEnt], iEnt, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
}

stock UseMusic(iEnt)
{
	if(g_bMusicPlaying[iEnt])
	{
		StopSound(iEnt, 0, g_sSongPath[iEnt]);
		g_bMusicPlaying[iEnt] = false;
	}else{
		PrecacheSound(g_sSongPath[iEnt]);
		EmitSoundToAll(g_sSongPath[iEnt], iEnt, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		g_bMusicPlaying[iEnt] = true;
	}
}

stock UseBlackEmblem(iClient)
{
	if(g_bBlackEmblem[iClient])
	{
		SetEntityColor(iClient, 255, 255, 255);
		g_bBlackEmblem[iClient] = false;
		ClientCommand(iClient, "play hl1/fvox/fuzz.wav");
		ActivateEmblem(iClient, false);
	}else{
		SetEntityColor(iClient, 0, 0, 0);
		g_bBlackEmblem[iClient] = true;
		ClientCommand(iClient, "play hl1/fvox/fuzz.wav");
		ActivateEmblem(iClient, true);
	}
}

stock SetEntityColor(iEnt, R, G, B)
{
	new Color = GetEntSendPropOffs(iEnt, "m_clrRender", false);
	new A = GetEntData(iEnt, Color + 3, 1);
	SetEntityRenderColor(iEnt, R, G, B, A);
}

stock bool:IsValidProp(entity)
{
	if (entity > 0 && IsValidEntity(entity))
	{
		return true;
	}
	return false;
}

public OnGameFrame()
{
	decl bool:bCanUseEmblem;
	decl iClient;
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(IsPlayerAlive(i))
			{
				if(GetClientButtons(i) & IN_USE)
				{
					new iEnt = GetClientAimTarget(i, false);
					decl Float:fOrigin[3], Float:fEntityOrigin[3];
					if(GetClientAimTarget(i, false) == -1)
					{
						
					}else{
						iClient = i;
						decl String:sClassname[256];
						GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
						GetClientAbsOrigin(i, fOrigin);
						GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fEntityOrigin);
						new Float:fDistance = GetVectorDistance(fOrigin, fEntityOrigin);
						if(StrEqual(sClassname, "cel_internet", true))
						{
							if(fDistance <= 150)
							{
								UseInternet(i, iEnt);
							}
						}else if(StrEqual(sClassname, "emblem_black", true))
						{
							if(CheckOwner(i, iEnt))
							{
								if(g_fETime[i] < GetGameTime() - 1)
								{
									if(fDistance <= 150)
									{
										UseBlackEmblem(i);
										bCanUseEmblem = true;
									}
									g_fETime[i] = GetGameTime();
								}
							}else{
								bCanUseEmblem = false;
							}
						}else if(StrEqual(sClassname, "cel_sound", true))
						{
							if(g_fETime[i] < GetGameTime() - 1)
							{
								if(fDistance <= 50)
								{
									UseSound(iEnt);
								}
								g_fETime[i] = GetGameTime();
							}
						}else if(StrEqual(sClassname, "cel_music", true))
						{
							if(g_fETime[i] < GetGameTime() - 1)
							{
								if(fDistance <= 150)
								{
									UseMusic(iEnt);
								}
								g_fETime[i] = GetGameTime();
							}
						}
					}
				}
			}
		}
	}
	if(!bCanUseEmblem)
	{
		NotYourEmblem(iClient);
	}
}

public Action:Timer_HudRainbow(Handle:timer)
{
	for (new i = 1; i < MaxClients; i++)
	{
		switch(g_iRainbowHudNumber[i])
		{
			case 0:
			{
				if(g_bHudRainbow[i])
				{
					g_iHudRed[i] = 255;
					g_iHudGreen[i] = 0;
					g_iHudBlue[i] = 0;
				}
				g_iRainbowHudNumber[i] = 1;
			}
			case 1:
			{
				if(g_bHudRainbow[i])
				{
					g_iHudRed[i] = 255;
					g_iHudGreen[i] = 128;
					g_iHudBlue[i] = 0;
				}
				g_iRainbowHudNumber[i] = 2;
			}
			case 2:
			{
				if(g_bHudRainbow[i])
				{
					g_iHudRed[i] = 255;
					g_iHudGreen[i] = 255;
					g_iHudBlue[i] = 0;
				}
				g_iRainbowHudNumber[i] = 3;
			}
			case 3:
			{
				if(g_bHudRainbow[i])
				{
					g_iHudRed[i] = 0;
					g_iHudGreen[i] = 255;
					g_iHudBlue[i] = 0;
				}
				g_iRainbowHudNumber[i] = 4;
			}
			case 4:
			{
				if(g_bHudRainbow[i])
				{
					g_iHudRed[i] = 0;
					g_iHudGreen[i] = 0;
					g_iHudBlue[i] = 255;
				}
				g_iRainbowHudNumber[i] = 5;
			}
			case 5:
			{
				if(g_bHudRainbow[i])
				{
					g_iHudRed[i] = 128;
					g_iHudGreen[i] = 0;
					g_iHudBlue[i] = 255;
				}
				g_iRainbowHudNumber[i] = 6;
			}
			case 6:
			{
				if(g_bHudRainbow[i])
				{
					g_iHudRed[i] = 255;
					g_iHudGreen[i] = 0;
					g_iHudBlue[i] = 255;
				}
				g_iRainbowHudNumber[i] = 0;
			}
		}
	}
}

public Action:Timer_Rainbow(Handle:timer)
{
	for (new i = 0; i < GetMaxEntities(); i++)
	{
		if(g_bColorRainbow[i])
		{
			switch(g_iRainbowNumber[g_iOwner[i]])
			{
				case 0:
				{
					SetEntityColor(i, 255, 0, 0);
					g_iRainbowNumber[g_iOwner[i]] = 1;
				}
				case 1:
				{
					SetEntityColor(i, 255, 128, 0);
					g_iRainbowNumber[g_iOwner[i]] = 2;
				}
				case 2:
				{
					SetEntityColor(i, 255, 255, 0);
					g_iRainbowNumber[g_iOwner[i]] = 3;
				}
				case 3:
				{
					SetEntityColor(i, 0, 255, 0);
					g_iRainbowNumber[g_iOwner[i]] = 4;
				}
				case 4:
				{
					SetEntityColor(i, 0, 0, 255);
					g_iRainbowNumber[g_iOwner[i]] = 5;
				}
				case 5:
				{
					SetEntityColor(i, 128, 0, 255);
					g_iRainbowNumber[g_iOwner[i]] = 6;
				}
				case 6:
				{
					SetEntityColor(i, 255, 0, 255);
					g_iRainbowNumber[g_iOwner[i]] = 0;
				}
			}
		}
	}
}

public Action:Timer_DelayRemove(Handle:timer, any:i)
{
	AcceptEntityInput(i, "kill");
	if(g_bColorRainbow[i])
	{
		g_bColorRainbow[i] = false;
	}
}

public Action:Timer_SpawnClient(Handle:timer)
{
	for(new i = 1; i < MaxClients; i++)
	{
		if(g_bJustJoined[i])
		{
			CPrintToChatAll("Player {green}%N{default} has spawned.", i);
			g_bJustJoined[i] = false;
		}
	}
}

public Action:Timer_PropHud(Handle:timer)
{
	decl String:sTemp[256], String:sClassname[64];
	for (new i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i) && IsClientConnected(i))
		{
			if(GetClientAimTarget(i, false) == -1)
			{
				Format(sTemp, sizeof(sTemp), "Name: %N\nProps Spawned: %d\nCels Spawned: %d", i, g_iPropCount[i], g_iCelCount[i]);
			}else{
				new iEnt = GetClientAimTarget(i, false);
				GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
				if(StrEqual(sClassname, "player", false))
				{
					Format(sTemp, sizeof(sTemp), "Name: %N\nProps Spawned: %d\nCels Spawned: %d", iEnt, g_iPropCount[iEnt], g_iCelCount[iEnt]);
				}else if(CheckOwner(i, iEnt))
				{
					if(StrEqual(sClassname, "emblem_black", false))
					{
						Format(sTemp, sizeof(sTemp), "Emblem: %s", g_sEmblemName[iEnt]);
					}else{
						if(StrEqual(sClassname, "cel_internet", false))
						{
							Format(sTemp, sizeof(sTemp), "Url: %s\nColor: %s", g_sUrlName[iEnt], g_sColorName[iEnt]);
						}else{
							if(StrEqual(sClassname, "cel_sound", false))
							{
								Format(sTemp, sizeof(sTemp), "Sound: %s\nColor: %s", g_sSoundName[iEnt], g_sColorName[iEnt]);
							}else{
								if(StrEqual(sClassname, "cel_music", false))
								{
									Format(sTemp, sizeof(sTemp), "Song: %s\nColor: %s", g_sSongName[iEnt], g_sColorName[iEnt]);
								}else{
									Format(sTemp, sizeof(sTemp), "Prop: %s\nColor: %s", g_sPropName[iEnt], g_sColorName[iEnt]);
								}
							}
						}
					}
				}else{
					if(StrEqual(sClassname, "emblem_black", false))
					{
						Format(sTemp, sizeof(sTemp), "Owner: %N\nEmblem: %s", g_iOwner[iEnt], g_sEmblemName[iEnt]);
					}else{
						if(StrEqual(sClassname, "cel_internet", false))
						{
							Format(sTemp, sizeof(sTemp), "Owner: %N\nUrl: %s\nColor: %s", g_iOwner[iEnt], g_sUrlName[iEnt], g_sColorName[iEnt]);
						}else{
							if(StrEqual(sClassname, "cel_sound", false))
							{
								Format(sTemp, sizeof(sTemp), "Owner: %N\nSound: %s\nColor: %s", g_iOwner[iEnt], g_sSoundName[iEnt], g_sColorName[iEnt]);
							}else{
								if(StrEqual(sClassname, "cel_music", false))
								{
									Format(sTemp, sizeof(sTemp), "Owner: %N\nSong: %s\nColor: %s", g_iOwner[iEnt], g_sSongName[iEnt], g_sColorName[iEnt]);
								}else{
									Format(sTemp, sizeof(sTemp), "Owner: %N\nProp: %s\nColor: %s", g_iOwner[iEnt], g_sPropName[iEnt], g_sColorName[iEnt]);
								}
							}
						}
					}
				}
			}
			HudMessage(i, 1, 3.025, -0.110, g_iHudRed[i], g_iHudGreen[i], g_iHudBlue[i], 225, 0, 0.6, 0.01, 0.01, 0.01, sTemp);
		}
	}
}

public bool:FilterPlayer(entity, contentsMask)
{
	return entity > MaxClients;
}

public Action:Event_PlayerConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!dontBroadcast)
    {
        decl String:clientName[33], String:networkID[22], String:address[32];
        GetEventString(event, "name", clientName, sizeof(clientName));
        GetEventString(event, "networkid", networkID, sizeof(networkID));
        GetEventString(event, "address", address, sizeof(address));
        new Handle:newEvent = CreateEvent("player_connect", true);
        SetEventString(newEvent, "name", clientName);
        SetEventInt(newEvent, "index", GetEventInt(event, "index"));
        SetEventInt(newEvent, "userid", GetEventInt(event, "userid"));
        SetEventString(newEvent, "networkid", networkID);
        SetEventString(newEvent, "address", address);
        FireEvent(newEvent, true);
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    if (!dontBroadcast)
    {
        decl String:clientName[33], String:networkID[22], String:reason[65];
        GetEventString(event, "name", clientName, sizeof(clientName));
        GetEventString(event, "networkid", networkID, sizeof(networkID));
        GetEventString(event, "reason", reason, sizeof(reason));
        
        new Handle:newEvent = CreateEvent("player_disconnect", true);
        SetEventInt(newEvent, "userid", GetEventInt(event, "userid"));
        SetEventString(newEvent, "reason", reason);
        SetEventString(newEvent, "name", clientName);        
        SetEventString(newEvent, "networkid", networkID);
        
        FireEvent(newEvent, true);
        
        return Plugin_Handled;
    }
    return Plugin_Handled;
}

public Action:HideChatTriggers(iClient, const String:command[], iArgs)
{
	decl String:sText[2];
	GetCmdArg(1, sText, sizeof(sText));
	return (sText[0] == '/' || sText[0] == '!') ? Plugin_Handled : Plugin_Continue;
} 

public Action:Command_Spawn(iClient, iArgs)
{
	decl Float:fAngles[3], Float:fOrigin[3];
	decl String:sAlias[64], String:sOption[64], String:sModel[64], String:sEntityName[64], String:sPropsName[128], String:sPropsBuffer[2][128], String:sTemp[256];
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!spawn{default} <prop alias> <extra options>");
		CelModClient(iClient, "Type {green}!proplist{default} for a list of prop aliases.");
		return Plugin_Handled;
	}
	if(g_iPropCount[iClient] > g_iPropLimit)
	{
		Format(sTemp, sizeof(sTemp), "You've reached your max prop count(%d).", g_iPropLimit);
		CelModClient(iClient, sTemp);
		return Plugin_Handled;
	}
	GetCmdArg(1, sAlias, sizeof(sAlias));
	GetCmdArg(2, sOption, sizeof(sOption));
	if(g_fSpawnTime[iClient] < GetGameTime() - 1)
	{
		new Handle:hProps = CreateKeyValues("Props");
		FileToKeyValues(hProps, g_sPropsPath);
		KvGetString(hProps, sAlias, sPropsName, sizeof(sPropsName), "null");
		if(StrContains(sPropsName, "null", false) != -1)
		{
			if(StrContains(sAlias, "1", false) != -1)
			{
				ReplaceString(sAlias, sizeof(sAlias), "1", "");
			}else{
				Format(sAlias, sizeof(sAlias), "%s1", sAlias);
			}
			KvGetString(hProps, sAlias, sPropsName, sizeof(sPropsName), "null");
			if(StrContains(sPropsName, "null", false) != -1)
			{
				CelModClient(iClient, "Prop not found!");
				CloseHandle(hProps);
				return Plugin_Handled;
			}
		}
		ExplodeString(sPropsName, "^", sPropsBuffer, 2, sizeof(sPropsBuffer[]));
		strcopy(sModel, sizeof(sModel), sPropsBuffer[0]);
		strcopy(sEntityName, sizeof(sEntityName), sPropsBuffer[1]);
		GetClientAbsAngles(iClient, fAngles);
		GetHitOrigin(iClient, fOrigin);
		new iEnt = CreateEntityByName(sEntityName);
		PrecacheModel(sModel);
		DispatchKeyValue(iEnt, "model", sModel);
		DispatchSpawn(iEnt);
		TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);
		if(StrEqual(sOption, "frozen", true))
		{
			AcceptEntityInput(iEnt, "disablemotion");
		}else if(StrEqual(sOption, "god", true))
		{
			SetEntProp(iEnt, Prop_Data, "m_takedamage", 0, 1);
		}else if(StrEqual(sOption, "", true))
		{}else{
			Format(sTemp, sizeof(sTemp), "{green}%s{default} is not a valid option.", sOption);
			CelModClient(iClient, sTemp);
		}
		g_iPropCount[iClient]++;
		Format(g_sPropName[iEnt], sizeof(g_sPropName[]), sAlias);
		g_iOwner[iEnt] = iClient;
		Format(g_sColorName[iEnt], sizeof(g_sColorName[]), "white");
		new iColor = GetEntSendPropOffs(iEnt, "m_clrRender", false);
		new iR = GetEntData(iEnt, iColor, 1);
		new iG = GetEntData(iEnt, iColor + 1, 1);
		new iB = GetEntData(iEnt, iColor + 2, 1);
		new iA = GetEntData(iEnt, iColor + 3, 1);
		g_iPropColor[iEnt][0] = iR;
		g_iPropColor[iEnt][1] = iG;
		g_iPropColor[iEnt][2] = iB;
		g_iPropColor[iEnt][3] = iA;
		g_fSpawnTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Delete(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		decl String:sClassname[64];
		GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
		if(CheckOwner(iClient, iEnt))
		{
			DissolveEntity(iEnt);
			if(g_bColorRainbow[iEnt])
			{
				g_bColorRainbow[iEnt] = false;
			}
			if(g_bBlackEmblem[iClient])
			{
				SetEntityColor(iClient, 255, 255, 255);
				g_bBlackEmblem[iClient] = false;
			}
			if(StrContains(sClassname, "cel_", false) != -1 || StrContains(sClassname, "emblem_", false) != -1)
			{
				g_iCelCount[g_iOwner[iEnt]] -= 1;
			}else{
				g_iPropCount[g_iOwner[iEnt]] -= 1;
			}
			if(StrEqual(sClassname, "cel_sound", true))
			{
				StopSound(iEnt, 0, g_sSoundPath[iEnt]);
				g_bMusicPlaying[iEnt] = false;
			}else if(StrEqual(sClassname, "cel_music", true))
			{
				StopSound(iEnt, 0, g_sSongPath[iEnt]);
			}else{

			}
			DeleteBeam(iClient, iEnt);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Freeze(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			AcceptEntityInput(iEnt, "disablemotion");
			ChangeBeam(iClient, iEnt);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_UnFreeze(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			AcceptEntityInput(iEnt, "enablemotion");
			ChangeBeam(iClient, iEnt);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_DeleteAll(iClient, iArgs)
{
	decl String:sTemp[256], String:sClassname[256];
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		if(g_iPropCount[iClient] > 0 || g_iCelCount[iClient] > 0)
		{
			new iProps = g_iPropCount[iClient] + g_iCelCount[iClient];
			for (new i = 0; i < GetMaxEntities(); i++)
			{
				if(CheckOwner(iClient, i))
				{
					GetEntityClassname(i, sClassname, sizeof(sClassname));
					if(StrContains(sClassname, "weapon_", false)!= -1)
					{
						//Do Nothing!
					}else{
						if(IsValidProp(i))
						{
							CreateTimer(0.3, Timer_DelayRemove, i);
						}
					}
					if(g_bColorRainbow[i])
					{
						g_bColorRainbow[i] = false;
					}	
					if(g_bBlackEmblem[iClient])
					{
						SetEntityColor(iClient, 255, 255, 255);
						g_bBlackEmblem[iClient] = false;
					}
					if(StrEqual(sClassname, "cel_sound", true))
					{
						StopSound(i, 0, g_sSoundPath[i]);
					}else if(StrEqual(sClassname, "cel_music", true))
					{
						StopSound(i, 0, g_sSongPath[i]);
						g_bMusicPlaying[i] = false;
					}else{

					}
				}
			}
			if(g_iPropCount[iClient] > 0)
			{
				g_iPropCount[iClient] = 0;
			}else if(g_iCelCount[iClient] > 0)
			{
				g_iCelCount[iClient] = 0;
			}
			Format(sTemp, sizeof(sTemp), "{green}%d{default} item(s) have been removed.", iProps);
			g_iPropCount[iClient] = 0;
			g_iCelCount[iClient] = 0;
			CelModClient(iClient, sTemp);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Fly(iClient, iArgs)
{
	new MoveType:sMoveType = GetEntityMoveType(iClient);
	if (sMoveType != MOVETYPE_NOCLIP)
	{
		SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
		CelModClient(iClient, "You have enabled flying.");
	}
	else
	{
		SetEntityMoveType(iClient, MOVETYPE_WALK);
		CelModClient(iClient, "You have disabled flying.");
	}
	return Plugin_Handled;
}

public Action:Command_ServerSay(iClient, iArgs)
{
	decl String:sMessage[1024];
	GetCmdArgString(sMessage, sizeof(sMessage));
	CelModServer(sMessage);
	for (new i = 1; i < MaxClients; i++)
	{
		ClientCommand(i, "play weapons/fx/nearmiss/bulletltor10.wav");
	}
	return Plugin_Handled;
}

public Action:Command_Internet(iClient, iArgs)
{
	decl String:sTemp[256];
	decl Float:fAngles[3], Float:fOrigin[3];
	if(g_iCelCount[iClient] > g_iCelLimit)
	{
		Format(sTemp, sizeof(sTemp), "You've reached your max cel count(%d).", g_iCelLimit);
		CelModClient(iClient, sTemp);
		return Plugin_Handled;
	}
	if(g_fSpawnTime[iClient] < GetGameTime() - 1)
	{
		GetClientAbsAngles(iClient, fAngles);
		GetHitOrigin(iClient, fOrigin);
		new iEnt = CreateEntityByName("prop_physics_override");
		DispatchKeyValue(iEnt, "model", "models/props_lab/monitor02.mdl");
		DispatchKeyValue(iEnt, "classname", "cel_internet");
		DispatchSpawn(iEnt);
		TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);
		Format(g_sUrlName[iEnt], sizeof(g_sUrlName[]), "http://celmod.xfusionlockx.tk");
		g_iOwner[iEnt] = iClient;
		g_iCelCount[iClient]++;
		Format(g_sColorName[iEnt], sizeof(g_sColorName[]), "white");
		g_fSpawnTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_SetUrl(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!seturl{default} <url>");
		return Plugin_Handled;
	}
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		decl String:sUrl[256], String:sUrl2[256], String:sTemp[256], String:sClassname[64];
		new iEnt = GetClientAimTarget(iClient, false);
		GetCmdArgString(sUrl, sizeof(sUrl));
		GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
		if(CheckOwner(iClient, iEnt) && StrEqual(sClassname, "cel_internet", true))
		{
			if(StrContains(sUrl, "//", false)!=-1)
			{
				Format(sUrl2, sizeof(sUrl2), "%s", sUrl);
			}else{
				Format(sUrl2, sizeof(sUrl2), "http://%s", sUrl);
			}
			Format(g_sUrlName[iEnt], sizeof(g_sUrlName[]), sUrl2);
			ChangeBeam(iClient, iEnt);
			Format(sTemp, sizeof(sTemp), "Url set to {green}%s{default}", sUrl2);
			CelModClient(iClient, sTemp);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Color(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!color{default} <color>");
		return Plugin_Handled;
	}
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		decl String:sAlias[64], String:sColor[128], String:sColorBuffer[3][128], String:sR[32], String:sG[32], String:sB[32], String:sClassname[256];
		GetCmdArg(1, sAlias, sizeof(sAlias));
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			if(StrEqual(sAlias, "rainbow", false))
			{
				g_bColorRainbow[iEnt] = true;
				FormatEx(g_sColorName[iEnt], sizeof(g_sColorName[]), "rainbow");
			}else{
				new Handle:hColors = CreateKeyValues("Colors");
				FileToKeyValues(hColors, g_sColorsPath);
				KvGetString(hColors, sAlias, sColor, sizeof(sColor), "null");
				if(StrContains(sColor, "null", false) != -1)
				{
					if(StrContains(sAlias, "1", false) != -1)
					{
						ReplaceString(sAlias, sizeof(sAlias), "1", "");
					}else{
						Format(sAlias, sizeof(sAlias), "%s1", sAlias);
					}
					KvGetString(hColors, sAlias, sColor, sizeof(sColor), "null");
					if(StrContains(sColor, "null", false) != -1)
					{
						CelModClient(iClient, "Color not found!");
						CloseHandle(hColors);
						return Plugin_Handled;
					}
				}
			}
			GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
			if(StrEqual(sAlias, "rainbow", false))
			{
				if(StrEqual(sClassname, "emblem_black", true))
				{
					CannotColorEmblems(iClient);
					return Plugin_Handled;
				}else{
					g_bColorRainbow[iEnt] = true;
					Format(g_sColorName[iEnt], sizeof(g_sColorName[]), "rainbow");
					g_iRainbowNumber[iClient] = 0;
				}
			}else{
				g_bColorRainbow[iEnt] = false;
			}
			ExplodeString(sColor, "^", sColorBuffer, 3, sizeof(sColorBuffer[]));
			strcopy(sR, sizeof(sR), sColorBuffer[0]);
			strcopy(sG, sizeof(sG), sColorBuffer[1]);
			strcopy(sB, sizeof(sB), sColorBuffer[2]);
			new iR = StringToInt(sR), iG = StringToInt(sG), iB = StringToInt(sB);
			new iColor = GetEntSendPropOffs(iEnt, "m_clrRender", false);
			new iA = GetEntData(iEnt, iColor + 3, 1);
			if(StrEqual(sClassname, "emblem_black", true))
			{
				CannotColorEmblems(iClient);
			}else{
				SetEntityRenderColor(iEnt, iR, iG, iB, iA);
				g_iPropColor[iEnt][0] = iR;
				g_iPropColor[iEnt][1] = iG;
				g_iPropColor[iEnt][2] = iB;
				g_iPropColor[iEnt][3] = iA;
				Format(g_sColorName[iEnt], sizeof(g_sColorName[]), sAlias);
				ChangeBeam(iClient, iEnt);
			}
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_HudColor(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!hudcolor{default} <color>");
		return Plugin_Handled;
	}
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		decl String:sAlias[64], String:sColor[128], String:sColorBuffer[3][128], String:sR[32], String:sG[32], String:sB[32];
		GetCmdArg(1, sAlias, sizeof(sAlias));
		if(StrEqual(sAlias, "rainbow", false))
		{
			g_bHudRainbow[iClient] = true;
		}else{
			new Handle:hColors = CreateKeyValues("Colors");
			FileToKeyValues(hColors, g_sColorsPath);
			KvGetString(hColors, sAlias, sColor, sizeof(sColor), "null");
			if(StrContains(sColor, "null", false) != -1)
			{
				if(StrContains(sAlias, "1", false) != -1)
				{
					ReplaceString(sAlias, sizeof(sAlias), "1", "");
				}else{
					Format(sAlias, sizeof(sAlias), "%s1", sAlias);
				}
				KvGetString(hColors, sAlias, sColor, sizeof(sColor), "null");
				if(StrContains(sColor, "null", false) != -1)
				{
					CelModClient(iClient, "Color not found!");
					CloseHandle(hColors);
					return Plugin_Handled;
				}
			}
		}
		if(StrEqual(sAlias, "rainbow", false))
		{
			g_bHudRainbow[iClient] = true;
			g_iRainbowHudNumber[iClient] = 0;
		}else{
			g_bHudRainbow[iClient] = false;
		}
		ExplodeString(sColor, "^", sColorBuffer, 3, sizeof(sColorBuffer[]));
		strcopy(sR, sizeof(sR), sColorBuffer[0]);
		strcopy(sG, sizeof(sG), sColorBuffer[1]);
		strcopy(sB, sizeof(sB), sColorBuffer[2]);
		new iR = StringToInt(sR), iG = StringToInt(sG), iB = StringToInt(sB);
		g_iHudRed[iClient] = iR;
		g_iHudGreen[iClient] = iG;
		g_iHudBlue[iClient] = iB;
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Owner(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEnt = GetClientAimTarget(iClient, false);
	decl String:sTemp[256], String:sClassname[256];
	GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
	if(StrEqual(sClassname, "player", true))
	{
		Format(sTemp, sizeof(sTemp), "The players name is {green}%N{default}.", iEnt);
	}else{
		Format(sTemp, sizeof(sTemp), "The owner of entity #{green}%d{default} is {green}%N{default}.", iEnt, g_iOwner[iEnt]);
	}
	CelModClient(iClient, sTemp);
	return Plugin_Handled;
}

public Action:Command_Alpha(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!amt{default} <alpha>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	decl String:sAlpha[64];
	GetCmdArg(1, sAlpha, sizeof(sAlpha));
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			new iA = StringToInt(sAlpha);
			SetEntityRenderMode(iEnt, RENDER_TRANSALPHA);
			SetEntityRenderColor(iEnt, g_iPropColor[iEnt][0], g_iPropColor[iEnt][1], g_iPropColor[iEnt][2], iA);
			g_iPropColor[iEnt][3] = iA;
			ChangeBeam(iClient, iEnt);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Solid(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!solid{default} <on/off>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	decl String:sOption[64];
	GetCmdArg(1, sOption, sizeof(sOption));
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			if(StrEqual(sOption, "on", false))
			{
				DispatchKeyValue(iEnt, "solid", "6");
				CelModClient(iClient, "Turned solidity on.");
			}else if(StrEqual(sOption, "off", false))
			{
				DispatchKeyValue(iEnt, "solid", "4");
				CelModClient(iClient, "Turned solidity off.");
			}else{
				CelModClient(iClient, "Invalid input specified. Use 'on' or 'off'.");
			}
			ChangeBeam(iClient, iEnt);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Rotate(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!rotate{default} <degree>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	decl String:sDegree[64];
	decl Float:fAngles[3], Float:fFinalAngles[3];
	GetCmdArg(1, sDegree, sizeof(sDegree));
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			new iY = StringToInt(sDegree);
			GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
			fFinalAngles[1] = (fAngles[1] += iY);
			TeleportEntity(iEnt, NULL_VECTOR, fFinalAngles, NULL_VECTOR);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Flip(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!flip{default} <degree>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	decl String:sDegree[64];
	decl Float:fAngles[3], Float:fFinalAngles[3];
	GetCmdArg(1, sDegree, sizeof(sDegree));
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			new iX = StringToInt(sDegree);
			GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
			fFinalAngles[0] = (fAngles[0] += iX);
			TeleportEntity(iEnt, NULL_VECTOR, fFinalAngles, NULL_VECTOR);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Roll(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!roll{default} <degree>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	decl String:sDegree[64];
	decl Float:fAngles[3], Float:fFinalAngles[3];
	GetCmdArg(1, sDegree, sizeof(sDegree));
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			new iZ = StringToInt(sDegree);
			GetEntPropVector(iEnt, Prop_Send, "m_angRotation", fAngles);
			fFinalAngles[2] = (fAngles[2] += iZ);
			TeleportEntity(iEnt, NULL_VECTOR, fFinalAngles, NULL_VECTOR);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Straight(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	decl Float:fAngles[3];
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			fAngles[0] = 0.0;
			fAngles[1] = 0.0;
			fAngles[2] = 0.0;
			TeleportEntity(iEnt, NULL_VECTOR, fAngles, NULL_VECTOR);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_SMove(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!smove{default} <x> <y> <z>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	decl String:sX[64], String:sY[64], String:sZ[64];
	decl Float:fOrigin[3], Float:fFinalOrigin[3];
	GetCmdArg(1, sX, sizeof(sX));
	GetCmdArg(2, sY, sizeof(sY));
	GetCmdArg(3, sZ, sizeof(sZ));
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			new iX = StringToInt(sX), iY = StringToInt(sY), iZ = StringToInt(sZ);
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fOrigin);
			fFinalOrigin[0] = (fOrigin[0] += iX);
			fFinalOrigin[1] = (fOrigin[1] += iY);
			fFinalOrigin[2] = (fOrigin[2] += iZ);
			TeleportEntity(iEnt, fFinalOrigin, NULL_VECTOR, NULL_VECTOR);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_ColorAll(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!colorall{default} <color>");
		return Plugin_Handled;
	}
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		decl String:sAlias[64], String:sColor[128], String:sColorBuffer[3][128], String:sR[32], String:sG[32], String:sB[32], String:sClassname[256];
		GetCmdArg(1, sAlias, sizeof(sAlias));
		for(new iEnt = 0; iEnt < GetMaxEntities(); iEnt++)
		{
			if(CheckOwner(iClient, iEnt))
			{
				if(StrEqual(sAlias, "rainbow", false))
				{
					g_bColorRainbow[iEnt] = true;
					FormatEx(g_sColorName[iEnt], sizeof(g_sColorName[]), "rainbow");
				}else{
					new Handle:hColors = CreateKeyValues("Colors");
					FileToKeyValues(hColors, g_sColorsPath);
					KvGetString(hColors, sAlias, sColor, sizeof(sColor), "null");
					if(StrContains(sColor, "null", false) != -1)
					{
						if(StrContains(sAlias, "1", false) != -1)
						{
							ReplaceString(sAlias, sizeof(sAlias), "1", "");
						}else{
							Format(sAlias, sizeof(sAlias), "%s1", sAlias);
						}
						KvGetString(hColors, sAlias, sColor, sizeof(sColor), "null");
						if(StrContains(sColor, "null", false) != -1)
						{
							CelModClient(iClient, "Color not found!");
							CloseHandle(hColors);
							return Plugin_Handled;
						}
					}
				}
				GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
				if(StrEqual(sAlias, "rainbow", false))
				{
					if(StrEqual(sClassname, "emblem_black", true))
					{
						CannotColorEmblems(iClient);
						return Plugin_Handled;
					}else{
						g_bColorRainbow[iEnt] = true;
						Format(g_sColorName[iEnt], sizeof(g_sColorName[]), "rainbow");
						g_iRainbowNumber[iClient] = 0;
					}
				}else{
					g_bColorRainbow[iEnt] = false;
				}
				ExplodeString(sColor, "^", sColorBuffer, 3, sizeof(sColorBuffer[]));
				strcopy(sR, sizeof(sR), sColorBuffer[0]);
				strcopy(sG, sizeof(sG), sColorBuffer[1]);
				strcopy(sB, sizeof(sB), sColorBuffer[2]);
				new iR = StringToInt(sR), iG = StringToInt(sG), iB = StringToInt(sB);
				new iColor = GetEntSendPropOffs(iEnt, "m_clrRender", false);
				new iA = GetEntData(iEnt, iColor + 3, 1);
				if(StrEqual(sClassname, "emblem_black", true))
				{
					CannotColorEmblems(iClient);
				}else{
					SetEntityRenderColor(iEnt, iR, iG, iB, iA);
					g_iPropColor[iEnt][0] = iR;
					g_iPropColor[iEnt][1] = iG;
					g_iPropColor[iEnt][2] = iB;
					g_iPropColor[iEnt][3] = iA;
					Format(g_sColorName[iEnt], sizeof(g_sColorName[]), sAlias);
				}
			}
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_SpecialSpawn(iClient, iArgs)
{
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!cm_specialspawn{default} <model> <classname> <target> <skin>");
		return Plugin_Handled;
	}
	if(iArgs < 2)
	{
		CelModClient(iClient, "Usage: {green}!cm_specialspawn{default} <model> <classname> <target> <skin>");
		return Plugin_Handled;
	}
	if(iArgs < 3)
	{
		CelModClient(iClient, "Usage: {green}!cm_specialspawn{default} <model> <classname> <target> <skin>");
		return Plugin_Handled;
	}
	decl String:sModel[256], String:sClassname[256], String:sTarget[256], String:sSkin[256];
	decl Float:fAngles[3], Float:fOrigin[3];
	GetCmdArg(1, sModel, sizeof(sModel));
	GetCmdArg(2, sClassname, sizeof(sClassname));
	GetCmdArg(3, sTarget, sizeof(sTarget));
	GetCmdArg(4, sSkin, sizeof(sSkin));
	GetClientAbsAngles(iClient, fAngles);
	GetHitOrigin(iClient, fOrigin);
	new iTarget = FindTarget(iClient, sTarget, false, false);
	new iEnt = CreateEntityByName("prop_physics_override");
	PrecacheModel(sModel);
	DispatchKeyValue(iEnt, "model", sModel);
	DispatchKeyValue(iEnt, "classname", sClassname);
	DispatchKeyValue(iEnt, "skin", sSkin);
	DispatchSpawn(iEnt);
	TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);
	g_iOwner[iEnt] = iTarget;
	g_iCelCount[iTarget]++;
	if(StrEqual(sClassname, "emblem_black", true))
	{
		Format(g_sEmblemName[iEnt], sizeof(g_sEmblemName[]), "black");
	}
	return Plugin_Handled;
}

public Action:Command_Door(iClient, iArgs)
{
	decl String:sTemp[256], String:sDoorSkin[64];
	decl Float:fOrigin[3];
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!door{default} <skin>");
		return Plugin_Handled;
	}
	GetCmdArg(1, sDoorSkin, sizeof(sDoorSkin));
	if(g_iCelCount[iClient] > g_iCelLimit)
	{
		Format(sTemp, sizeof(sTemp), "You've reached your max cel count(%d).", g_iCelLimit);
		CelModClient(iClient, sTemp);
		return Plugin_Handled;
	}
	if(g_fSpawnTime[iClient] < GetGameTime() - 1)
	{
		GetHitOrigin(iClient, fOrigin);
		new iEnt = CreateEntityByName("prop_door_rotating");
		DispatchKeyValue(iEnt, "model", "models/props_c17/door01_left.mdl");
		DispatchKeyValue(iEnt, "classname", "cel_door");
		DispatchKeyValue(iEnt, "skin", sDoorSkin);
		DispatchKeyValue(iEnt, "distance", "90");
		DispatchKeyValue(iEnt, "speed", "100");
		DispatchKeyValue(iEnt, "returndelay", "-1");
		DispatchKeyValue(iEnt, "dmg", "20");
		DispatchKeyValue(iEnt, "opendir", "0");
		DispatchKeyValue(iEnt, "spawnflags", "8192");
		DispatchKeyValue(iEnt, "OnFullyOpen", "!caller,close,,3,-1");
		DispatchSpawn(iEnt);
		fOrigin[2] += 54;
		TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
		g_iOwner[iEnt] = iClient;
		g_iCelCount[iClient]++;
		Format(g_sColorName[iEnt], sizeof(g_sColorName[]), "white");
		Format(g_sPropName[iEnt], sizeof(g_sPropName[]), "door");
		g_fSpawnTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Ignite(iClient, iArgs)
{
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!ignite{default} <seconds>");
		return Plugin_Handled;
	}
	decl String:sSeconds[64];
	GetCmdArg(1, sSeconds, sizeof(sSeconds));
	if(g_fCommandTime[iClient] < GetGameTime() - 1)
	{
		new iEnt = GetClientAimTarget(iClient, false);
		if(CheckOwner(iClient, iEnt))
		{
			IgniteEnt(iEnt, sSeconds);
			ChangeBeam(iClient, iEnt);
		}else{
			NotYours(iClient);
		}
		g_fCommandTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_HeadcrabCan(iClient, iArgs)
{
	decl Float:fOrigin[3];
	GetHitOrigin(iClient, fOrigin);
	new iCanister = CreateEntityByName("env_headcrabcanister");
	DispatchKeyValue(iCanister, "HeadcrabType", "0");
	DispatchKeyValue(iCanister, "HeadcrabCount", "0");
	DispatchKeyValue(iCanister, "FlightSpeed", "5");
	DispatchKeyValue(iCanister, "FlightTime", "15");
	DispatchKeyValue(iCanister, "StartingHeight", "35");
	DispatchKeyValue(iCanister, "SkyboxcanisterCount", "1");
	DispatchKeyValue(iCanister, "Damage", "100");
	DispatchKeyValue(iCanister, "DamageRadius", "25");
	DispatchKeyValue(iCanister, "SmokeLifetime", "1");
	TeleportEntity(iCanister, fOrigin, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iCanister, "FireCanister");
	return Plugin_Handled;
}

public Action:Command_Sound(iClient, iArgs)
{
	decl Float:fAngles[3], Float:fOrigin[3];
	decl String:sAlias[64], String:sSoundsName[128], String:sTemp[256];
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!sound{default} <sound alias>");
		CelModClient(iClient, "Type {green}!soundlist{default} for a list of sound aliases.");
		return Plugin_Handled;
	}
	if(g_iCelCount[iClient] > g_iCelLimit)
	{
		Format(sTemp, sizeof(sTemp), "You've reached your max cel count(%d).", g_iCelLimit);
		CelModClient(iClient, sTemp);
		return Plugin_Handled;
	}
	GetCmdArg(1, sAlias, sizeof(sAlias));
	if(g_fSpawnTime[iClient] < GetGameTime() - 1)
	{
		new Handle:hSounds = CreateKeyValues("Sounds");
		FileToKeyValues(hSounds, g_sSoundsPath);
		KvGetString(hSounds, sAlias, sSoundsName, sizeof(sSoundsName), "null");
		if(StrContains(sSoundsName, "null", false) != -1)
		{
			if(StrContains(sAlias, "1", false) != -1)
			{
				ReplaceString(sAlias, sizeof(sAlias), "1", "");
			}else{
				Format(sAlias, sizeof(sAlias), "%s1", sAlias);
			}
			KvGetString(hSounds, sAlias, sSoundsName, sizeof(sSoundsName), "null");
			if(StrContains(sSoundsName, "null", false) != -1)
			{
				CelModClient(iClient, "Prop not found!");
				CloseHandle(hSounds);
				return Plugin_Handled;
			}
		}
		GetClientAbsAngles(iClient, fAngles);
		GetHitOrigin(iClient, fOrigin);
		new iEnt = CreateEntityByName("prop_physics_override");
		PrecacheModel("models/props_junk/popcan01a.mdl");
		DispatchKeyValue(iEnt, "model", "models/props_junk/popcan01a.mdl");
		DispatchKeyValue(iEnt, "classname", "cel_sound");
		DispatchSpawn(iEnt);
		TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);
		g_iCelCount[iClient]++;
		Format(g_sSoundName[iEnt], sizeof(g_sSoundName[]), sAlias);
		Format(g_sSoundPath[iEnt], sizeof(g_sSoundPath[]), sSoundsName);
		PrecacheSound(sSoundsName);
		g_iOwner[iEnt] = iClient;
		Format(g_sColorName[iEnt], sizeof(g_sColorName[]), "orange");
		SetEntityColor(iEnt, 255, 128, 0);
		new iColor = GetEntSendPropOffs(iEnt, "m_clrRender", false);
		new iA = GetEntData(iEnt, iColor + 3, 1);
		g_iPropColor[iEnt][0] = 255;
		g_iPropColor[iEnt][1] = 128;
		g_iPropColor[iEnt][2] = 0;
		g_iPropColor[iEnt][3] = iA;
		g_fSpawnTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}

public Action:Command_Music(iClient, iArgs)
{
	decl Float:fAngles[3], Float:fOrigin[3];
	decl String:sAlias[64], String:sMusicName[128], String:sMusicBuffer[2][128], String:sTemp[256];
	if(iArgs < 1)
	{
		CelModClient(iClient, "Usage: {green}!music{default} <song alias>");
		CelModClient(iClient, "Type {green}!musiclist{default} for a list of song aliases.");
		return Plugin_Handled;
	}
	if(g_iCelCount[iClient] > g_iCelLimit)
	{
		Format(sTemp, sizeof(sTemp), "You've reached your max cel count(%d).", g_iCelLimit);
		CelModClient(iClient, sTemp);
		return Plugin_Handled;
	}
	GetCmdArg(1, sAlias, sizeof(sAlias));
	if(g_fSpawnTime[iClient] < GetGameTime() - 1)
	{
		new Handle:hMusic = CreateKeyValues("Music");
		FileToKeyValues(hMusic, g_sMusicPath);
		KvGetString(hMusic, sAlias, sMusicName, sizeof(sMusicName), "null");
		if(StrContains(sMusicName, "null", false) != -1)
		{
			if(StrContains(sAlias, "1", false) != -1)
			{
				ReplaceString(sAlias, sizeof(sAlias), "1", "");
			}else{
				Format(sAlias, sizeof(sAlias), "%s1", sAlias);
			}
			KvGetString(hMusic, sAlias, sMusicName, sizeof(sMusicName), "null");
			if(StrContains(sMusicName, "null", false) != -1)
			{
				CelModClient(iClient, "Song not found!");
				CloseHandle(hMusic);
				return Plugin_Handled;
			}
		}
		ExplodeString(sMusicName, "^", sMusicBuffer, 2, sizeof(sMusicBuffer[]));
		GetClientAbsAngles(iClient, fAngles);
		GetHitOrigin(iClient, fOrigin);
		new iEnt = CreateEntityByName("prop_physics_override");
		PrecacheModel("models/props_lab/citizenradio.mdl");
		DispatchKeyValue(iEnt, "model", "models/props_lab/citizenradio.mdl");
		DispatchKeyValue(iEnt, "classname", "cel_music");
		DispatchSpawn(iEnt);
		TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);
		g_iCelCount[iClient]++;
		Format(g_sSongName[iEnt], sizeof(g_sSongName[]), sAlias);
		Format(g_sSongPath[iEnt], sizeof(g_sSongPath[]), sMusicBuffer[0]);
		PrecacheSound(sMusicBuffer[0]);
		g_iOwner[iEnt] = iClient;
		Format(g_sColorName[iEnt], sizeof(g_sColorName[]), "green");
		SetEntityColor(iEnt, 0, 255, 0);
		new iColor = GetEntSendPropOffs(iEnt, "m_clrRender", false);
		new iA = GetEntData(iEnt, iColor + 3, 1);
		g_iPropColor[iEnt][0] = 0;
		g_iPropColor[iEnt][1] = 255;
		g_iPropColor[iEnt][2] = 0;
		g_iPropColor[iEnt][3] = iA;
		g_fSpawnTime[iClient] = GetGameTime();
	}else{
		TooFast(iClient);
	}
	return Plugin_Handled;
}
