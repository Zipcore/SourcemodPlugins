#include <sourcemod>
#include <sdktools>
#include <morecolors>

#define NAME "[BuildMod] - Old"
#define AUTHOR "FusionLock"
#define DESCRIPTION "A mod that contains commands to control & manipulate entites."
#define VERSION "1.3.0"
#define URL "xfusionlockx.tk"

#define MAX_ENTITES 2048

new redColor[4] = {255, 0, 0, 200};
new orangeColor[4] = {255, 128, 0, 200};
new yellowColor[4] = {255, 255, 0, 200};
new greenColor[4] = {0, 255, 0, 200};
new blueColor[4] = {0, 0, 255, 200};
new physWhite[4] = {255, 255, 255, 200};
new greyColor[4] = {255, 255, 255, 300};

new tHalo;
new tBeam;
new tLaser;
new tPhys
new Server_Prop_Limit;
new Client_Prop_Count[MAXPLAYERS + 1];
new Entity_Owner[MAX_ENTITES + 1];
new Entity_Color[MAX_ENTITES + 1][4];
new Copied_Color[MAXPLAYERS + 1][4];
new Entity_Grab[MAXPLAYERS + 1];

new String:PropsPath[128];
new String:ColorsPath[128];
new String:Internet_URL[MAX_ENTITES + 1][256];
new String:Button_Command[MAX_ENTITES + 1][1024];
new String:Client_AuthID[MAXPLAYERS + 1][1024];
new String:Copied_Model[MAXPLAYERS + 1][1024];
new String:Copied_Name[MAXPLAYERS + 1][256];
new String:Entity_Name[MAX_ENTITES + 1][256];

new bool:NoPropInQueue[MAXPLAYERS + 1];
new bool:Client_GodMode[MAXPLAYERS + 1];
new bool:Client_HUD[MAXPLAYERS + 1];
new bool:Plugin_Enabled;

new Float:LastEUse[MAXPLAYERS + 1];
new Float:Grab_Origin[MAXPLAYERS + 1][3];

new Handle:hPlugin_Enabled = INVALID_HANDLE;
new Handle:hServer_Prop_Limit = INVALID_HANDLE;

//Plugin Information
public Plugin:myinfo = 
{
	name = NAME,
	author = AUTHOR,
	description = DESCRIPTION,
	version = VERSION,
	url = URL
}

