#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>

new bool:joined[33] = false;
new bool:active;
new players_num;

public plugin_init()
{
	register_plugin("Admin roulette", "1.0", "saimon.lt");
	
	register_clcmd("say !adminroulette", "check_permissions");
	register_clcmd("say /adminroulette", "check_permissions");
	
	register_clcmd("say !players", "show_players");
	register_clcmd("say /players", "show_players");
	
	register_clcmd("say !join", "join_roulette");
	register_clcmd("say /join", "join_roulette");
	
	active = false;
	players_num = 0;
	
}

public check_permissions(id)
{
	if(active)
	{
		print_colorchat(id, "!g[!tFUN!g] [!tAdmin Roulette!g] !y Admin rulete jau vyksta. Rasykite !g!join!y.");
		return PLUGIN_HANDLED;
	}		
	else if(get_user_flags(id) & ADMIN_RCON)
	{
		active = true;
		
		new name[32];
		get_user_name(id, name, 31);
		
		print_colorchat(id, "!g[!Admin Roulette!g] !y Administratorius !g%s !ypradejo admin rulete. Rasykite !join norint zaisti.", name);
		
		set_task(120.0, "set_winner", id);
	}
	else
	{		
		print_colorchat(id, "!g[!tAdmin Roulette!g] !y Jus neturite reikiamu teisiu naudotis sia komanda.");
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public set_winner(id)
{
	new players[32], pnum, tempid;
	get_players(players, pnum, "h");	

	for( new i; i<pnum; i++)
	{ 
	        tempid = players[random(pnum)];
		
		if(joined[tempid] && is_user_connected(tempid) && players_num != 0)
		{
			new name[32];
			get_user_name(tempid, name, 31);
			print_colorchat(0, "!g[!tAdmin Roulette!g] !y Zaidejas !g%s !y laimejo SADMIN 30-ciai dienu. Sveikinimai !", name);
			
			server_cmd("amx_givevip #%d 30", get_user_userid(tempid)); 
			
			active = false;
                        players_num = 0;
		}
		else if((!(joined[tempid])) && players_num == 0)
		{
			print_colorchat(0, "!g[!tAdmin Roulette!g] !y Sistema negalejo isrinkti laimetojo, kadangi niekas nesutiko zaisti !");
			active = false;
		        return PLUGIN_HANDLED;
		}
		else
		{		
			set_winner(id);
		}
	}
	
	return PLUGIN_CONTINUE;
}

public show_players(id)
{
	if(active)
	{
		print_players_stats(id)
	}
	else
	{
		print_colorchat(0, "!g[!tAdmin Roulette!g] !y Atsiprasome, siuo metu admin rulete nevyksta !");
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public print_players_stats(user) 
{
	new steamnames[32][33]
	new message[256]
	new id, count, x, len
	
	new players[32], playersnum
	get_players( players, playersnum, "ch" )
	for( --playersnum; playersnum >= 0; playersnum-- )
	{
		id = players[playersnum]

		if(joined[id])
		{
			get_user_name( id, steamnames[count++], charsmax(steamnames[]) )
		}
	}

	len = formatex(message, charsmax(message), "^4[ADMIN ROULETE]^1 Zaidejai:^3", user)
	if( count > 0 ) 
	{
		for( x = 0 ; x < count ; x++ ) 
		{
			len += formatex(message[len], charsmax(message)-len, "^3 %s%s", steamnames[x], x < (count-1) ? ", ":"." )
			if( len > 96 ) 
			{
				ChatColor( user, message )
				len = format( message, 255, "^4" )
			}
		}
		ChatColor( user, message )
	}
	else
	{
		len += format( message[len], 255-len, "Zaideju nera.", user)
		ChatColor( user, message )
	}
}

public join_roulette(id)
{
        if(get_user_flags(id) & ADMIN_BAN && active && (!(joined[id])))
        {
		 print_colorchat(0, "!g[!tAdmin Roulette!g] !y Administratoriai zaisti negali !");
                 return PLUGIN_HANDLED;
        }
	else if(active && (!(joined[id])))
	{
		joined[id] = true;
		players_num++;
		
		new name[32];
		get_user_name(id, name, 31);
		print_colorchat(0, "!g[!tAdmin Roulette!g] !y Zaidejas !g%s !yzaidzia admin roulete ! Pamegink ir tu !", name);
	}
	else
	{
		print_colorchat(id, "!g[!tAdmin Roulette!g] !y Jus jau zaidziate arba rulete nevyksta !");
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}
		

stock ChatColor(const id, const input[], any:...)
{
    new count = 1, players[32]
    static msg[192]
    vformat(msg, 191, input, 3)
   
    replace_all(msg, 191, "!g", "^4") // Green Color
    replace_all(msg, 191, "!y", "^1") // Default Color
    replace_all(msg, 191, "!t", "^3") // Team Color
   
    if (id) players[0] = id; else get_players(players, count, "ch")
    {
        for (new i = 0; i < count; i++)
        {
            if (is_user_connected(players[i]))
            {
                message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i])
                write_byte(players[i]);
                write_string(msg);
                message_end();
            }
        }
    }
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