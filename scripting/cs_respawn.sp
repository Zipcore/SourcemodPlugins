#include <sourcemod>
#include <cstrike>

#define NAME ""
#define AUTHOR ""
#define DESCRIPTION ""
#define VERSION "1.0.0"
#define URL ""

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
	AddCommandListener(Command_JoinTeam, "jointeam");
	HookEvent("player_death", Event_PlayerDeath);
	
}

public Action:Event_PlayerDeath(Handle:Event, const String:Name[], bool:dontBroadcast) 
{
	decl iClient;
	iClient = GetClientOfUserId(GetEventInt(Event, "userid"));
	CreateTimer(1.0, tRespawnClient, iClient);
}

public Action:Command_JoinTeam(iClient, const String:command[], iArgs)
{
	CreateTimer(1.0, tRespawnClient, iClient);
}

public Action:tRespawnClient(Handle:timer, any:iClient)
{
	CS_RespawnPlayer(iClient);
}