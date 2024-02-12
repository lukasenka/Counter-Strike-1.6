#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#define PLUGIN "Give Free Admin"
#define VERSION "2.0"
#define AUTHOR "beast/saimon"

new Handle:g_SqlTuple, g_Query[256],

cvarSystem, cvarAuthBy, cvarAccess, cvarComment, cvarHost, cvarUser, cvarPassword, cvarDatabase;


public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_concmd("amx_givevip", "CmdGiveVip", ADMIN_RCON, "<nick> <days> [access] [account flags: de / ce] [comment]")
	
	/* default sistema:
	
	   gv_system:
		0 - multimod/aha.lt/armasi
		1 - psychical unban
	*/	
	cvarSystem = register_cvar("gv_system", "1")
	
	/* default auth metodas:
	
	   gv_auth_by:
		0 - privilegijos ant steamid
		1 - ant ip
	*/
	cvarAuthBy = register_cvar("gv_auth_by", "1")
	
	// default access
	cvarAccess = register_cvar("gv_access", "abcdeijhtxu")
	
	// default comment
	cvarComment = register_cvar("gv_comment", "FreeAdmin")
}

public plugin_cfg()
{
	cvarHost = get_cvar_pointer("amx_sql_host")
	cvarUser = get_cvar_pointer("amx_sql_user")
	cvarPassword = get_cvar_pointer("amx_sql_pass")
	cvarDatabase = get_cvar_pointer("amx_sql_db")	
	
	set_task(1.0, "InitSql")
}

public InitSql()
{
	new host[64], user[32], password[32], database[32]
	
	get_pcvar_string(cvarHost, host, charsmax(host))
	get_pcvar_string(cvarUser, user, charsmax(user))
	get_pcvar_string(cvarPassword, password, charsmax(password))
	get_pcvar_string(cvarDatabase, database, charsmax(database))
	
	g_SqlTuple = SQL_MakeDbTuple(host, user, password, database)
}

public CmdGiveVip(id, level ,cid)
{
	if(!cmd_access(id,level,cid,3))
		return PLUGIN_HANDLED

	static arg1[32], arg2[10], arg3[23], arg4[3], arg5[15]
	
	read_argv(1, arg1, 32)
	
	new target = cmd_target(id, arg1, 2)
	
	if(!target)
		return PLUGIN_HANDLED
	
	read_argv(2, arg2, charsmax(arg2))
	
	new vipTime = str_to_num(arg2)
	
	if(vipTime <= 0)
	{
		console_print(id, "Neteisingas vip laikas.")
		return PLUGIN_HANDLED
	}
		
	if(get_user_flags(target) & ADMIN_KICK)
	{
		console_print(id, "Zaidejas jau turi Admin statusa.")
		return PLUGIN_HANDLED
	}
	
	read_argv(3, arg3, charsmax(arg3))
	
	if(arg3[0] == EOS)
		get_pcvar_string(cvarAccess, arg3, charsmax(arg3))
		
	static authId[36], nick[32]
		
	read_argv(4, arg4, charsmax(arg4))
	
	if(arg4[0] != EOS)
	{
		if(!equal(arg4, "de") && !equal(arg4, "ce"))
		{
			console_print(id, "Neteisingas account flag.")
			return PLUGIN_HANDLED
		}
		
		if(arg4[0] == 'd')
			get_user_ip(target, authId, charsmax(authId), 1)	
		
		else
			get_user_authid(target, authId, charsmax(authId))
	}
	
	else
	{
		if(get_pcvar_num(cvarAuthBy))
		{
			get_user_ip(target, authId, charsmax(authId), 1)
			copy(arg4, charsmax(arg4), "de")
		}
		
		else
		{
			get_user_authid(target, authId, charsmax(authId))
			copy(arg4, charsmax(arg4), "ce")
		}
	}
	
	read_argv(5, arg5, charsmax(arg5))
	
	if(arg5[0] == EOS)
		get_pcvar_string(cvarComment, arg5, charsmax(arg5))	
	
	get_user_name(target, nick, charsmax(nick))
	
	new currTime = time()
	new timeLeft = currTime + (vipTime * 24 * 60 * 60)

	new data[2]
	
	data[0] = id
	
	if(get_pcvar_num(cvarSystem))
	{
		data[1] = 1
		
		formatex(g_Query, charsmax(g_Query), "INSERT INTO amx_amxadmins (username, steamid, \
		nickname, access, flags, created, expired, ashow, days, nr) VALUES ('%s', '%s', '%s', '%s', \
		'%s', %d, %d, 1, %d, '%s')", authId, authId, GetSecureName(nick), arg3, arg4, currTime, timeLeft, vipTime, arg5)
		
		SQL_ThreadQuery(g_SqlTuple, "AddVip1", g_Query, data, sizeof data)
	}
	
	else
	{
		
		static szCurrTime[12], sztimeLeft[12]
		
		format_time(szCurrTime, charsmax(szCurrTime), "%Y-%m-%d", currTime)
		format_time(sztimeLeft, charsmax(sztimeLeft), "%Y-%m-%d", timeLeft)
		
		data[1] = 0
		
		formatex(g_Query, charsmax(g_Query), "INSERT INTO amx_amxadmins (username, \
		nickname, access, flags, regtime, timeleft, nupirko, nr) VALUES ('%s', '%s', '%s', \
		'%s', '%s', '%s', 1, '%s')", authId, GetSecureName(nick), arg3, arg4, szCurrTime, sztimeLeft, arg5)
		
		SQL_ThreadQuery(g_SqlTuple, "AddVip1", g_Query, data, sizeof data)
	}
	
	return PLUGIN_HANDLED
}

