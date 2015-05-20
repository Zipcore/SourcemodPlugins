#include <sourcemod>
#include <morecolors>

#define NAME "Custom Server Chat"
#define AUTHOR "FusionLock"
#define DESCRIPTION "Changes the color of the clients username & message in the server chat."
#define VERSION "1.0.8"
#define URL "http://steamcommunity.com/profiles/76561198054654475"

new Handle:g_hUsernameColor = INVALID_HANDLE;
new Handle:g_hMessageColor = INVALID_HANDLE;

new String:g_sUsernameColor[128];
new String:g_sMessageColor[128];

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
	g_hUsernameColor = CreateConVar("csc_usernamecolor", "orange", "What the usernames color will be.");
	g_hMessageColor = CreateConVar("csc_messagecolor", "white", "What the messages color will be.");

	GetConVarString(g_hUsernameColor, g_sUsernameColor, sizeof(g_sUsernameColor));
	GetConVarString(g_hMessageColor, g_sMessageColor, sizeof(g_sMessageColor));

	HookConVarChange(g_hUsernameColor, OnConvarsChanged);
	HookConVarChange(g_hMessageColor, OnConvarsChanged);

	AddCommandListener(Hook_Say, "say");
	AddCommandListener(Hook_Say, "say_team");
}

public OnConvarsChanged(Handle:hConvar, const String:sOldValue[], const String:sNewValue[])
{
	GetConVarString(g_hUsernameColor, g_sUsernameColor, sizeof(g_sUsernameColor));
	GetConVarString(g_hMessageColor, g_sMessageColor, sizeof(g_sMessageColor));
}

/*public StrStartsWith(const String:sMessage[], const String:sStartsWith[])
{
	decl String:sArg1[64];

	Format(sArg1, sizeof(sArg1), "%s", sMessage[0])

	if(StrContains(sMessage, "/", true) != -1)
	{
		return true;
	}else{
		return false;
	}
}*/

public Action:Hook_Say(iClient, const String:command[], iArgs)
{
	decl String:sMessage[1024];

	GetCmdArgString(sMessage, sizeof(sMessage));

	StripQuotes(sMessage);

	if(IsChatTrigger()
	{
		return Plugin_Handled;
	}else{
		CPrintToChatAll("{%s}%N{default}: {%s}%s", g_sUsernameColor, iClient, g_sMessageColor, sMessage);

		return Plugin_Handled;
	}
}