//Plugin Start
public OnPluginStart()
{
	CreateConVar("buildmod_version", VERSION, "BuildMod version.", FCVAR_PLUGIN);
	hPlugin_Enabled = CreateConVar("bm_enabled", "1", "Toggles BuildMod on or off. (0 = Off, 1 = On)", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hServer_Prop_Limit = CreateConVar("bm_prop_limit", "350", "This sets the number of props players can spawn.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	
	HookConVarChange(hPlugin_Enabled, OnSettingsChange);
	HookConVarChange(hServer_Prop_Limit, OnSettingsChange);
	
	Plugin_Enabled = GetConVarBool(hPlugin_Enabled);
	Server_Prop_Limit = GetConVarInt(hServer_Prop_Limit);
	
	RegConsoleCmd("sm_spawn", Command_Spawn, "Spawns a prop by a model name.");
	RegConsoleCmd("sm_delete", Command_Remove, "Removes a prop.");
	RegConsoleCmd("sm_owner", Command_GetOwner, "Gets the owner of the prop you are looking at");
	RegConsoleCmd("sm_nokill", Command_GodMode, "Enables/disable godmode.");
	RegConsoleCmd("sm_freeze", Command_Freeze, "Freezes a prop.");
	RegConsoleCmd("sm_unfreeze", Command_UnFreeze, "Unfreezes a prop.");
	RegConsoleCmd("sm_internet", Command_SpawnInternet, "Spawns a internet cel");
	RegConsoleCmd("sm_seturl", Command_SetUrl, "Set's the url on a internet cel.");
	RegConsoleCmd("sm_geturl", Command_GetUrl, "Get's the url of an internet cel.");
	RegConsoleCmd("sm_link", Command_CommandLink, "Allows commands to be performed on a client using a button.");
	RegConsoleCmd("sm_changecommand", Command_ChangeCommand, "Changes the command of a link.");
	RegConsoleCmd("sm_rotate", Command_Rotate, "Rotates a prop.");
	RegConsoleCmd("sm_color", Command_Color, "Changes the color of a prop.");
	RegConsoleCmd("sm_flip", Command_Flip, "Flips a prop.");
	RegConsoleCmd("sm_amt", Command_Alpha, "Changes the alpha of a prop.");
	RegConsoleCmd("+grab", Command_Grab, "Grabs a prop.");
	RegConsoleCmd("-grab", Command_UnGrab, "Lets go of a prop.");
	RegConsoleCmd("sm_copy", Command_Copy, "Copies a prop.");
	RegConsoleCmd("sm_paste", Command_Paste, "Pasties a copied prop.");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	BuildPath(Path_SM, PropsPath, 128, "data/buildmod/props_db.txt");
	BuildPath(Path_SM, ColorsPath, 128, "data/buildmod/colors_db.txt");
}

//When a client first spawns in the server
public OnClientPutInServer(client)
{
	CreateTimer(0.1, HUD_TIMER, client, TIMER_REPEAT);
	SetOwner(client, client);
	Client_HUD[client] = true;
	NoPropInQueue[client] = true;
	Client_Prop_Count[client] = 0;
	Entity_Grab[client] = -1;
	decl String:AuthID[64];
	GetClientAuthString(client, AuthID, sizeof(AuthID)-1);
	ReplaceString(AuthID, sizeof(AuthID)-1, ":", "-");
	Format(Client_AuthID[client], sizeof(Client_AuthID[]), AuthID);
}

//When a client leaves the server
public OnClientDisconnect(client)
{
	Client_HUD[client] = false;
	for (new i = 0; i <= GetMaxEntities(); i++)
	{
		if (IsValidEntity(i) && Entity_Owner[i] == client)
		{
			decl String:cTargetname[64];
			GetEntPropString(i, Prop_Data, "m_iName", cTargetname, sizeof(cTargetname));
			
			if (StrContains(cTargetname, "BM:") != -1)
			{
				Entity_Dissolve(client, i);
			}
		}
	}
}

//When a convar get's changed
public OnSettingsChange(Handle:hCvar, const String:sOld[], const String:sNew[])
{
	decl String:cMessage[256];
	if(hCvar == hPlugin_Enabled)
	{
		Plugin_Enabled = bool:StringToInt(sNew);
		if(StrEqual(sNew, "0", true))
		{
			Format(cMessage, sizeof(cMessage), "BuildMod have been {olive}disabled{default}.");
		}else if(StrEqual(sNew, "1", true)){
			Format(cMessage, sizeof(cMessage), "BuildMod have been {olive}enabled{default}.");
		}
		Print_Message_To_All(cMessage);
	}else if(hCvar == hServer_Prop_Limit)
	{
		Server_Prop_Limit = StringToInt(sNew);
		Format(cMessage, sizeof(cMessage), "The prop limit has been changed to {olive}%s", sNew);
		Print_Message_To_All(cMessage);
	}
	
}

//Client spawn
public Action:Event_PlayerSpawn(Handle:Event, const String:Name[], bool:dontBroadcast) 
{
	decl client;
	client = GetClientOfUserId(GetEventInt(Event, "userid"));
	if(!Plugin_Enabled)
	{
		
	}else{
		God_Client(client);
		Print_Message_To_Client(client, "You have spawned with godmode enabled. Use {olive}!nokill{default} to disable/enable godmode.");
	}
}

//Map Start
public OnMapStart()
{
	PrecacheSound("UI/hint.wav");
	tHalo = PrecacheModel("materials/sprites/halo01.vmt", true);
	tBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	tLaser = PrecacheModel("materials/sprites/laser.vmt", false);
	tPhys = PrecacheModel("materials/sprites/physbeam.vmt", false);
	CreateTimer(0.1, Timer_Grab, _, TIMER_REPEAT);
}

//OnGameFrame
public OnGameFrame()
{
	for(new client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(IsPlayerAlive(client))
			{
				if(GetClientButtons(client) & IN_USE)
				{
					if(LastEUse[client] <= GetGameTime() - 1)
					{
						new entity = GetClientAimTarget(client, false);
						if(GetClientAimTarget(client, false) == -1)
						{
							
						}else{
							decl String:eClassname[256];
							GetEntityClassname(entity, eClassname, sizeof(eClassname));
							if(StrEqual(eClassname, "cel_internet", true))
							{
								UseInternet(client, entity);
							}else if(StrEqual(eClassname, "cel_buttonlink", true))
							{
								UseButton(client, entity);
							}
							LastEUse[client] = GetGameTime();
						}
					}
				}
			}
		}
	}
}

//Plugin Stocks
stock Print_Message_To_Client(target, String:Message[])
{
	CPrintToChat(target, "{blue}[BuildMod]{default} %s", Message);
}

stock Print_Message_To_All(String:Message[])
{
	CPrintToChatAll("{blue}[BM]{default} %s", Message);
}

stock NotYours(client, entity)
{
	decl String:cMessage[256];
	Format(cMessage, sizeof(cMessage), "That prop doesn't belong to you! It belongs to {olive}%N{default}!", GetOwner(client, entity));
	Print_Message_To_Client(client, cMessage);
}

stock NotLooking(client)
{
	Print_Message_To_Client(client, "You arn't looking at anything!");
}

stock AddPropToClientPropCount(client)
{
	Client_Prop_Count[client]++;
}

stock RemovePropFromClientPropCount(client, entity)
{
	Client_Prop_Count[Entity_Owner[entity]] -= 1;
}

stock Entity_Dissolve(client, entity)
{
	decl String:eTargetname[256];
	Format(eTargetname, sizeof(eTargetname), "dissolve%N%f", GetOwner(client, entity), GetRandomFloat());
	DispatchKeyValue(entity, "targetname", eTargetname);
	new eDissolve = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(eDissolve, "dissolvetype", "3");
	DispatchKeyValue(eDissolve, "target", eTargetname);
	AcceptEntityInput(eDissolve, "dissolve");
	RemovePropFromClientPropCount(client, entity);
	AcceptEntityInput(eDissolve, "kill");
}

stock Entity_Motion(client, entity, String:eMotion[])
{
	if(StrEqual(eMotion, "disable", true))
	{
		AcceptEntityInput(entity, "disablemotion");
	}else if(StrEqual(eMotion, "enable", true))
	{
		AcceptEntityInput(entity, "enablemotion");
	}
}

stock Entity_Targetname(client, entity)
{
	decl String:eTargetname[256], String:cAuthID[256];
	GetClientAuthString(client, cAuthID, sizeof(cAuthID));
	Format(eTargetname, sizeof(eTargetname), "BM:%s", cAuthID);
	DispatchKeyValue(entity, "targetname", eTargetname);
}

stock SetOwner(client, entity)
{
	Entity_Owner[entity] = client;
}

stock GetOwner(client, entity)
{
	return Entity_Owner[entity];
}

stock CheckOwner(client, entity)
{
	if(Entity_Owner[entity] == client)
	{
		return true;
	}
	return false;
}

stock Crosshair_HitPoint(client, Float:ePos[3])
{
	decl Float:cOrigin[3], Float:cAngles[3];
	GetClientEyePosition(client, cOrigin);
	GetClientEyeAngles(client, cAngles);
	new Handle:eTrace = TR_TraceRayFilterEx(cOrigin, cAngles, MASK_SOLID, RayType_Infinite, TracePlayers);
	if(TR_DidHit(eTrace))
	{
		TR_GetEndPosition(ePos, eTrace);
		CloseHandle(eTrace);
		return;
	}
	CloseHandle(eTrace);
}

stock God_Client(client)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	Client_GodMode[client] = true;
}

