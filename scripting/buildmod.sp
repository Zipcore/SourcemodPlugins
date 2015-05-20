//=============== Plugin Includes ===============
#include <sourcemod>
#include <sdktools>
#include <morecolors>

//=============== Plugin Information ===============
#define NAME "|BuildMod|"
#define AUTHOR "FusionLock"
#define DESCRIPTION "A mod for maniplulating & controling entites."
#define VERSION "1.3.0"
#define URL "http://xfusionlockx.tk"

//=============== Plugin Declares ===============
#define MAX_ENTITES 2048
#define DEFAULTMONEY 0

/*new redColor[4] = {255, 0, 0, 200};
new orangeColor[4] = {255, 128, 0, 200};
new yellowColor[4] = {255, 255, 0, 200};
new greenColor[4] = {0, 255, 0, 200};*/
new blueColor[4] = {0, 0, 255, 200};
new physWhite[4] = {255, 255, 255, 200};
new greyColor[4] = {255, 255, 255, 300};

new iBuildModCelCount[MAXPLAYERS + 1];
new iBuildModCelLimit;
new iBuildModClientBalance[MAXPLAYERS + 1];
new iBuildModCopiedEntityColor[MAXPLAYERS + 1][4];
new iBuildModEntityColor[MAX_ENTITES + 1][4];
new iBuildModEntityOwner[MAX_ENTITES + 1];
new iBuildModPropCount[MAXPLAYERS + 1];
new iBuildModPropLimit;
new tHalo;
new tBeam;
new tPhys

new bool:bBuildModColorHud;
new bool:bBuildModEnabled;
new bool:bBuildModNoProp[MAXPLAYERS + 1];

new Handle:hBuildModCelsLimit = INVALID_HANDLE;
new Handle:hBuildModColorHud = INVALID_HANDLE;
new Handle:hBuildModEnabled = INVALID_HANDLE;
new Handle:hBuildModPropLimit = INVALID_HANDLE;

new String:sBuildModClientsPath[128];
new String:sBuildModColorsPath[128];
new String:sBuildModCommandsPath[128];
new String:sBuildModCopiedEntityName[MAXPLAYERS + 1][256];
new String:sBuildModCopiedEntityModel[MAXPLAYERS + 1][256];
new String:sBuildModDownloadsPath[128];
new String:sBuildModEntityName[MAX_ENTITES + 1][256];
new String:sBuildModHasInternetCel[MAXPLAYERS + 1][256];
new String:sBuildModMoneyPath[128];
new String:sBuildModPropsPath[128];
new String:sBuildModSteamID[MAXPLAYERS + 1][128];
new String:sBuildModEntityUrl[MAX_ENTITES + 1][256];

//=============== Plugin Info ===============
public Plugin:myinfo = 
{
	name = NAME,
	author = AUTHOR,
	description = DESCRIPTION,
	version = VERSION,
	url = URL
}

//=============== Plugin Start ===============
public OnPluginStart()
{
	//Loads the plugins convars.
	LoadConvars();
	
	//Loads the plugins commands.
	LoadCommands();
	
	//Builds the plugin paths.
	BuildPaths();
	
	//Hooks events on the server.
	HookEvents();
	
	//Hooks certain commands.
	HookCommands();
}

//=============== Plugin Forwards ===============
//When the map loads
public OnMapStart()
{
	PrecacheSound("UI/hint.wav");
	tHalo = PrecacheModel("materials/sprites/halo01.vmt", true);
	tBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	tPhys = PrecacheModel("materials/sprites/physbeam.vmt", true);
	DonwloadsFiles();
}

//Called when specified convars change.
public ConvarsChanged(Handle:hConvar, const String:sOldData[], const String:sNewData[])
{
	decl String:sTemp[256];
	
	//Checks if the convars has been changed.
	if(hConvar == hBuildModCelsLimit)
	{
		Format(sTemp, sizeof(sTemp), "Cel limit has been changed to [{green}%s{default}].", sNewData);
		iBuildModCelLimit = StringToInt(sNewData);
		sMessageAll(sTemp);
	}else if(hConvar == hBuildModEnabled)
	{
		if(StrEqual(sNewData, "0", true))
		{
			Format(sTemp, sizeof(sTemp), "BuildMod has been {green}disabled{default}.");
		}else if(StrEqual(sNewData, "1", true))
		{
			Format(sTemp, sizeof(sTemp), "BuildMod has been {green}enabled{default}.");
		}
		bBuildModEnabled = bool:StringToInt(sNewData);
		sMessageAll(sTemp);
	}else if(hConvar == hBuildModColorHud)
	{
		if(StrEqual(sNewData, "0", true))
		{
			Format(sTemp, sizeof(sTemp), "BuildMod's colored hud has been {green}disabled{default}.");
		}else if(StrEqual(sNewData, "1", true))
		{
			Format(sTemp, sizeof(sTemp), "BuildMod's colored hud has been {green}enabled{default}.");
		}
		bBuildModColorHud = bool:StringToInt(sNewData);
		sMessageAll(sTemp);
	}else if(hConvar == hBuildModPropLimit)
	{
		Format(sTemp, sizeof(sTemp), "Prop limit has been changed to [{green}%s{default}].", sNewData);
		iBuildModPropLimit = StringToInt(sNewData);
		sMessageAll(sTemp);
	}  
}

//On every game frame.
public OnGameFrame()
{
	for(new iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			if(IsPlayerAlive(iClient))
			{
				if(GetClientButtons(iClient) & IN_USE)
				{
					new iEntity = GetClientAimTarget(iClient, false);
					if(GetClientAimTarget(iClient, false) == -1)
					{
						
					}else{
						decl String:sClassname[256];
						GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
						if(StrEqual(sClassname, "cel_internet", true))
						{
							UseInternet(iClient, iEntity);
						}
					}
				}
			}
		}
	}
}


