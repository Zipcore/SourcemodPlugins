#include <sourcemod>

#define NAME "Commandeh Hudz"
#define AUTHOR "FusionLockz"
#define DESCRIPTION "MAKES PRETTY CMDS :P"
#define VERSION "1.0.0"
#define URL ""

new iCommandNumber;

new String:sCommandsOne[1024];
new String:sCommandsTwo[1024];
new String:sCommandsThree[1024];
new String:sCommandsFour[1024];
new String:sCommandsFive[1024];

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
	AddCommandListener(Chat_Say, "say");
	AddCommandListener(Chat_Say, "say_team"); 

	iCommandNumber = 0; 
}

public OnClientPutInServer(iClient)
{
	CreateTimer(0.1, Timer_HUD, _, TIMER_REPEAT);
}

public Action:Timer_HUD(Handle:Timer)
{
	for (new i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i) && IsClientConnected(i))
		{
			SetHudTextParams(3.0, 0.0, 0.1, 255, 255, 0, 225, 0, 6.0, 0.1, 0.2);
			ShowHudText(i, -1, "%s\n%s\n%s\n%s\n%s", sCommandsOne, sCommandsTwo, sCommandsThree, sCommandsFour, sCommandsFive);
		}
	}
}

public Action:Chat_Say(iClient, const String:command[], iArgs)
{
	decl String:sText[1024];
	GetCmdArgString(sText, sizeof(sText));
	ReplaceString(sText, sizeof(sText), "say !", "!", true);
	StripQuotes(sText);
	switch(iCommandNumber)
	{
		case 0:
		{
			Format(sCommandsOne, sizeof(sCommandsOne), sText);
			iCommandNumber = 1;
		}
		case 1:
		{
			Format(sCommandsTwo, sizeof(sCommandsTwo), sText);
			iCommandNumber = 2;
		}
		case 2:
		{
			Format(sCommandsThree, sizeof(sCommandsThree), sText);
			iCommandNumber = 3;
		}
		case 3:
		{
			Format(sCommandsFour, sizeof(sCommandsFour), sText);
			iCommandNumber = 4;
		}
		case 4:
		{
			Format(sCommandsFive, sizeof(sCommandsFive), sText);
			iCommandNumber = 0;
		}
	}
} 