stock Ungod_Client(client)
{
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
	Client_GodMode[client] = false;
}

stock SetUrl(entity, String:cUrl[])
{
	Format(Internet_URL[entity], sizeof(Internet_URL[]), "%s", cUrl);
}

stock UseInternet(client, entity)
{
	if(!Plugin_Enabled)
	{
		
	}else{
		ShowMOTDPanel(client, "Internet", Internet_URL[entity], MOTDPANEL_TYPE_URL); 
	}
}

stock UseButton(client, entity)
{
	if(!Plugin_Enabled)
	{
		
	}else{
		FakeClientCommand(GetOwner(client, entity), Button_Command[entity]);
	}
}

stock NormalBeam(client, entity, String:colorChoice[])
{
	decl Float:cAngles[3], Float:cOrigin[3], Float:eOrigin[3];
	GetClientAbsOrigin(client, cOrigin);
	GetClientEyeAngles(client, cAngles);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", eOrigin);
	if(StrEqual(colorChoice, "red", true))
	{
		TE_SetupBeamPoints(cOrigin, eOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, redColor, 10);
		TE_SendToAll();
	}else if(StrEqual(colorChoice, "orange", true))
	{
		TE_SetupBeamPoints(cOrigin, eOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, orangeColor, 10);
		TE_SendToAll();
	}else if(StrEqual(colorChoice, "yellow", true))
	{
		TE_SetupBeamPoints(cOrigin, eOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, yellowColor, 10);
		TE_SendToAll();
	}else if(StrEqual(colorChoice, "green", true))
	{
		TE_SetupBeamPoints(cOrigin, eOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, greenColor, 10);
		TE_SendToAll();
	}else if(StrEqual(colorChoice, "blue", true))
	{
		TE_SetupBeamPoints(cOrigin, eOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, blueColor, 10);
		TE_SendToAll();
	}else if(StrEqual(colorChoice, "white", true))
	{
		TE_SetupBeamPoints(cOrigin, eOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, physWhite, 10);
		TE_SendToAll();
	}else if(StrEqual(colorChoice, "grey", true))
	{
		TE_SetupBeamPoints(cOrigin, eOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, greyColor, 10);
		TE_SendToAll();
	}
	TE_SetupSparks(eOrigin, cAngles, 3, 2);
	TE_SendToAll();
	TE_SetupArmorRicochet(eOrigin, cAngles);
	TE_SendToAll();
}