//When the clients first spawns in the server.
public OnClientPutInServer(iClient)
{
	ResetClientInformation(iClient);
	MoneyLoad(iClient);
	CommandsLoad(iClient);
	CreateTimer(0.1, tEntityHud, iClient, TIMER_REPEAT);
	CreateTimer(60.0, tGiveMoney, iClient, TIMER_REPEAT);
}

//When the clients disconnects from the server.
public OnClientDisconnect(iClient)
{
	for (new i = 0; i <= GetMaxEntities(); i++)
	{
		if(CheckOwner(iClient, i))
		{
			CreateTimer(0.1, tDelayRemove, i);
		}
	}
}

//When the client spawns.
public Action:Event_PlayerSpawn(Handle:Event, const String:Name[], bool:dontBroadcast) 
{
	/*decl iClient;
	iClient = GetClientOfUserId(GetEventInt(Event, "userid"));*/
}

//When the client connects. (Used to block messages)
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

//When the client disconnects. (Used to block messages)
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

//Filters out players.
public bool:FilterPlayer(entity, contentsMask)
{
	return entity > MaxClients;
}

//=============== Plugin Timers ===============
//Delays remove
public Action:tDelayRemove(Handle:timer, any:iEntity)
{
	AcceptEntityInput(iEntity, "kill");
}

//Loads the entity hud.
public Action:tEntityHud(Handle:timer, any:iClient)
{
	decl String:sTemp[256], String:sClassname[256];
	if(IsClientInGame(iClient) && IsClientConnected(iClient))
	{
		new iEntity = GetClientAimTarget(iClient, false);
		if(GetClientAimTarget(iClient, false) == -1)
		{
			Format(sTemp, sizeof(sTemp), "Name: %N\nProps Spawned: %d\nBalance: $%d", iClient, iBuildModPropCount[iClient], iBuildModClientBalance[iClient]);
		}else{
			GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
			if(StrEqual(sClassname, "player", true))
			{
				Format(sTemp, sizeof(sTemp), "Name: %N\nProps Spawned: %d\nBalance: $%d", iEntity, iBuildModPropCount[iEntity], iBuildModClientBalance[iEntity]);
			}else if(StrEqual(sClassname, "cel_internet", true))
			{
				Format(sTemp, sizeof(sTemp), "Owner: %N\nUrl: %s", iBuildModEntityOwner[iEntity], sBuildModEntityUrl[iEntity]);
			}else if(CheckOwner(iClient, iEntity))
			{
				Format(sTemp, sizeof(sTemp), "Prop Name: %s\nProp Classname: %s", sBuildModEntityName[iEntity], sClassname);
			}else{
				Format(sTemp, sizeof(sTemp), "Prop Owner: %N\nProp Name: %s\nProp Classname: %s", iBuildModEntityOwner[iEntity], sBuildModEntityName[iEntity], sClassname);
			}
		}
		if(bBuildModColorHud)
		{
			SetHudTextParamsEx(3.050, -0.110, 0.4, blueColor);
			ShowHudText(iClient, -1, sTemp);
		}else{
			PrintHintText(iClient, sTemp);
			StopSound(iClient, SNDCHAN_STATIC, "UI/hint.wav");
		}
	}
}

//Gives clients 2 dollars every 60 seconds (1 Minute).
public Action:tGiveMoney(Handle:timer, any:iClient)
{
	if(IsClientInGame(iClient) && IsClientConnected(iClient))
	{
		new iMoney = iBuildModClientBalance[iClient] += 2;
		iBuildModClientBalance[iClient] = iMoney;
		MoneySave(iClient);
	}
}

//=============== Plugin Commands ===============
//When a client runs a command.
public Action:HookPlayerChat(iClient, const String:command[], iArgs)
{
	decl String:sText[2];
	GetCmdArg(1, sText, sizeof(sText));
	return (sText[0] == '/' || sText[0] == '!') ? Plugin_Handled : Plugin_Continue;
}  

//Spawns a entity by a givin alias.
public Action:Command_cSpawn(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		PrintToConsole(iClient, "Usage: sm_spawn <prop alias> <frozen|god>");
		sMessage(iClient, "Usage: {green}!spawn{default} <prop alias> <frozen|god>");
		return Plugin_Handled;
	}
	decl String:sAlias[256], String:iEntityOption[256], String:sModel[256], String:iEntityName[256], String:sPropsDBName[128], String:sPropsDBBuffer[2][128], String:sTemp[256], String:iEntityClassname[256];
	if(iBuildModPropCount[iClient] >= iBuildModPropLimit)
	{
		Format(sTemp, sizeof(sTemp), "You have spawned maximum props [{green}%d{default}/{green}%d{default}]", iBuildModPropCount[iClient], iBuildModPropLimit);
		sMessage(iClient, sTemp);
		return Plugin_Handled;
	}
	GetCmdArg(1, sAlias, sizeof(sAlias));
	GetCmdArg(2, iEntityOption, sizeof(iEntityOption));
	new Handle:hPropsDB = CreateKeyValues("Props");
	FileToKeyValues(hPropsDB, sBuildModPropsPath);
	KvGetString(hPropsDB, sAlias, sPropsDBName, sizeof(sPropsDBName), "null");
	if(StrContains(sPropsDBName, "null", false) != -1)
	{
		if(StrContains(sAlias, "1", false) != -1)
		{
			ReplaceString(sAlias, sizeof(sAlias), "1", "");
		}else{
			Format(sAlias, sizeof(sAlias), "%s1", sAlias);
		}
		KvGetString(hPropsDB, sAlias, sPropsDBName, sizeof(sPropsDBName), "null");
		if(StrContains(sPropsDBName, "null", false) != -1)
		{
			ReplaceString(sAlias, sizeof(sAlias), "1", "");
			Format(sTemp, sizeof(sTemp), "{green}%s{default} was not found!", sAlias);
			sMessage(iClient, sTemp);
			CloseHandle(hPropsDB);
			return Plugin_Handled;
		}
	}
	ExplodeString(sPropsDBName, "^", sPropsDBBuffer, 2, sizeof(sPropsDBBuffer[]));
	strcopy(sModel, sizeof(sModel), sPropsDBBuffer[0]);
	strcopy(iEntityName, sizeof(iEntityName), sPropsDBBuffer[1]);
	strcopy(iEntityClassname, sizeof(iEntityClassname), iEntityName);
	SpawnEntity(iClient, sModel, sAlias, iEntityName, iEntityOption, iEntityClassname);
	return Plugin_Handled;
}

