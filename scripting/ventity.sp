#include <sourcemod>
#include <sdktools>

public OnPluginStart()
{
	RegConsoleCmd("sm_ventity", Command_ViewEntity, "");
	RegConsoleCmd("sm_unventity", Command_UnViewEntity, "");
}

public Action:Command_ViewEntity(iClient, iArgs)
{
	new iEnt = GetClientAimTarget(iClient, false);

	SetClientViewEntity(iClient, iEnt);

	return Plugin_Handled;
}

public Action:Command_UnViewEntity(iClient, iArgs)
{
	SetClientViewEntity(iClient, iClient);

	return Plugin_Handled;
}