stock DeleteBeam(client, entity)
{
	decl Float:cAngles[3], Float:cOrigin[3], Float:eOrigin[3];
	GetClientAbsOrigin(client, cOrigin);
	GetClientEyeAngles(client, cAngles);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", eOrigin);
	TE_SetupBeamPoints(cOrigin, eOrigin, tBeam, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, greyColor, 10);
	TE_SendToAll();
	TE_SetupSparks(eOrigin, cAngles, 3, 2);
	TE_SendToAll();
	TE_SetupArmorRicochet(eOrigin, cAngles);
	TE_SendToAll();
}

stock LinkBeam(client, Float:eOrigin1[3], Float:eOrigin2[3])
{
	decl Float:cAngles[3];
	GetClientEyeAngles(client, cAngles);
	TE_SetupBeamPoints(eOrigin1, eOrigin2, tLaser, tHalo, 0, 15, 0.8, 3.0, 3.0, 1, 0.0, orangeColor, 10);
	TE_SendToAll();
	TE_SetupSparks(eOrigin1, cAngles, 3, 2);
	TE_SendToAll();
	TE_SetupArmorRicochet(eOrigin1, cAngles);
	TE_SendToAll();
	TE_SetupSparks(eOrigin2, cAngles, 3, 2);
	TE_SendToAll();
	TE_SetupArmorRicochet(eOrigin2, cAngles);
	TE_SendToAll();
}

//Plugin Booleans
public bool:TracePlayers(entity, contentsMask)
{
	return entity > MaxClients;
}

//Plugin Timers
public Action:HUD_TIMER(Handle:timer, any:client)
{
	decl String:hMessage[256], String:eClassname[256];
	if(IsClientInGame(client) && IsClientConnected(client) && Client_HUD[client])
	{
		new entity = GetClientAimTarget(client, false);
		if(IsValidEntity(entity))
		{
			GetEntityClassname(entity, eClassname, sizeof(eClassname));
			if(StrEqual(eClassname, "player", true))
			{
				Format(hMessage, sizeof(hMessage), "Name: %N\nProps Spawned: %d", GetOwner(client, entity), Client_Prop_Count[entity]);
			}else if(StrEqual(eClassname, "cel_internet", true))
			{
				Format(hMessage, sizeof(hMessage), "Owner: %N\nUrl: %s", GetOwner(client, entity), Internet_URL[entity]);
			}else if(StrEqual(eClassname, "cel_buttonlink", true))
			{
				Format(hMessage, sizeof(hMessage), "Owner: %N\nCommand: %s", GetOwner(client, entity), Button_Command[entity]);
			}else if(CheckOwner(client, entity))
			{
				Format(hMessage, sizeof(hMessage), "Prop Name: %s", Entity_Name[entity]);
			}else{
				Format(hMessage, sizeof(hMessage), "Owner: %N\nProp Name: %s", GetOwner(client, entity), Entity_Name[entity]);
			}/*else{
			Format(hMessage, sizeof(hMessage), "Name: %N\nProps Spawned %d", client, Client_Prop_Count[client]);
			}*/
		}else{
			Format(hMessage, sizeof(hMessage), "");
		}
		PrintHintText(client, hMessage);
		StopSound(client, SNDCHAN_STATIC, "UI/hint.wav");
	}
}