//Removes an entity.
public Action:Command_cRemove(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	if(CheckOwner(iClient, iEntity))
	{
		DissolveEntity(iEntity);
		DeleteBeam(iClient, iEntity);
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Gets the count of client props & cels.
public Action:Command_cCount(iClient, iArgs)
{
	CPrintToChat(iClient, "{blue}|BuildMod|{default} Props: {green}%d{default}/{green}%d{default}", iBuildModPropCount[iClient], iBuildModPropLimit);
	CPrintToChat(iClient, "{blue}|BuildMod|{default} Cels: {green}%d{default}/{green}%d{default}", iBuildModCelCount[iClient], iBuildModCelLimit);
	return Plugin_Handled;
}

//Sets the color of an entity.
public Action:Command_cColor(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		PrintToConsole(iClient, "Usage: sm_color <color>");
		sMessage(iClient, "Usage: {green}!color{default} <color>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl String:sColor[256], String:sColorsDBName[128], String:sColorsDBBuffer[3][128], String:sTemp[256], String:sR[64], String:sG[64], String:sB[64];
	GetCmdArg(1, sColor, sizeof(sColor));
	new Handle:hColorsDB = CreateKeyValues("Props");
	FileToKeyValues(hColorsDB, sBuildModColorsPath);
	KvGetString(hColorsDB, sColor, sColorsDBName, sizeof(sColorsDBName), "null");
	if(StrContains(sColorsDBName, "null", false) != -1)
	{
		if(StrContains(sColor, "1", false) != -1)
		{
			ReplaceString(sColor, sizeof(sColor), "1", "");
		}else{
			Format(sColor, sizeof(sColor), "%s1", sColor);
		}
		KvGetString(hColorsDB, sColor, sColorsDBName, sizeof(sColorsDBName), "null");
		if(StrContains(sColorsDBName, "null", false) != -1)
		{
			ReplaceString(sColor, sizeof(sColor), "1", "");
			Format(sTemp, sizeof(sTemp), "Color {green}%s{default} was not found!", sColor);
			sMessage(iClient, sTemp);
			CloseHandle(hColorsDB);
			return Plugin_Handled;
		}
	}
	ExplodeString(sColorsDBName, "^", sColorsDBBuffer, 3, sizeof(sColorsDBBuffer[]));
	strcopy(sR, sizeof(sR), sColorsDBBuffer[0]);
	strcopy(sG, sizeof(sG), sColorsDBBuffer[1]);
	strcopy(sB, sizeof(sB), sColorsDBBuffer[2]);
	new iColor = GetEntSendPropOffs(iEntity, "m_clrRender", false);
	new iAlpha = GetEntData(iEntity, iColor + 3, 1);
	if(CheckOwner(iClient, iEntity))
	{
		SetEntityRenderColor(iEntity, StringToInt(sR), StringToInt(sG), StringToInt(sB), iAlpha);
		iBuildModEntityColor[iEntity][0] = StringToInt(sR);
		iBuildModEntityColor[iEntity][1] = StringToInt(sG);
		iBuildModEntityColor[iEntity][2] = StringToInt(sB);
		iBuildModEntityColor[iEntity][3] = iAlpha;
		NormalBeam(iClient, iEntity);
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Freezes an entity.
public Action:Command_cFreeze(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	if(CheckOwner(iClient, iEntity))
	{
		EntityMotionDisable(iEntity, true);
		sMessage(iClient, "Your prop has been frozen.");
		NormalBeam(iClient, iEntity);
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Unfreezes an entity.
public Action:Command_cUnFreeze(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	if(CheckOwner(iClient, iEntity))
	{
		EntityMotionDisable(iEntity, false);
		sMessage(iClient, "Your prop has been unfrozen.");
		NormalBeam(iClient, iEntity);
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Copies an entity to be pasted later.
public Action:Command_cCopy(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl String:sModel[256];
	if(CheckOwner(iClient, iEntity))
	{
		sBuildModCopiedEntityModel[iClient] = "";
		sBuildModCopiedEntityName[iClient] = "";
		iBuildModCopiedEntityColor[iClient][0] = 0;
		iBuildModCopiedEntityColor[iClient][1] = 0;
		iBuildModCopiedEntityColor[iClient][2] = 0;
		iBuildModCopiedEntityColor[iClient][3] = 0;
		GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
		new iColor = GetEntSendPropOffs(iEntity, "m_clrRender", false);
		new iRed = GetEntData(iEntity, iColor, 1);
		new iGreen = GetEntData(iEntity, iColor + 1, 1);
		new iBlue = GetEntData(iEntity, iColor + 2, 1);
		new iAlpha = GetEntData(iEntity, iColor + 3, 1);
		sBuildModCopiedEntityModel[iClient] = sModel;
		sBuildModCopiedEntityName[iClient] = sBuildModEntityName[iEntity];
		iBuildModCopiedEntityColor[iClient][0] = iRed;
		iBuildModCopiedEntityColor[iClient][1] = iGreen;
		iBuildModCopiedEntityColor[iClient][2] = iBlue;
		iBuildModCopiedEntityColor[iClient][3] = iAlpha;
		sMessage(iClient, "Added entity to copy queue.");
		NormalBeam(iClient, iEntity);
		bBuildModNoProp[iClient] = false;
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Pastes an entity in the copy queue.
public Action:Command_cPaste(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(bBuildModNoProp[iClient])
	{
		sMessage(iClient, "No entity in copy queue.");
		return Plugin_Handled;
	}else{
		SpawnEntity(iClient, sBuildModCopiedEntityModel[iClient], sBuildModCopiedEntityName[iClient], "prop_physics_override", "frozen", "prop_physics_override");
		new iEntity = GetClientAimTarget(iClient, false);
		SetEntityRenderColor(iEntity, iBuildModCopiedEntityColor[iClient][0], iBuildModCopiedEntityColor[iClient][1], iBuildModCopiedEntityColor[iClient][2], iBuildModCopiedEntityColor[iClient][3]);
		NormalBeam(iClient, iEntity);
		SetEntityRenderMode(iEntity, RENDER_TRANSALPHA);
		iBuildModEntityColor[iEntity][0] = iBuildModCopiedEntityColor[iClient][0];
		iBuildModEntityColor[iEntity][1] = iBuildModCopiedEntityColor[iClient][1];
		iBuildModEntityColor[iEntity][2] = iBuildModCopiedEntityColor[iClient][2];
		iBuildModEntityColor[iEntity][3] = iBuildModCopiedEntityColor[iClient][3];
		sMessage(iClient, "Your entity has been pasted.");
	}
	return Plugin_Handled;
}

//Rotates an entity.
public Action:Command_cRotate(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		PrintToConsole(iClient, "Usage: sm_rotate <degrees>");
		sMessage(iClient, "Usage: {green}!rotate{default} <degrees>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl String:sDegree[256], String:sTemp[256];
	decl Float:iAngles[3], Float:iFinalAngles[3];
	GetCmdArg(1, sDegree, sizeof(sDegree));
	if(CheckOwner(iClient, iEntity))
	{
		GetEntPropVector(iEntity, Prop_Send, "m_angRotation", iAngles);
		new iY = StringToInt(sDegree);
		iFinalAngles[0] = iAngles[0];
		iFinalAngles[1] = (iAngles[1] += iY);
		iFinalAngles[2] = iAngles[2];
		TeleportEntity(iEntity, NULL_VECTOR, iFinalAngles, NULL_VECTOR);
		Format(sTemp, sizeof(sTemp), "Your entity has been rotated {green}%s{default} degrees.", sDegree);
		sMessage(iClient, sTemp);
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Flips an entity.
public Action:Command_cFlip(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		PrintToConsole(iClient, "Usage: sm_flip <degrees>");
		sMessage(iClient, "Usage: {green}!flip{default} <degrees>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl String:sDegree[256], String:sTemp[256];
	decl Float:iAngles[3], Float:iFinalAngles[3];
	GetCmdArg(1, sDegree, sizeof(sDegree));
	if(CheckOwner(iClient, iEntity))
	{
		GetEntPropVector(iEntity, Prop_Send, "m_angRotation", iAngles);
		new iX = StringToInt(sDegree);
		iFinalAngles[0] = (iAngles[0] += iX);
		iFinalAngles[1] = iAngles[1];
		iFinalAngles[2] = iAngles[2];
		TeleportEntity(iEntity, NULL_VECTOR, iFinalAngles, NULL_VECTOR);
		Format(sTemp, sizeof(sTemp), "Your entity has been flipped {green}%s{default} degrees.", sDegree);
		sMessage(iClient, sTemp);
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Straightens an entity.
public Action:Command_cStraighten(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl Float:iFinalAngles[3];
	if(CheckOwner(iClient, iEntity))
	{
		iFinalAngles[0] = 0.0;
		iFinalAngles[1] = 0.0;
		iFinalAngles[2] = 0.0;
		NormalBeam(iClient, iEntity);
		TeleportEntity(iEntity, NULL_VECTOR, iFinalAngles, NULL_VECTOR);
		sMessage(iClient, "Your entity has been straightened.");
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Moves an entity using x y & z.
public Action:Command_cSMove(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		PrintToConsole(iClient, "Usage: sm_smove <x> <y> <z>");
		sMessage(iClient, "Usage: {green}!smove{default} <x> <y> <z>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl String:sX[256], String:sY[256], String:sZ[256];
	decl Float:iOrigin[3], Float:iFinalOrigin[3];
	GetCmdArg(1, sX, sizeof(sX));
	GetCmdArg(2, sY, sizeof(sY));
	GetCmdArg(3, sZ, sizeof(sZ));
	if(CheckOwner(iClient, iEntity))
	{
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", iOrigin);
		new iX = StringToInt(sX), iY = StringToInt(sY), iZ = StringToInt(sZ);
		iFinalOrigin[0] = (iOrigin[0] += iX);
		iFinalOrigin[1] = (iOrigin[1] += iY);
		iFinalOrigin[2] = (iOrigin[2] += iZ);
		TeleportEntity(iEntity, iFinalOrigin, NULL_VECTOR, NULL_VECTOR);
		sMessage(iClient, "Your entity has been moved.");
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Gets entity information.
public Action:Command_cEntityInfo(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl String:sModel[256], String:sClassname[256];
	GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname)); 
	CPrintToChat(iClient, "{blue}|BuildMod|{default} Entity Name: %s", sBuildModEntityName[iEntity]);
	CPrintToChat(iClient, "{blue}|BuildMod|{default} Entity Owner: %N", iBuildModEntityOwner[iEntity]);
	CPrintToChat(iClient, "{blue}|BuildMod|{default} Entity Model: %s", sModel);
	CPrintToChat(iClient, "{blue}|BuildMod|{default} Entity Classname: %s", sClassname);
	return Plugin_Handled;
}

//Enables noclip on a client.
public Action:Command_cNoclip(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	new MoveType:sMoveType = GetEntityMoveType(iClient);
	if (sMoveType != MOVETYPE_NOCLIP)
	{
		SetEntityMoveType(iClient, MOVETYPE_NOCLIP);
		sMessage(iClient, "You have enabled flying.");
	}
	else
	{
		SetEntityMoveType(iClient, MOVETYPE_WALK);
		sMessage(iClient, "You have disabled flying.");
	}
	return Plugin_Handled;
}

//Returns the balance of the client.
public Action:Command_cBalance(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	decl String:sTemp[256];
	Format(sTemp, sizeof(sTemp), "Current Balance: $%d", iBuildModClientBalance[iClient]);
	sMessage(iClient, sTemp);
	return Plugin_Handled;
}

//Buys a command. Note: When putting commands for sale, make it $1 less.
public Action:Command_cBuy(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		PrintToConsole(iClient, "Usage: sm_buy <command>");
		sMessage(iClient, "Usage: {green}!buy{default} <command>");
		return Plugin_Handled;
	}
	decl String:sCommand[256], String:sTemp[256];
	GetCmdArg(1, sCommand, sizeof(sCommand));
	if(StrEqual(sBuildModHasInternetCel[iClient], "true", true))
	{
		sMessage(iClient, "You already own {green}!internet{default}!");
		return Plugin_Handled;
	}
	if(StrEqual(sCommand, "internet", false))
	{
		if(iBuildModClientBalance[iClient] > 49)
		{
			sMessage(iClient, "You have bought {green}!internet{default} for $50! You also get {green}!seturl{default} for free!");
			iBuildModClientBalance[iClient] -= 50;
			sBuildModHasInternetCel[iClient] = "true";
			MoneySave(iClient);
			CommandsSave(iClient);
		}else{
			sMessage(iClient, "You cannot afford this command!");
		}
	}else{
		Format(sTemp, sizeof(sTemp), "You cannot buy {green}%s{default}!", sCommand);
		sMessage(iClient, sTemp);
	}
	return Plugin_Handled;
}

//Spawns an internet cel.
public Action:Command_cInternet(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(StrEqual(sBuildModHasInternetCel[iClient], "false", true))
	{
		sMessage(iClient, "You haven't bought that yet! Buy it using {green}!buy internet{default}!");
		return Plugin_Handled;
	}
	SpawnEntity(iClient, "models/props_lab/monitor02.mdl", "internet", "prop_physics_override", "frozen", "cel_internet");
	AddNumberToCelCount(iClient);
	return Plugin_Handled;
}

//Sets the url of a cel.
public Action:Command_cSetUrl(iClient, iArgs)
{
	if(!bBuildModEnabled)
	{
		return Plugin_Handled;
	}
	if(iArgs < 1)
	{
		PrintToConsole(iClient, "Usage: sm_seturl <url>");
		sMessage(iClient, "Usage: {green}!seturl{default} <url>");
		return Plugin_Handled;
	}
	if(GetClientAimTarget(iClient, false) == -1)
	{
		NotLooking(iClient);
		return Plugin_Handled;
	}
	if(StrEqual(sBuildModHasInternetCel[iClient], "false", true))
	{
		sMessage(iClient, "You haven't bought that yet! Buy it using {green}!buy internet{default}!");
		return Plugin_Handled;
	}
	new iEntity = GetClientAimTarget(iClient, false);
	decl String:sUrl[256], String:sTemp[256];
	GetCmdArg(1, sUrl, sizeof(sUrl));
	if(CheckOwner(iClient, iEntity))
	{
		Format(sUrl, sizeof(sUrl), "http://%s", sUrl);
		Format(sBuildModEntityUrl[iEntity], sizeof(sBuildModEntityUrl[]), sUrl);
		Format(sTemp, sizeof(sTemp), "Url has been set to {green}%s{default}.", sUrl);
		sMessage(iClient, sTemp);
		NormalBeam(iClient, iEntity);
	}else{
		NotYours(iClient, iEntity);
	}
	return Plugin_Handled;
}

//Sends a message through the server.
public Action:Command_cServerSay(iArgs)
{
	decl String:sMess[256];
	GetCmdArgString(sMess, sizeof(sMess));
	sMessageAll(sMess);
	return Plugin_Handled;
}

//=============== Plugin Stocks ===============
//Loads the plugins convars.
stock LoadConvars()
{
	//Creates the plugin convars.
	hBuildModCelsLimit = CreateConVar("buildmod_celimit", "15", "Changes the buildmod cell limit", FCVAR_PLUGIN|FCVAR_NOTIFY);
	hBuildModColorHud = CreateConVar("buildmod_color_hud", "0", "Enables buildmod's color hud on or off.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hBuildModEnabled = CreateConVar("buildmod_enabled", "1", "Enables buildmod on or off.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hBuildModPropLimit = CreateConVar("buildmod_proplimit", "300", "Changes the buildmod prop limit.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	
	//Checks if the convars have been changed.
	HookConVarChange(hBuildModCelsLimit, ConvarsChanged);
	HookConVarChange(hBuildModColorHud, ConvarsChanged);
	HookConVarChange(hBuildModEnabled, ConvarsChanged);
	HookConVarChange(hBuildModPropLimit, ConvarsChanged);
	
	//Converts convar data.
	iBuildModCelLimit = GetConVarInt(hBuildModCelsLimit);
	bBuildModColorHud = GetConVarBool(hBuildModColorHud);
	bBuildModEnabled = GetConVarBool(hBuildModEnabled);
	iBuildModPropLimit = GetConVarInt(hBuildModPropLimit);
}

//Loads the plugins commands.
stock LoadCommands()
{
	RegConsoleCmd("sm_spawn", Command_cSpawn, "Spawns an entity.");
	RegConsoleCmd("sm_prop", Command_cSpawn, "Spawns an entity.");
	RegConsoleCmd("sm_delete", Command_cRemove, "Removes an entity.");
	RegConsoleCmd("sm_remove", Command_cRemove, "Removes an entity.");
	RegConsoleCmd("sm_count", Command_cCount, "Shows the entity count for a client.");
	RegConsoleCmd("sm_color", Command_cColor, "Changes the color of an entity.");
	RegConsoleCmd("sm_paint", Command_cColor, "Changes the color of an entity.");
	RegConsoleCmd("sm_freeze", Command_cFreeze, "Freezes an entity.");
	RegConsoleCmd("sm_unfreeze", Command_cUnFreeze, "Unfreezes an entity.");
	RegConsoleCmd("sm_copy", Command_cCopy, "Adds an entity to the copy queue.");
	RegConsoleCmd("sm_paste", Command_cPaste, "Pastes an entity in the copy queue.");
	RegConsoleCmd("sm_rotate", Command_cRotate, "Rotates an entity.");
	RegConsoleCmd("sm_r", Command_cRotate, "Rotates an entity.");
	RegConsoleCmd("sm_flip", Command_cFlip, "Flips an entity.");
	RegConsoleCmd("sm_f", Command_cFlip, "Flips an entity.");
	RegConsoleCmd("sm_straight", Command_cStraighten, "Straightens an entity.");
	RegConsoleCmd("sm_stand", Command_cStraighten, "Straightens an entity.");
	RegConsoleCmd("sm_smove", Command_cSMove, "Moves an entity using x y & z.");
	RegConsoleCmd("sm_entinfo", Command_cEntityInfo, "Gets entity information.");
	RegConsoleCmd("sm_einfo", Command_cEntityInfo, "Gets entity information.");
	RegConsoleCmd("sm_fly", Command_cNoclip, "Enables noclip on a client.");
	RegConsoleCmd("sm_buy", Command_cBuy, "Buys a command.");
	RegConsoleCmd("sm_internet", Command_cInternet, "Spawns an internet cel.");
	RegConsoleCmd("sm_seturl", Command_cSetUrl, "Sets the url of an cel.");
	RegConsoleCmd("sm_balance", Command_cBalance, "Returns the balance of the client.");
	RegConsoleCmd("sm_money", Command_cBalance, "Returns the balance of the client.");
	RegServerCmd("bm_say", Command_cServerSay);
}

//Hooks events on the server.
stock HookEvents()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

//Hooks certain commands.
stock HookCommands()
{
	AddCommandListener(HookPlayerChat, "say");
	AddCommandListener(HookPlayerChat, "say_team");  
}

//Downloads files on map start
stock DonwloadsFiles()
{
	new Handle:hDownloadFiles = OpenFile(sBuildModDownloadsPath, "r");
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

//Saves money information.
stock MoneySave(iClient)
{
	decl String:sAuthID[256], String:sSteamID[256];
	GetClientAuthString(iClient, sAuthID, sizeof(sAuthID));
	new Handle:hMoneyDB = CreateKeyValues("Money");
	FileToKeyValues(hMoneyDB, sBuildModMoneyPath);
	if(KvJumpToKey(hMoneyDB, sAuthID, true))
	{
		KvGetString(hMoneyDB, "steamid", sSteamID, sizeof(sSteamID), "null");
		if(StrEqual(sSteamID, "null", true))
		{
			PrintToServer("Creating balance for %N", iClient);
		}
		KvSetString(hMoneyDB, "steamid", sAuthID);
		KvSetNum(hMoneyDB, "balance", iBuildModClientBalance[iClient]);
		KvRewind(hMoneyDB);
		KeyValuesToFile(hMoneyDB, sBuildModMoneyPath);
		CloseHandle(hMoneyDB);
	}
}

//Loads money information.
stock MoneyLoad(iClient)
{
	decl String:sAuthID[256], String:sSteamID[256];
	GetClientAuthString(iClient, sAuthID, sizeof(sAuthID));
	new Handle:hMoneyDB = CreateKeyValues("Money");
	FileToKeyValues(hMoneyDB, sBuildModMoneyPath);
	if(KvJumpToKey(hMoneyDB, sAuthID, true))
	{
		KvGetString(hMoneyDB, "steamid", sSteamID, sizeof(sSteamID), "null");
		if(StrEqual(sSteamID, "null", true))
		{
			MoneySave(iClient);
		}else{
			new iMoney = KvGetNum(hMoneyDB, "balance");
			iBuildModClientBalance[iClient] = iMoney;
		}
		KvRewind(hMoneyDB);
		CloseHandle(hMoneyDB);
	}
}

//Saves commands information.
stock CommandsSave(iClient)
{
	decl String:sAuthID[256], String:sSteamID[256];
	GetClientAuthString(iClient, sAuthID, sizeof(sAuthID));
	new Handle:hCommandDB = CreateKeyValues("Commands");
	FileToKeyValues(hCommandDB, sBuildModCommandsPath);
	if(KvJumpToKey(hCommandDB, sAuthID, true))
	{
		KvGetString(hCommandDB, "steamid", sSteamID, sizeof(sSteamID), "null");
		if(StrEqual(sSteamID, "null", true))
		{
			PrintToServer("Creating commands for %N", iClient);
		}
		KvSetString(hCommandDB, "steamid", sAuthID);
		KvSetString(hCommandDB, "internet", sBuildModHasInternetCel[iClient]);
		KvRewind(hCommandDB);
		KeyValuesToFile(hCommandDB, sBuildModCommandsPath);
		CloseHandle(hCommandDB);
	}
}

//Loads commands information.
stock CommandsLoad(iClient)
{
	decl String:sAuthID[256], String:sSteamID[256];
	GetClientAuthString(iClient, sAuthID, sizeof(sAuthID));
	new Handle:hCommandDB = CreateKeyValues("Commands");
	FileToKeyValues(hCommandDB, sBuildModCommandsPath);
	if(KvJumpToKey(hCommandDB, sAuthID, true))
	{
		KvGetString(hCommandDB, "steamid", sSteamID, sizeof(sSteamID), "null");
		if(StrEqual(sSteamID, "null", true))
		{
			CommandsSave(iClient);
		}else{
			KvGetString(hCommandDB, "internet", sBuildModHasInternetCel[iClient], sizeof(sBuildModHasInternetCel[]), "null");
		}
		KvRewind(hCommandDB);
		CloseHandle(hCommandDB);
	}
}

//Resets clients information.
stock ResetClientInformation(iClient)
{
	decl String:sSteamID[256], String:sMap[256], String:sFilePath[256];
	GetCurrentMap(sMap, sizeof(sMap));
	sBuildModCopiedEntityModel[iClient] = "";
	sBuildModCopiedEntityName[iClient] = "";
	sBuildModHasInternetCel[iClient] = "false";
	iBuildModCopiedEntityColor[iClient][0] = 0;
	iBuildModCopiedEntityColor[iClient][1] = 0;
	iBuildModCopiedEntityColor[iClient][2] = 0;
	iBuildModCopiedEntityColor[iClient][3] = 0;
	iBuildModCelCount[iClient] = 0;
	iBuildModPropCount[iClient] = 0;
	iBuildModClientBalance[iClient] = 250;
	GetClientAuthString(iClient, sSteamID, sizeof(sSteamID));
	ReplaceString(sSteamID, sizeof(sSteamID), "STEAM_", "");
	ReplaceString(sSteamID, sizeof(sSteamID), ":", "-");
	FormatEx(sBuildModSteamID[iClient], sizeof(sBuildModSteamID[]), "%s", sSteamID);
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "simple-build/saves/%s/%s", sMap, sBuildModSteamID[iClient]);
	if(!DirExists(sFilePath))
	{
		CreateDirectory(sFilePath, 511);
	}
	MoneyLoad(iClient);
	CommandsLoad(iClient);
}

//Builds the plugin paths.
stock BuildPaths()
{
	decl String:sMap[256], String:sFilePath[256];
	GetCurrentMap(sMap, sizeof(sMap));
	BuildPath(Path_SM, sBuildModColorsPath, 128, "data/buildmod/colors_db.txt");
	BuildPath(Path_SM, sBuildModCommandsPath, 128, "data/buildmod/commands_db.txt");
	BuildPath(Path_SM, sBuildModDownloadsPath, 128, "data/buildmod/downloads_db.txt");
	BuildPath(Path_SM, sBuildModClientsPath, 128, "data/buildmod/client_db.txt");
	BuildPath(Path_SM, sBuildModPropsPath, 128, "data/buildmod/props_db.txt");
	BuildPath(Path_SM, sBuildModMoneyPath, 128, "data/buildmod/money_db.txt");
	LoadTranslations("common.phrases");
}

//Allows entites to be spawned.
stock SpawnEntity(iClient, String:sModel[], String:sPropName[256], String:iEntityName[], String:iEntityOption[], String:iEntityClassname[])
{
	decl Float:vOrigin[3], Float:vClientAngles[3];
	decl String:sTemp[256];
	new iEntity = CreateEntityByName(iEntityName);
	PrecacheModel(sModel);
	DispatchKeyValue(iEntity, "classname", iEntityClassname);
	DispatchKeyValue(iEntity, "model", sModel);
	DispatchSpawn(iEntity);
	GetCrosshairHitOrigin(iClient, vOrigin);
	GetClientAbsAngles(iClient, vClientAngles);
	TeleportEntity(iEntity, vOrigin, vClientAngles, NULL_VECTOR);
	if(StrEqual(iEntityOption, "frozen", true))
	{
		EntityMotionDisable(iEntity, true);
	}else if(StrEqual(iEntityOption, "god", true))
	{
		SetEntProp(iEntity, Prop_Data, "m_takedamage", 0, 1);
	}else if(StrEqual(iEntityOption, "", true))
	{
		//Do nothing. Just a check.
	}else{
		Format(sTemp, sizeof(sTemp), "{green}%s{default} is not a valid option.", iEntityOption);
		sMessage(iClient, sTemp);
	}
	new iColor = GetEntSendPropOffs(iEntity, "m_clrRender", false);
	new iRed = GetEntData(iEntity, iColor, 1);
	new iGreen = GetEntData(iEntity, iColor + 1, 1);
	new iBlue = GetEntData(iEntity, iColor + 2, 1);
	new iAlpha = GetEntData(iEntity, iColor + 3, 1);
	iBuildModEntityColor[iEntity][0] = iRed;
	iBuildModEntityColor[iEntity][1] = iGreen;
	iBuildModEntityColor[iEntity][2] = iBlue;
	iBuildModEntityColor[iEntity][3] = iAlpha;
	sBuildModEntityName[iEntity] = sPropName;
	SetOwner(iClient, iEntity);
	AddNumberToPropCount(iClient);
	return true;
}

//Dissolves a givin entity.
stock DissolveEntity(iEntity)
{
	decl String:sTargetname[256];
	Format(sTargetname, sizeof(sTargetname), "dissolve%N%f", GetOwner(iEntity), GetRandomFloat());
	DispatchKeyValue(iEntity, "targetname", sTargetname);
	new sDissolve = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(sDissolve, "dissolvetype", "3");
	DispatchKeyValue(sDissolve, "target", sTargetname);
	AcceptEntityInput(sDissolve, "dissolve");
	RemoveNumberFromPropCount(iEntity);
	AcceptEntityInput(sDissolve, "kill");
}

//Checks the owner of an entity.
stock CheckOwner(iClient, iEntity)
{
	if(iBuildModEntityOwner[iEntity] == iClient)
	{
		return true;
	}
	return false;
}

//Gets the owner of an entity.
stock GetOwner(iEntity)
{
	return iBuildModEntityOwner[iEntity];
}

//Sets the owner of an entity.
stock SetOwner(iClient, iEntity)
{
	iBuildModEntityOwner[iEntity] = iClient;
}

//Sends a message that the entity doesn't belong to you.
stock NotYours(iClient, iEntity)
{
	decl String:sTemp[256];
	Format(sTemp, sizeof(sTemp), "That doesn't belong to you! It belongs to {green}%N{default}.", iBuildModEntityOwner[iEntity]);
	sMessage(iClient, sTemp);
}

//Sends a message that you are not looking at anything.
stock NotLooking(iClient)
{
	sMessage(iClient, "You are not looking at anything!");
}

//Gets crosshair hit origin.
stock GetCrosshairHitOrigin(iClient, Float:iOrigin[3])
{
	decl Float:iClientOrigin[3], Float:iClientAngles[3];
	GetClientEyePosition(iClient, iClientOrigin);
	GetClientEyeAngles(iClient, iClientAngles);
	new Handle:hTraceRay = TR_TraceRayFilterEx(iClientOrigin, iClientAngles, MASK_SOLID, RayType_Infinite, FilterPlayer);
	if(TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(iOrigin, hTraceRay);
		CloseHandle(hTraceRay);
		return;
	}
	CloseHandle(hTraceRay);
}

//Enables/Disables motion on entites.
stock EntityMotionDisable(iEntity, bool:bDisable)
{
	if(bDisable)
	{
		AcceptEntityInput(iEntity, "disablemotion");
	}else{
		AcceptEntityInput(iEntity, "enablemotion");
	}
}

//Adds number to client prop count.
stock AddNumberToPropCount(iClient)
{
	iBuildModPropCount[iClient]++;
}

//Removes number from client prop count.
stock RemoveNumberFromPropCount(iEntity)
{
	iBuildModPropCount[iBuildModEntityOwner[iEntity]] -= 1;
}

//Adds number to client cel count.
stock AddNumberToCelCount(iClient)
{
	iBuildModCelCount[iClient]++;
}

//Removes number from client cel count.
stock RemoveNumberFromCelCount(iEntity)
{
	iBuildModCelCount[iBuildModEntityOwner[iEntity]] -= 1;
}

//When a client uses an internet cel.
stock UseInternet(iClient, iEntity)
{
	if(!bBuildModEnabled)
	{
		
	}else{
		ShowMOTDPanel(iClient, "Internet", sBuildModEntityUrl[iEntity], MOTDPANEL_TYPE_URL); 
	}
}

//Sends out a normal beam to a prop.
stock NormalBeam(iClient, iEntity)
{
	decl Float:iClientAngles[3], Float:iClientOrigin[3], Float:iEntityOrigin[3];
	GetClientAbsOrigin(iClient, iClientOrigin);
	GetClientEyeAngles(iClient, iClientAngles);
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", iEntityOrigin);
	TE_SetupBeamPoints(iClientOrigin, iEntityOrigin, tPhys, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, physWhite, 10);
	TE_SendToAll();
	TE_SetupSparks(iEntityOrigin, iClientAngles, 3, 2);
	TE_SendToAll();
	TE_SetupArmorRicochet(iEntityOrigin, iClientAngles);
	TE_SendToAll();
}

//Sends out a delete beam to a prop.
stock DeleteBeam(iClient, iEntity)
{
	decl Float:iClientAngles[3], Float:iClientOrigin[3], Float:iEntityOrigin[3];
	GetClientAbsOrigin(iClient, iClientOrigin);
	GetClientEyeAngles(iClient, iClientAngles);
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", iEntityOrigin);
	TE_SetupBeamPoints(iClientOrigin, iEntityOrigin, tBeam, tHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, greyColor, 10);
	TE_SendToAll();
	TE_SetupSparks(iEntityOrigin, iClientAngles, 3, 2);
	TE_SendToAll();
	TE_SetupArmorRicochet(iEntityOrigin, iClientAngles);
	TE_SendToAll();
}

//Sends a message to a client.
stock sMessage(iClient, String:sMess[])
{
	CPrintToChat(iClient, "{blue}|BuildMod|{default} %s", sMess);
}

//Sends a message to the server.
stock sMessageAll(String:sMess[])
{
	CPrintToChatAll("{blue}|BM|{default} %s", sMess);
}