public AddVip1(failState, Handle:query, error[], errCode, data[])
{
	if(errCode)
		return log_amx("Error in query [AddVip1] Error: %s", error)
	
	if(failState == TQUERY_CONNECT_FAILED)
		return log_amx("Could not connect to SQL database [AddVip1]")

	if(failState == TQUERY_QUERY_FAILED)
		return log_amx("Error in query [AddVip1]")
	
	if(data[1])
	{
		new data2[2]
		
		data2[0] = data[0]
		data2[1] = SQL_GetInsertId(query)
		
		SQL_ThreadQuery(g_SqlTuple, "AddVip2", "SELECT * FROM amx_serverinfo", data2, sizeof data2)
	}
	
	else
	{
		if(data[0])
		{
			if(is_user_connected(data[0]))
				console_print(data[0], "*** OK ***")
		}
		
		else
			console_print(0, "*** OK ***")	
		
		if(!task_exists())
			set_task(10.0, "ReloadAdmins")
	}
	
	return PLUGIN_CONTINUE
}

public AddVip2(failState, Handle:query, error[], errCode, data[])
{
	if(errCode)
		return log_amx("Error in query [AddVip2] Error: %s", error)	
	
	if(failState == TQUERY_CONNECT_FAILED)
		return log_amx("Could not connect to SQL database [AddVip2]")

	if(failState == TQUERY_QUERY_FAILED)
		return log_amx("Error in query [AddVip2]")
		
	static data2[3]
	
	data2[0] = data[0]
	data2[1] = data[1]
	
	while(SQL_MoreResults(query))
	{
		data2[2] = SQL_ReadResult(query, 0)
		
		formatex(g_Query, charsmax(g_Query), "INSERT INTO amx_admins_servers \
		(admin_id, server_id) VALUES (%d, %d)", data[1], data2[2])
		
		SQL_ThreadQuery(g_SqlTuple, "AddVip3", g_Query, data2, sizeof data2)
		
		SQL_NextRow(query)
	}
	
	return PLUGIN_CONTINUE
}

public AddVip3(failState, Handle:query, error[], errCode, data[])
{
	if(errCode)
		return log_amx("Error in query [AddVip3] Error: %s", error)	
	
	if(failState == TQUERY_CONNECT_FAILED)
		return log_amx("Could not connect to SQL database [AddVip3]")	
		
	if(failState == TQUERY_QUERY_FAILED)
		return log_amx("Error in query [AddVip3]")
	
	if(data[0])
	{
		if(is_user_connected(data[0]))
			console_print(data[0], "*** Server %d - OK ***", data[2])
	}
	
	else
		console_print(0, "*** Server %d - OK ***", data[2])
	
	if(!task_exists())
		set_task(10.0, "ReloadAdmins")
	
	return PLUGIN_CONTINUE
}

public ReloadAdmins()
{
	server_cmd("amx_reloadadmins")
	server_exec()
}

// STOCKS

// Credits hleV
GetSecureName(const name[])
{
	new secureName[64]
	copy(secureName, charsmax(secureName), name)
	   
	replace_all(secureName, charsmax(secureName), "\", "\\")
	replace_all(secureName, charsmax(secureName), "'", "\'")
	replace_all(secureName, charsmax(secureName), "`", "\`")
	   
	return secureName
}

stock print_colorchat(const id, const input[], any:...)
{
	new count = 1, players[32];
	static msg[191];
	vformat(msg,190,input,3);
	replace_all(msg,190,"!g","^4");// green txt
	replace_all(msg,190,"!y","^1");// orange txt
	replace_all(msg,190,"!t","^3");// team txt
	replace_all(msg,190,"!w","^0");// team txt
	if (id) players[0] = id; else get_players(players,count,"ch");
	for (new i=0;i<count;i++)
		if (is_user_connected(players[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}
}

stock get_user_name_ex(id)
{
	new szName[33];
	get_user_name(id, szName, charsmax(szName));

	replace_all(szName, charsmax(szName), "'", "\'");
	replace_all(szName, charsmax(szName), "^"", "\^"");
	
	return szName;
}

stock get_user_authid_ex(id) { new szAuthID[33]; get_user_authid(id, szAuthID, 34); return szAuthID; }
stock get_user_ip_ex(id) { new szAuthIP[33]; get_user_ip(id, szAuthIP, 34, 1); return szAuthIP; }