public Action:Timer_Grab(Handle:hTimer)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && (Entity_Grab[i] != -1))
		{
			decl Float:eOrigin[3], Float:cOrigin[3];
			GetClientAbsOrigin(i, cOrigin);
			
			eOrigin[0] = cOrigin[0] + Grab_Origin[i][0];
			eOrigin[1] = cOrigin[1] + Grab_Origin[i][1];
			eOrigin[2] = cOrigin[2] + Grab_Origin[i][2];
			
			TeleportEntity(Entity_Grab[i], eOrigin, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

//Plugin Commands
public Action:Command_Spawn(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	decl String:cMessage[256], String:cAlias[256], String:cOption[256], String:propModel[256], String:propEntity[256];
	decl Float:cAngles[3], Float:chOrigin[3];
	GetCmdArg(1, cAlias, sizeof(cAlias));
	GetCmdArg(2, cOption, sizeof(cOption));
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_spawn <prop alias> <frozen|god>");
		return Plugin_Handled;
	}
	if(Client_Prop_Count[client] >= Server_Prop_Limit)
	{
		Format(cMessage, sizeof(cMessage), "You have spawned maximum props [{olive}%d{default}/{olive}%d{default}]", Client_Prop_Count[client], Server_Prop_Limit);
		Print_Message_To_Client(client, cMessage);
		return Plugin_Handled;
	}
	decl String:sPropString[128];
	
	// Attempt to match a model to the given prop alias:
	new Handle:PropsDB = CreateKeyValues("Props");
	FileToKeyValues(PropsDB, PropsPath);
	KvGetString(PropsDB, cAlias, sPropString, sizeof(sPropString), "Null");
	
	// If no model was found:
	if(StrContains(sPropString, "Null", false) != -1)
	{
		// Attempt to correct:
		if(StrContains(cAlias, "1", false) != -1)
			ReplaceString(cAlias, sizeof(cAlias), "1", "");
		
		else
		Format(cAlias, sizeof(cAlias), "%s1", cAlias);
		
		KvGetString(PropsDB, cAlias, sPropString, sizeof(sPropString), "Null");
		
		// If no model was found, cancel:
		if(StrContains(sPropString, "Null", false) != -1)
		{
			ReplaceString(cAlias, sizeof(cAlias), "1", "");
			Format(cMessage, sizeof(cMessage), "Prop {olive}%s{default} was not found!", cAlias);
			Print_Message_To_Client(client, cMessage);
			CloseHandle(PropsDB);
			return Plugin_Handled;
		}
	}
	
	CloseHandle(PropsDB);
	
	decl String:sPropBuffer[2][128];
	ExplodeString(sPropString, "^", sPropBuffer, 2, sizeof(sPropBuffer[]));
	
	strcopy(propModel, sizeof(propModel), sPropBuffer[0]);
	strcopy(propEntity, sizeof(propEntity), sPropBuffer[1]);
	GetClientAbsAngles(client, cAngles);
	Crosshair_HitPoint(client, chOrigin);
	new sEntity = CreateEntityByName(propEntity);
	PrecacheModel(propModel);
	DispatchKeyValue(sEntity, "model", propModel);
	DispatchSpawn(sEntity);
	TeleportEntity(sEntity, chOrigin, cAngles, NULL_VECTOR);
	if(StrEqual(cOption, "frozen", true))
	{
		AcceptEntityInput(sEntity, "disablemotion");
	}else if(StrEqual(cOption, "god", true))
	{
		SetEntProp(sEntity, Prop_Data, "m_takedamage", 0, 1);
	}else if(StrEqual(cOption, "", true))
	{
		//Do nothing. Just a check.
	}else{
		Format(cMessage, sizeof(cMessage), "{olive}%s{default} is not a valid option.", cOption);
		Print_Message_To_Client(client, cMessage);
	}
	SetOwner(client, sEntity);
	Entity_Name[sEntity] = cAlias;
	AddPropToClientPropCount(client);
	Entity_Targetname(client, sEntity);
	new color = GetEntSendPropOffs(sEntity, "m_clrRender", false);
	new red = GetEntData(sEntity, color, 1);
	new green = GetEntData(sEntity, color + 1, 1);
	new blue = GetEntData(sEntity, color + 2, 1);
	new alpha = GetEntData(sEntity, color + 3, 1);
	Entity_Color[sEntity][0] = red;
	Entity_Color[sEntity][1] = green;
	Entity_Color[sEntity][2] = blue;
	Entity_Color[sEntity][3] = alpha;
	return Plugin_Handled;
}

public Action:Command_Remove(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:eClassname[256];
	GetEntityClassname(entity, eClassname, sizeof(eClassname));
	if(CheckOwner(client, entity))
	{
		Entity_Dissolve(client, entity);
		if(StrEqual(eClassname, "cel_internet", true) || StrEqual(eClassname, "cel_buttonlink", true))
		{
			Print_Message_To_Client(client, "Your cel has been removed.");
		}else{
			Print_Message_To_Client(client, "Your prop has been removed.");
		}
		DeleteBeam(client, entity);
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_GetOwner(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:cMessage[256];
	Format(cMessage, sizeof(cMessage), "The prop belongs to {olive}%N{default}.", Entity_Owner[entity]);
	Print_Message_To_Client(client, cMessage);
	return Plugin_Handled;
}

public Action:Command_GodMode(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(Client_GodMode[client])
	{
		Ungod_Client(client);
		Print_Message_To_Client(client, "Your godmode has been disabled!");
	}else{
		God_Client(client);
		Print_Message_To_Client(client, "Your godmode has been enabled!");
	}
	return Plugin_Handled;
}

public Action:Command_Freeze(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	if(CheckOwner(client, entity))
	{
		Entity_Motion(client, entity, "disable");
		Print_Message_To_Client(client, "Your prop has been frozen.");
		NormalBeam(client, entity, "white");
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_UnFreeze(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	if(CheckOwner(client, entity))
	{
		Entity_Motion(client, entity, "enable");
		Print_Message_To_Client(client, "Your prop has been unfrozen.");
		NormalBeam(client, entity, "white");
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_SpawnInternet(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	decl Float:cAngles[3], Float:chOrigin[3];
	decl String:eModel[256], String:cUrl[256];
	Format(eModel, sizeof(eModel), "models/props_lab/monitor02.mdl");
	Format(cUrl, sizeof(cUrl), "http://voyagersclan.com");
	GetClientAbsAngles(client, cAngles);
	Crosshair_HitPoint(client, chOrigin);
	new cInternet = CreateEntityByName("prop_physics_override");
	PrecacheModel(eModel);
	DispatchKeyValue(cInternet, "classname", "cel_internet");
	DispatchKeyValue(cInternet, "model", eModel);
	DispatchSpawn(cInternet);
	TeleportEntity(cInternet, chOrigin, cAngles, NULL_VECTOR);
	SetUrl(cInternet, cUrl);
	SetOwner(client, cInternet);
	Entity_Targetname(client, cInternet);
	return Plugin_Handled;
}

public Action:Command_SetUrl(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_seturl <url>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	if(CheckOwner(client, entity))
	{
		decl String:eClassname[256], String:cUrl[256], String:fUrl[256], String:cMessage[256];
		GetCmdArg(1, cUrl, sizeof(cUrl));
		GetEntityClassname(entity, eClassname, sizeof(eClassname));
		if(StrEqual(eClassname, "cel_internet", true))
		{
			Format(fUrl, sizeof(fUrl), "http://%s", cUrl);
			SetUrl(entity, fUrl);
			NormalBeam(client, entity, "white");
			Format(cMessage, sizeof(cMessage), "Internet url has been set to {olive}%s{default}.", Internet_URL[entity]);
			Print_Message_To_Client(client, cMessage);
		}
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_GetUrl(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:eClassname[256];
	GetEntityClassname(entity, eClassname, sizeof(eClassname));
	if(StrEqual(eClassname, "cel_internet", true))
	{
		decl String:cMessage[256];
		Format(cMessage, sizeof(cMessage), "Internet URL: {olive}%s{default}.", Internet_URL[entity]);
		Print_Message_To_Client(client, cMessage);
	}
	return Plugin_Handled;
}

public Action:Command_CommandLink(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_link <command>");
		return Plugin_Handled;
	}
	decl Float:cOrigin[3], Float:cAngles[3], Float:chOrigin[3], Float:eOrigin[3];
	decl String:bCommand[256];
	GetClientAbsAngles(client, cAngles);
	Crosshair_HitPoint(client, chOrigin);
	new lEntity = CreateEntityByName("prop_physics_override");
	PrecacheModel("models/props_junk/popcan01a.mdl");
	DispatchKeyValue(lEntity, "model", "models/props_junk/popcan01a.mdl");
	DispatchSpawn(lEntity);
	TeleportEntity(lEntity, chOrigin, cAngles, NULL_VECTOR);
	GetCmdArgString(bCommand, sizeof(bCommand));
	DispatchKeyValue(lEntity, "classname", "cel_buttonlink");
	Format(Button_Command[lEntity], sizeof(Button_Command), bCommand);
	GetEntPropVector(lEntity, Prop_Data, "m_vecOrigin", eOrigin);
	GetClientAbsOrigin(client, cOrigin);
	Print_Message_To_Client(client, "Created link.");
	LinkBeam(client, cOrigin, eOrigin);
	SetOwner(client, lEntity);
	Entity_Targetname(client, lEntity);
	return Plugin_Handled;
}

public Action:Command_ChangeCommand(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_changecommand <command>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:bCommand[256], String:cMessage[256];
	GetCmdArgString(bCommand, sizeof(bCommand));
	if(CheckOwner(client, entity))
	{
		Format(Button_Command[entity], sizeof(Button_Command), bCommand);
		Format(cMessage, sizeof(cMessage), "Command set to {olive}%s{default}.", bCommand);
		Print_Message_To_Client(client, cMessage);
		NormalBeam(client, entity, "white");
	}
	return Plugin_Handled;
}

public Action:Command_Rotate(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_rotate <degrees>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:sDegree[256];
	decl Float:cAngles[3], Float:fAngles[3];
	GetCmdArg(1, sDegree, sizeof(sDegree));
	if(CheckOwner(client, entity))
	{
		new Y = StringToInt(sDegree);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", cAngles);
		fAngles[1] = (cAngles[1] += Y);
		TeleportEntity(entity, NULL_VECTOR, fAngles, NULL_VECTOR);
		Print_Message_To_Client(client, "Your prop has been rotated.");
		NormalBeam(client, entity, "white");
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_Flip(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_flip <degrees>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:sDegree[256];
	decl Float:cAngles[3], Float:fAngles[3];
	GetCmdArg(1, sDegree, sizeof(sDegree));
	if(CheckOwner(client, entity))
	{
		new X = StringToInt(sDegree);
		GetEntPropVector(entity, Prop_Send, "m_angRotation", cAngles);
		fAngles[0] = (cAngles[0] += X);
		TeleportEntity(entity, NULL_VECTOR, fAngles, NULL_VECTOR);
		Print_Message_To_Client(client, "Your prop has been flipped.");
		NormalBeam(client, entity, "white");
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_Color(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_color <color>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:sColor[256], String:cMessage[256], String:colorName[128], String:colorBuffer[3][128], String:sR[64], String:sG[64], String:sB[64];
	GetCmdArg(1, sColor, sizeof(sColor));
	if(CheckOwner(client, entity))
	{
		new color = GetEntSendPropOffs(entity, "m_clrRender", false);
		new alpha = GetEntData(entity, color + 3, 1);
		new Handle:ColorDB = CreateKeyValues("Colors");
		FileToKeyValues(ColorDB, ColorsPath);
		KvGetString(ColorDB, sColor, colorName, sizeof(colorName), "Null");
		if(StrContains(colorName, "Null", false) != -1)
		{
			if(StrContains(sColor, "1", false) != -1)
				ReplaceString(sColor, sizeof(sColor), "1", "");
			
			else
			Format(sColor, sizeof(sColor), "%s1", sColor);
			
			KvGetString(ColorDB, sColor, colorName, sizeof(colorName), "Null");

			if(StrContains(colorName, "Null", false) != -1)
			{
				ReplaceString(sColor, sizeof(sColor), "1", "");
				Format(cMessage, sizeof(cMessage), "Color {olive}%s{default} was not found!", sColor);
				Print_Message_To_Client(client, cMessage);
				CloseHandle(ColorDB);
				return Plugin_Handled;
			}
		}
		
		CloseHandle(ColorDB);

		ExplodeString(colorName, "^", colorBuffer, 3, sizeof(colorBuffer[]));
		
		strcopy(sR, sizeof(sR), colorBuffer[0]);
		strcopy(sG, sizeof(sG), colorBuffer[1]);
		strcopy(sB, sizeof(sB), colorBuffer[2]);
		SetEntityRenderColor(entity, StringToInt(sR), StringToInt(sG), StringToInt(sB), alpha);
		NormalBeam(client, entity, "white");
		Entity_Color[entity][0] = StringToInt(sR);
		Entity_Color[entity][1] = StringToInt(sG);
		Entity_Color[entity][2] = StringToInt(sB);
		Entity_Color[entity][3] = alpha;
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_Alpha(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "Usage: sm_amt <transparency>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl String:sAmt[256];
	GetCmdArg(1, sAmt, sizeof(sAmt));
	if(CheckOwner(client, entity))
	{
		new Amt = StringToInt(sAmt);
		SetEntityRenderMode(entity, RENDER_TRANSALPHA);
		new color = GetEntSendPropOffs(entity, "m_clrRender", false);
		new red = GetEntData(entity, color, 1);
		new green = GetEntData(entity, color + 1, 1);
		new blue = GetEntData(entity, color + 2, 1);
		SetEntityRenderColor(entity, red, green, blue, Amt <= 50 ? 50 : Amt);
		NormalBeam(client, entity, "white");
		Entity_Color[entity][3] = Amt;
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_Grab(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	decl Float:eOrigin[3], Float:cOrigin[3];
	if(CheckOwner(client, entity))
	{
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", eOrigin);
		GetClientAbsOrigin(client, cOrigin);
		Entity_Grab[client] = entity;
		Grab_Origin[client][0] = eOrigin[0] - cOrigin[0];
		Grab_Origin[client][1] = eOrigin[1] - cOrigin[1];
		Grab_Origin[client][2] = eOrigin[2] - cOrigin[2];
		SetEntityRenderFx(Entity_Grab[client], RENDERFX_DISTORT);
		SetEntityRenderColor(Entity_Grab[client], 255, 0, 0, 128);
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_UnGrab(client, args)
{
	if (Entity_Grab[client] != -1)
	{
		SetEntityRenderFx(Entity_Grab[client], RENDERFX_NONE);
		SetEntityRenderColor(Entity_Grab[client], Entity_Color[Entity_Grab[client]][0], Entity_Color[Entity_Grab[client]][1], Entity_Color[Entity_Grab[client]][2], Entity_Color[Entity_Grab[client]][3]);
		Entity_Grab[client] = -1;
	} else
	Entity_Grab[client] = -1;
	return Plugin_Handled;
}

public Action:Command_Copy(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(client, false) == -1)
	{
		NotLooking(client);
		return Plugin_Handled;
	}
	new entity = GetClientAimTarget(client, false);
	if(CheckOwner(client, entity))
	{
		Copied_Model[client] = "";
		Copied_Color[entity][0] = 0;
		Copied_Color[entity][1] = 0;
		Copied_Color[entity][2] = 0;
		Copied_Color[entity][3] = 0;
		decl String:eModel[256], String:eClassname[256];
		GetEntityClassname(entity, eClassname, sizeof(eClassname));
		GetEntPropString(entity, Prop_Data, "m_ModelName", eModel, sizeof(eModel));
		if(StrEqual(eClassname, "cel_internet", true) || StrEqual(eClassname, "cel_buttonlink", true))
		{
			Print_Message_To_Client(client, "You cannot copy cels.");
			return Plugin_Handled;
		}
		Copied_Model[client] = eModel;
		Copied_Name[client] = Entity_Name[entity];
		new color = GetEntSendPropOffs(entity, "m_clrRender", false);
		new red = GetEntData(entity, color, 1);
		new green = GetEntData(entity, color + 1, 1);
		new blue = GetEntData(entity, color + 2, 1);
		new alpha = GetEntData(entity, color + 3, 1);
		Copied_Color[client][0] = red;
		Copied_Color[client][1] = green;
		Copied_Color[client][2] = blue;
		Copied_Color[client][3] = alpha;
		NormalBeam(client, entity, "white");
		Print_Message_To_Client(client, "Added prop to copy queue.");
		NoPropInQueue[client] = false;
	}else{
		NotYours(client, entity);
	}
	return Plugin_Handled;
}

public Action:Command_Paste(client, args)
{
	if(!Plugin_Enabled)
	{
		Print_Message_To_Client(client, "The plugin has been disabled.");
		return Plugin_Handled;
	}
	decl Float:cAngles[3], Float:chOrigin[3];
	if(NoPropInQueue[client])
	{
		Print_Message_To_Client(client, "No prop in copy queue.");
	}else{
		GetClientAbsAngles(client, cAngles);
		Crosshair_HitPoint(client, chOrigin);
		new sEntity = CreateEntityByName("prop_physics_override");
		PrecacheModel(Copied_Model[client]);
		DispatchKeyValue(sEntity, "model", Copied_Model[client]);
		DispatchSpawn(sEntity);
		TeleportEntity(sEntity, chOrigin, cAngles, NULL_VECTOR);
		SetOwner(client, sEntity);
		AddPropToClientPropCount(client);
		Entity_Targetname(client, sEntity);
		Entity_Motion(client, sEntity, "disable");
		SetEntityRenderColor(sEntity, Copied_Color[client][0], Copied_Color[client][1], Copied_Color[client][2], Copied_Color[client][3]);
		NormalBeam(client, sEntity, "white");
		Entity_Name[sEntity] = Copied_Name[client];
		SetEntityRenderMode(sEntity, RENDER_TRANSALPHA);
		new color = GetEntSendPropOffs(sEntity, "m_clrRender", false);
		new red = GetEntData(sEntity, color, 1);
		new green = GetEntData(sEntity, color + 1, 1);
		new blue = GetEntData(sEntity, color + 2, 1);
		new alpha = GetEntData(sEntity, color + 3, 1);
		Entity_Color[sEntity][0] = red;
		Entity_Color[sEntity][1] = green;
		Entity_Color[sEntity][2] = blue;
		Entity_Color[sEntity][3] = alpha;
		Print_Message_To_Client(client, "Pasted prop in copy queue.");
	}
	return Plugin_Handled;
}
