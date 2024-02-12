#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <fun>
#include <cstrike>

#define FM_MONEY_OFFSET 115

new kaina_2000, kaina_4000, kaina_6000, kaina_8000, kaina_12000, kaina_14000, kaina_16000
new cvar_mod_wait
new liko = 0


//Boolean of when NPC spawned 
new bool: g_NpcSpawn[33]; 
//Boolean to check if NPC is alive or not 
new bool: g_NpcDead[33]; 
//Classname for our NPC 
new const g_NpcClassName[] = "ent_npc"; 
//Constant model for NPC 
new const g_NpcModel[] = "models/barney.mdl"; 

//List of sounds our NPC will emit when damaged 
new const g_NpcSoundPain[][] =  
{ 
    "barney/ba_pain1.wav", 
    "barney/ba_pain2.wav", 
    "barney/ba_pain3.wav" 
} 

//Sounds when killed 
new const g_NpcSoundDeath[][] = 
{ 
    "barney/ba_die1.wav", 
    "barney/ba_die2.wav", 
    "barney/ba_die3.wav" 
} 

//Sounds when we knife our flesh NPC
new const g_NpcSoundKnifeHit[][] = 
{
	"weapons/knife_hit1.wav",
	"weapons/knife_hit2.wav",
	"weapons/knife_hit3.wav",
	"weapons/knife_hit4.wav"
}

new const g_NpcSoundKnifeStab[] = "weapons/knife_stab.wav";

//List of idle animations 
new const NPC_IdleAnimations[] = { 0, 1, 2, 3, 11, 12, 18, 21, 39, 63, 65 };

//Sprites for blood when our NPC is damaged
new spr_blood_drop, spr_blood_spray

//Player cooldown for using our NPC 
new Float: g_Cooldown[32];

//Boolean to check if we knifed our NPC
new bool: g_Hit[32];

public plugin_init()
{
	register_plugin("NPC Plugin", "2.1", "Mazza/saimon");
	register_clcmd("say /npc", "ClCmd_NPC");
	
	register_logevent("Event_NewRound", 2, "1=Round_Start")
		
	RegisterHam(Ham_TakeDamage, "info_target", "npc_TakeDamage");
	RegisterHam(Ham_Killed, "info_target", "npc_Killed");
	RegisterHam(Ham_Think, "info_target", "npc_Think");
	RegisterHam(Ham_TraceAttack, "info_target", "npc_TraceAttack");
	RegisterHam(Ham_ObjectCaps, "player", "npc_ObjectCaps", 1 );
	
	register_forward(FM_EmitSound, "npc_EmitSound"); 
	
	kaina_2000 = register_cvar("he_kaina", "2000")
	kaina_4000 = register_cvar("hp_kaina", "4000")
	kaina_6000 = register_cvar("gp_kaina", "6000")
        kaina_8000 = register_cvar("hex_kaina", "8000")
	kaina_12000 = register_cvar("usp_kaina", "12000")
	kaina_14000 = register_cvar("revive_kaina", "14000")
	kaina_16000 = register_cvar("loterija_kaina", "16000")
	
	cvar_mod_wait = register_cvar("jb_mod_wait", "25.0");

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

public plugin_precache()
{
	spr_blood_drop = precache_model("sprites/blood.spr")
	spr_blood_spray = precache_model("sprites/bloodspray.spr")
	
	new i;
	for(i = 0 ; i < sizeof g_NpcSoundPain ; i++)
		precache_sound(g_NpcSoundPain[i]);
	for(i = 0 ; i < sizeof g_NpcSoundDeath ; i++)
		precache_sound(g_NpcSoundDeath[i]);

	precache_model(g_NpcModel)
}


public plugin_cfg()
{
	Load_Npc()
}

public ClCmd_NPC(id)
{
	if(get_user_flags(id) & ADMIN_RCON)
	{		
	        new menu = menu_create("NPC kurimas", "Menu_Handler");
		
		menu_additem(menu, "Kurti NPC", "1");
	        menu_additem(menu, "Trinti NPC", "2");
	        menu_additem(menu, "Issaugoti NPC", "3");
	        menu_additem(menu, "Naikinti visus NPC", "4");
	
	        menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);

	        menu_display(id, menu);
	}
	else
	{
		print_colorchat(id, "!g[!gNPC] Prieiga uzdrausta. Jus negalite kuri NPC botu.")
	}
}

public Menu_Handler(id, menu, item)
{
	//If user chose to exit menu we will destroy our menu
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new info[6], szName[64];
	new access, callback;
	
	menu_item_getinfo(menu, item, access, info, charsmax(info), szName, charsmax(szName), callback);
	
	new key = str_to_num(info);
	
	switch(key)
	{
		case 1:
		{
			//Create our NPC
			Create_Npc(id);
		}
		case 2:
		{
			//Remove our NPC by the users aim
			new iEnt, body, szClassname[32];
			get_user_aiming(id, iEnt, body);
			
			if (is_valid_ent(iEnt)) 
			{
				entity_get_string(iEnt, EV_SZ_classname, szClassname, charsmax(szClassname));
				
				if (equal(szClassname, g_NpcClassName)) 
				{
					remove_entity(iEnt);
				}
				
			}
		}
		case 3:
		{
			//Save the current locations of all the NPCs
			Save_Npc();
			
			client_print(id, print_chat, "[AMXX] NPC origin saved succesfully");
		}
		case 4:
		{
			//Remove all NPCs from the map
			remove_entity_name(g_NpcClassName);
			
			client_print(id, print_chat, "[AMXX] ALL NPC origin removed");
		}
	}
	
	//Keep the menu displayed when we choose an option
	menu_display(id, menu);
	
	return PLUGIN_HANDLED;
}

public npc_TakeDamage(iEnt, inflictor, attacker, Float:damage, bits)
{
	//Make sure we only catch our NPC by checking the classname
	new className[32];
	entity_get_string(iEnt, EV_SZ_classname, className, charsmax(className))
	
	if(!equali(className, g_NpcClassName))
		return;
		
	//Play a random animation when damanged
	Util_PlayAnimation(iEnt, random_num(13, 17), 1.25);

	//Make our NPC say something when it is damaged
	//NOTE: Interestingly... Our NPC mouth (which is a controller) moves!! That saves us some work!!
	emit_sound(iEnt, CHAN_VOICE, g_NpcSoundPain[random(sizeof g_NpcSoundPain)],  VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	g_Hit[attacker] = true;
}

public npc_Killed(iEnt)
{
	new className[32];
	entity_get_string(iEnt, EV_SZ_classname, className, charsmax(className))
	
	if(!equali(className, g_NpcClassName))
		return HAM_IGNORED;

	//Player a death animation once our NPC is killed
	Util_PlayAnimation(iEnt, random_num(25, 30))

	//Because our NPC may look like it is laying down. 
	//The bounding box size is still there and it is impossible to change it so we will make the solid of our NPC to nothing
	entity_set_int(iEnt, EV_INT_solid, SOLID_NOT);

	//The voice of the NPC when it is dead
	emit_sound(iEnt, CHAN_VOICE, g_NpcSoundDeath[random(sizeof g_NpcSoundDeath)],  VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

	//Our NPC is dead so it shouldn't take any damage and play any animations
	entity_set_float(iEnt, EV_FL_takedamage, 0.0);
	//Our death boolean should now be true!!
	g_NpcDead[iEnt] = true;
		
	//The most important part of this forward!! We have to block the death forward.
	return HAM_SUPERCEDE
}

public npc_Think(iEnt)
{
	if(!is_valid_ent(iEnt))
		return;
	
	static className[32];
	entity_get_string(iEnt, EV_SZ_classname, className, charsmax(className))
	
	if(!equali(className, g_NpcClassName))
		return;
	
	//We can remove our NPC here if we wanted to but I left this blank as I personally like it when there is a NPC coprse laying around
	if(g_NpcDead[iEnt])
	{
		return;
	}
		
	//Our NPC just spawned
	if(g_NpcSpawn[iEnt])
	{
		static Float: mins[3], Float: maxs[3];
		pev(iEnt, pev_absmin, mins);
		pev(iEnt, pev_absmax, maxs);

		//Draw a box which is the size of the bounding NPC
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BOX)
		engfunc(EngFunc_WriteCoord, mins[0])
		engfunc(EngFunc_WriteCoord, mins[1])
		engfunc(EngFunc_WriteCoord, mins[2])
		engfunc(EngFunc_WriteCoord, maxs[0])
		engfunc(EngFunc_WriteCoord, maxs[1])
		engfunc(EngFunc_WriteCoord, maxs[2])
		write_short(100)
		write_byte(random_num(25, 255))
		write_byte(random_num(25, 255))
		write_byte(random_num(25, 255))
		message_end();
		
		//Our NPC spawn boolean is now set to false
		g_NpcSpawn[iEnt] = false;
	}
	
	//Choose a random idle animation
	Util_PlayAnimation(iEnt, NPC_IdleAnimations[random(sizeof NPC_IdleAnimations)]);

	//Make our NPC think every so often
	entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + random_float(5.0, 10.0));
}

public npc_TraceAttack(iEnt, attacker, Float: damage, Float: direction[3], trace, damageBits)
{
	if(!is_valid_ent(iEnt))
		return;
	
	new className[32];
	entity_get_string(iEnt, EV_SZ_classname, className, charsmax(className))
	
	if(!equali(className, g_NpcClassName))
		return;
		
	//Retrieve the end of the trace
	new Float: end[3]
	get_tr2(trace, TR_vecEndPos, end);
	
	//This message will draw blood sprites at the end of the trace
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, end[0])
	engfunc(EngFunc_WriteCoord, end[1])
	engfunc(EngFunc_WriteCoord, end[2])
	write_short(spr_blood_spray)
	write_short(spr_blood_drop)
	write_byte(247) // color index
	write_byte(random_num(1, 5)) // size
	message_end()
}

public npc_ObjectCaps(id)
{
	//Make sure player is alive
	if(!is_user_alive(id))
		return;

	//Check when player presses +USE key
	if(get_user_button(id) & IN_USE)
	{		
		//Check cooldown of player when using our NPC
		static Float: gametime ; gametime = get_gametime();
		if(gametime - 1.0 > g_Cooldown[id])
		{
			//Get the classname of whatever ent we are looking at
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			//Make sure our aim is looking at a NPC
			if(equali(szAimingEnt, g_NpcClassName))
			{
				check_team(id)				
				
			}
			
			//Set players cooldown to the current gametime
			g_Cooldown[id] = gametime;
		}
	}
}

public check_team(id)
{
	if(cs_get_user_team(id) == CS_TEAM_T)
	{
		shop(id)
	}
	else
	{
		print_colorchat(id, "!g[!gANTANIUKAS] !yDeja, bet kaleimo priziuretoju neaptarnauju !")
	}
}
		

public shop(id)
{
	
	new szText[100]
		
	new menu = menu_create("\rAntaniuko parduotuve", "parduotuve")
				
	formatex(szText, charsmax(szText), "+50 givybiu [ $%d ]", get_pcvar_num(kaina_4000))
	menu_additem(menu, szText, "1")
	
	formatex(szText, charsmax(szText), "Smoke granata [ $%d ]", get_pcvar_num(kaina_2000))
	menu_additem(menu, szText, "2")
	
	formatex(szText, charsmax(szText), "Granatu komplektas [ $%d ]", get_pcvar_num(kaina_6000))
	menu_additem(menu, szText, "3")

	formatex(szText, charsmax(szText), "He Granata [ $%d ] \w[\yLiko \r%d\y vnt.\w]", get_pcvar_num(kaina_8000), 1-liko)
	menu_additem(menu, szText, "4")
	
	formatex(szText, charsmax(szText), "USP (2 kulkos) [ $%d ]", get_pcvar_num(kaina_12000))
	menu_additem(menu, szText, "5")
		
	formatex(szText, charsmax(szText), "Prikelti zaideja [ $%d ]", get_pcvar_num(kaina_14000))
	menu_additem(menu, szText, "6")
				
	formatex(szText, charsmax(szText), "Laimes ratas [ $%d ]", get_pcvar_num(kaina_16000))
	menu_additem(menu, szText, "7")	
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0)
}

public parduotuve(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	new Data[6];
	new Access;
	new Callback;
	new Name[64];
	menu_item_getinfo(menu, item, Access, Data, 5, Name, 63, Callback)
	
	new Key = str_to_num(Data);
	
	switch (Key)
	{
		case 1:
		{
			
			new Money = fm_get_user_money(id)
			new Pcvar = get_pcvar_num(kaina_4000)
			new Health = get_user_health(id)
			
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			if(!equali(szAimingEnt, g_NpcClassName))
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yKad kazka nusipirktum, privalai !g buti prie manes !y. Nebandyk vogti !")
				return PLUGIN_HANDLED;
			}					
			else if(Money < Pcvar)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu neturi pakankamai !gpinigu !ykad pirktum si daikta !")
			}
			else
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yPasigydei !g+50HP !y !")
				fm_set_user_money(id, Money-Pcvar)
				fm_set_user_health(id, Health+50)
			}
		}		
		case 2:
		{
			
			new Money = fm_get_user_money(id)
			new Pcvar = get_pcvar_num(kaina_2000)
			
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			if(!equali(szAimingEnt, g_NpcClassName))
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yKad kazka nusipirktum, privalai !g buti prie manes !y. Nebandyk vogti !")
				return PLUGIN_HANDLED;
			}			
			else if (Money < Pcvar)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu neturi pakankamai !gpinigu !ykad pirktum si daikta !")
			}
			else
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu nusipirkai !gSMOKE granata !y !")
				fm_set_user_money(id, Money-Pcvar)
				give_item(id, "weapon_smokegrenade")
			}
		}
		
		case 3:
		{
		
			new Money = fm_get_user_money(id)
			new Pcvar = get_pcvar_num(kaina_6000)
			
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			if(!equali(szAimingEnt, g_NpcClassName))
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yKad kazka nusipirktum, privalai !g buti prie manes !y. Nebandyk vogti !")
				return PLUGIN_HANDLED;
			}				
			else if (Money < Pcvar)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu neturi pakankamai !gpinigu !ykad pirktum si daikta !")
			}
			else
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu nusipirkai !ggranatu komplekta !y !")
				fm_set_user_money(id, Money-Pcvar)
				give_item(id, "weapon_flashbang")
				give_item(id, "weapon_smokegrenade")
                                cs_set_user_bpammo(id, CSW_SMOKEGRENADE, 2)
			}
		}
                case 4:
		{
			
			new Money = fm_get_user_money(id)
			new Pcvar = get_pcvar_num(kaina_8000)
			
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			if(!equali(szAimingEnt, g_NpcClassName))
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yKad kazka nusipirktum, privalai !g buti prie manes !y. Nebandyk vogti !")
				return PLUGIN_HANDLED;
			}
                        else if (liko == 1)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yAtsiprasome, taciau prekes !gHE granata !ysandelyje nebeliko !")
                                return PLUGIN_HANDLED;
			}			
			else if (Money < Pcvar)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu neturi pakankamai !gpinigu !ykad pirktum si daikta !")
			}
			else
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu nusipirkai !gHE granata !y !")
				fm_set_user_money(id, Money-Pcvar)
				give_item(id, "weapon_hegrenade")
                                liko++
			}
		}		
		case 5:
		{
			
			new Money = fm_get_user_money(id)
			new Pcvar = get_pcvar_num(kaina_12000)
			
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			if(!equali(szAimingEnt, g_NpcClassName))
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yKad kazka nusipirktum, privalai !g buti prie manes !y. Nebandyk vogti !")
				return PLUGIN_HANDLED;
			}			
			else if (Money < Pcvar)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu neturi pakankamai !gpinigu !ykad pirktum si daikta !")
			}
			else
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu nusipirkai !gUSP ginkla !y !")
				fm_set_user_money(id, Money-Pcvar)
				give_item(id, "weapon_usp")
	                        cs_set_weapon_ammo(find_ent_by_owner(1, "weapon_usp", id), 2);
			}
		}
		case 6:
		{
			
			new Money = fm_get_user_money(id)
			new Pcvar = get_pcvar_num(kaina_14000)
			
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			if(!equali(szAimingEnt, g_NpcClassName))
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yKad kazka nusipirktum, privalai !g buti prie manes !y. Nebandyk vogti !")
				return PLUGIN_HANDLED;
			}			
			else if (Money < Pcvar)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu neturi pakankamai !gpinigu !ykad pirktum si daikta !")
			}
			else
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu nusipirkai !gzaidejo prikelima !y !")
				prikelti(id)
			}
		}
		case 7:
		{
			
			new Money = fm_get_user_money(id)
			new Pcvar = get_pcvar_num(kaina_16000)
			
			static iTarget, iBody, szAimingEnt[32];
			get_user_aiming(id, iTarget, iBody, 75);
			entity_get_string(iTarget, EV_SZ_classname, szAimingEnt, charsmax(szAimingEnt));
			
			if(!equali(szAimingEnt, g_NpcClassName))
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yKad kazka nusipirktum, privalai !g buti prie manes !y. Nebandyk vogti !")
				return PLUGIN_HANDLED;
			}			
			else if (Money < Pcvar)
			{
				print_colorchat(id, "!g[!gANTANIUKAS] !yTu neturi pakankamai !gpinigu !ykad pirktum si daikta !")
			}
			else
			{
				ridenti(id, random_num(1, 7));
				fm_set_user_money(id, Money-Pcvar)
				
			}
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}	


public ridenti(id, randomai)
{
	
	switch(randomai)
	{
		case 1:
		{
			cs_set_user_money(id, 15000)
			print_colorchat(id, "!g[!gANTANIUKAS] !yJus gavote !g15000 !ypinigu !")
		}
		case 2:
		{
			set_user_health(id, 200)
			print_colorchat(id, "!g[!gANTANIUKAS] !yJus gavote !g200 !ygivybiu !")
		}
		case 3:
		{
			set_user_health(id, 15)
			print_colorchat(id, "!g[!gANTANIUKAS] !yDeja , bet jums nepasiseke. Jusu givybes sumazintos iki !g15 !ygivybiu !")
		}
		case 4:
		{
			cs_set_user_money(id, 0)
			print_colorchat(id, "!g[!gANTANIUKAS] !yDeja , bet jums nepasiseke. Jusu praradote !gvisus !ypinigus !")
		}
		case 5:
		{
			give_item(id, "weapon_deagle")
			print_colorchat(id, "!g[!gANTANIUKAS] !ySveikinimai ! . Jus laimejote deagle su !7 !ykulkomis !")
		}
		case 6:
		{
			give_item(id, "weapon_hegrenade")
			give_item(id, "weapon_flashbang")
			give_item(id, "weapon_smokegrenade")
			print_colorchat(id, "!g[!gANTANIUKAS] !yJus laimejote !gvisa granatu !ykomplekta !")
		}
		case 7:
		{
			give_item(id, "weapon_ak47")
			cs_set_user_bpammo(id, CSW_AK47, 255)
			print_colorchat(id, "!g[!gANTANIUKAS] !yNeitiketina ! Jus laimejote !gak47 su pilna apkaba !y!")
			new szName[32]; 
			get_user_name(id, szName, 31); 
			
			if(get_pcvar_float(cvar_mod_wait) > 1.0)
		        {
			                print_colorchat(0, "!g[!tISPEJIMAS!g] !yIgoris Molkovas (slapyvardis : !t%s) pabego is kaleimo su !gak47 !ysaunamuoju ginklu!", szName, get_pcvar_float(cvar_mod_wait));
					print_colorchat(0, "!g[!tISPEJIMAS!g] !yIgoris Molkovas (slapyvardis : !t%s) pabego is kaleimo su !gak47 !ysaunamuoju ginklu!", szName, get_pcvar_float(cvar_mod_wait));
					print_colorchat(0, "!g[!tISPEJIMAS!g] !yIgoris Molkovas (slapyvardis : !t%s) pabego is kaleimo su !gak47 !ysaunamuoju ginklu!", szName, get_pcvar_float(cvar_mod_wait));
	                }
		}
	}
}

public prikelti(id) 
{ 		
	new menu = menu_create("\rP\wrasirinkite zaideja:", "player"); 
	
	new players[32], pnum, tempid; 
	new szName[32], szTempid[10]; 
	
	get_players(players, pnum, "b");
	
	
	for( new i; i<pnum; i++ ) 
	{ 
		tempid = players[i];
							
		get_user_name(tempid, szName, 31); 
		num_to_str(tempid, szTempid, 9); 
		menu_additem(menu, szName, szTempid, 0);
	} 
	menu_display(id, menu); 
	return PLUGIN_CONTINUE; 
} 

public player(id, menu, item)
{ 
	if(item == MENU_EXIT) 
	{ 
		menu_destroy(menu); 
		return PLUGIN_HANDLED; 
	} 
	
	new data[6], iName[64]; 
	new access, callback; 
	menu_item_getinfo(menu, item, access, data,5, iName, 63, callback); 

        new Money = fm_get_user_money(id)
	new Pcvar = get_pcvar_num(kaina_14000)
	
	new tempid = str_to_num(data); 

        if(cs_get_user_team(tempid) == CS_TEAM_SPECTATOR)
        {
                print_colorchat(id, "!g[!tANTANIUKAS!g] !yPrikelti stebetoju !gneimanoma!y.") 
                prikelti(id)
                return 1;
        }
        else if(cs_get_user_team(tempid) == CS_TEAM_UNASSIGNED)
        {
                print_colorchat(id, "!g[!tANTANIUKAS!g] !yPrikelti nepasirinkusio komandos zaidejo !gneimanoma!y.") 
                prikelti(id)
                return 1;
        }
        else if(is_user_alive(tempid))
        {
                print_colorchat(id, "!g[!tANTANIUKAS!g] !yPrikelti gyvo zaidejo !gneimanoma!y.") 
                prikelti(id)
                return 1;
        }

        new parm[1]
	parm[0]=tempid

        if(!(is_user_alive(id)))
        {
		fm_set_user_money(id, Money+Pcvar)

		print_colorchat(id, "!g[!tANTANIUKAS!g] !yDeja, privalai buti gyvas. Tavo pinigai sugrazinti. :)")

                return PLUGIN_HANDLED
        }
        else
        {
		set_task(0.5,"player_spawn",72,parm,1)
		set_task(0.7,"player_spawn",72,parm,1)
	
		new vardas[32]; 
		get_user_name(id, vardas, 31);
 	
		new zaidejas[32];
		get_user_name(tempid, zaidejas, 31)

        	fm_set_user_money(id, Money-Pcvar)
	
		print_colorchat(0, "!g[!tANTANIUKAS!g] !yZaidejas!t%s !yprikele zaideja !t%s !yuz !g14000 $ !y!", vardas, zaidejas);
        }	 	
		
	menu_destroy(menu); 
	return PLUGIN_HANDLED; 
}

public player_spawn(parm[1])
{
	spawn(parm[0])
}				

public npc_EmitSound(id, channel, sample[], Float:volume, Float:attn, flag, pitch)
{
	//Make sure player is alive
	if(!is_user_connected(id))
		return FMRES_SUPERCEDE;

	//Catch the current button player is pressing
	new iButton = get_user_button(id);
					
	//If the player knifed the NPC
	if(g_Hit[id])
	{	
		//Catch the string and make sure its a knife 
		if (sample[0] == 'w' && sample[1] == 'e' && sample[8] == 'k' && sample[9] == 'n')
		{
			//Catch the file of _hitwall1.wav or _slash1.wav/_slash2.wav
			if(sample[17] == 's' || sample[17] == 'w')
			{
				//If player is slashing then play the knife hit sound
				if(iButton & IN_ATTACK)
				{
					emit_sound(id, CHAN_WEAPON, g_NpcSoundKnifeHit[random(sizeof g_NpcSoundKnifeHit)], volume, attn, flag, pitch);
				}
				//If player is tabbing then play the stab sound
				else if(iButton & IN_ATTACK2)
				{
					emit_sound(id,CHAN_WEAPON, g_NpcSoundKnifeStab, volume, attn, flag, pitch);
				}

				//Reset our boolean as player is not hitting NPC anymore
				g_Hit[id] = false;
				
				//Block any further sounds to be played
				return FMRES_SUPERCEDE
			}
		}
	}
	
	return FMRES_IGNORED
}

public Event_NewRound()
{
        liko = 0

	new iEnt = -1;
	
	//Scan and find all of the NPC classnames
	while( ( iEnt = find_ent_by_class(iEnt, g_NpcClassName) ) )
	{
		//If we find a NPC which is dead...
		if(g_NpcDead[iEnt])
		{
			//Reset the solid box
                        entity_set_int(iEnt, EV_INT_solid, SOLID_BBOX);
			//Make our NPC able to take damage again
			entity_set_float(iEnt, EV_FL_takedamage, 1.0);
			//Make our NPC instanstly think
			entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.01);
			
			//Reset the NPC boolean to false
			g_NpcDead[iEnt] = false;
		}	
		
                entity_set_float(iEnt, EV_FL_health, 500000.0);
	}
}

Create_Npc(id, Float:flOrigin[3]= { 0.0, 0.0, 0.0 }, Float:flAngle[3]= { 0.0, 0.0, 0.0 } )
{
	//Create an entity using type 'info_target'
	new iEnt = create_entity("info_target");

        //Set weapon for NPC
        give_weapon(iEnt);
	
	//Set our entity to have a classname so we can filter it out later
	entity_set_string(iEnt, EV_SZ_classname, g_NpcClassName);
		
	//If a player called this function
	if(id)
	{
		//Retrieve the player's origin
		entity_get_vector(id, EV_VEC_origin, flOrigin);
		//Set the origin of the NPC to the current players location
		entity_set_origin(iEnt, flOrigin);
		//Increase the Z-Axis by 80 and set our player to that location so they won't be stuck
		flOrigin[2] += 80.0;
		entity_set_origin(id, flOrigin);
		
		//Retrieve the player's  angle
		entity_get_vector(id, EV_VEC_angles, flAngle);
		//Make sure the pitch is zeroed out
		flAngle[0] = 0.0;
		//Set our NPC angle based on the player's angle
		entity_set_vector(iEnt, EV_VEC_angles, flAngle);
	}
	//If we are reading from a file
	else 
	{
		//Set the origin and angle based on the values of the parameters
		entity_set_origin(iEnt, flOrigin);
		entity_set_vector(iEnt, EV_VEC_angles, flAngle);
	}

	//Set our NPC to take damange and how much health it has
	entity_set_float(iEnt, EV_FL_takedamage, 1.0);
	entity_set_float(iEnt, EV_FL_health, 500000.0);

	//Set a model for our NPC
	entity_set_model(iEnt, g_NpcModel);
	//Set a movetype for our NPC
	entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_PUSHSTEP);
	//Set a solid for our NPC
	entity_set_int(iEnt, EV_INT_solid, SOLID_BBOX);
	
	//Create a bounding box for oru NPC
	new Float: mins[3] = {-12.0, -12.0, 0.0 }
	new Float: maxs[3] = { 12.0, 12.0, 75.0 }

	entity_set_size(iEnt, mins, maxs);
	
	//Controllers for our NPC. First controller is head. Set it so it looks infront of itself
	entity_set_byte(iEnt,EV_BYTE_controller1,125);
	// entity_set_byte(ent,EV_BYTE_controller2,125);
	// entity_set_byte(ent,EV_BYTE_controller3,125);
	// entity_set_byte(ent,EV_BYTE_controller4,125);
	
	//Drop our NPC to the floor
	drop_to_floor(iEnt);
	
	// set_rendering( ent, kRenderFxDistort, 0, 0, 0, kRenderTransAdd, 127 );
	
	//We just spawned our NPC so it should not be dead
    
	g_NpcSpawn[iEnt] = true;
	g_NpcDead[iEnt] = false;
	
	//Make it instantly think
	entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.01)
}

public give_weapon(ent)
{
        new entWeapon = create_entity("info_target");

        entity_set_string(entWeapon, EV_SZ_classname, "npc_weapon");

        entity_set_int(entWeapon, EV_INT_movetype, MOVETYPE_FOLLOW);
        entity_set_int(entWeapon, EV_INT_solid, SOLID_NOT);
        entity_set_edict(entWeapon, EV_ENT_aiment, ent);
        entity_set_model(entWeapon, "models/p_ak47.mdl");
}

public Load_Npc()
{
	//Get the correct filepath and mapname
	new szConfigDir[256], szFile[256], szNpcDir[256];
	
	get_configsdir(szConfigDir, charsmax(szConfigDir));
	
	new szMapName[32];
	get_mapname(szMapName, charsmax(szMapName));
	
	formatex(szNpcDir, charsmax(szNpcDir),"%s/NPC", szConfigDir);
	formatex(szFile, charsmax(szFile),  "%s/%s.cfg", szNpcDir, szMapName);
		
	//If the filepath does not exist then we will make one
	if(!dir_exists(szNpcDir))
	{
		mkdir(szNpcDir);
	}
	
	//If the map config file does not exist we will make one
	if(!file_exists(szFile))
	{
		write_file(szFile, "");
	}
	
	//Variables to store when reading our file
	new szFileOrigin[3][32]
	new sOrigin[128], sAngle[128];
	new Float:fOrigin[3], Float:fAngles[3];
	new iLine, iLength, sBuffer[256];
	
	//When we are reading our file...
	while(read_file(szFile, iLine++, sBuffer, charsmax(sBuffer), iLength))
	{
		//Move to next line if the line is commented
		if((sBuffer[0]== ';') || !iLength)
			continue;
		
		//Split our line so we have origin and angle. The split is the vertical bar character
		strtok(sBuffer, sOrigin, charsmax(sOrigin), sAngle, charsmax(sAngle), '|', 0);
				
		//Store the X, Y and Z axis to our variables made earlier
		parse(sOrigin, szFileOrigin[0], charsmax(szFileOrigin[]), szFileOrigin[1], charsmax(szFileOrigin[]), szFileOrigin[2], charsmax(szFileOrigin[]));
		
		fOrigin[0] = str_to_float(szFileOrigin[0]);
		fOrigin[1] = str_to_float(szFileOrigin[1]);
		fOrigin[2] = str_to_float(szFileOrigin[2]);
				
		//Store the yawn angle
		fAngles[1] = str_to_float(sAngle[1]);
		
		//Create our NPC
		Create_Npc(0, fOrigin, fAngles)
	}
}

public Save_Npc()
{
	//Variables
	new szConfigsDir[256], szFile[256], szNpcDir[256];
	
	//Get the configs directory.
	get_configsdir(szConfigsDir, charsmax(szConfigsDir));
	
	//Get the current map name
	new szMapName[32];
	get_mapname(szMapName, charsmax(szMapName));
	
	//Format 'szNpcDir' to ../configs/NPC
	formatex(szNpcDir, charsmax(szNpcDir),"%s/NPC", szConfigsDir);
	//Format 'szFile to ../configs/NPC/mapname.cfg
	formatex(szFile, charsmax(szFile), "%s/%s.cfg", szNpcDir, szMapName);
		
	//If there is already a .cfg for the current map. Delete it
	if(file_exists(szFile))
		delete_file(szFile);
	
	//Variables
	new iEnt = -1, Float:fEntOrigin[3], Float:fEntAngles[3];
	new sBuffer[256];
	
	//Scan and find all of my custom ents
	while( ( iEnt = find_ent_by_class(iEnt, g_NpcClassName) ) )
	{
		//Get the entities' origin and angle
		entity_get_vector(iEnt, EV_VEC_origin, fEntOrigin);
		entity_get_vector(iEnt, EV_VEC_angles, fEntAngles);
		
		//Format the line of one custom ent.
		formatex(sBuffer, charsmax(sBuffer), "%d %d %d | %d", floatround(fEntOrigin[0]), floatround(fEntOrigin[1]), floatround(fEntOrigin[2]), floatround(fEntAngles[1]));
		
		//Finally write to the mapname.cfg file and move on to the next line
		write_file(szFile, sBuffer, -1);
		
		//We are currentlying looping to find all custom ents on the map. If found another ent. Do the above till there is none.
	}
	
}

stock Util_PlayAnimation(index, sequence, Float: framerate = 1.0)
{
	entity_set_float(index, EV_FL_animtime, get_gametime());
	entity_set_float(index, EV_FL_framerate,  framerate);
	entity_set_float(index, EV_FL_frame, 0.0);
	entity_set_int(index, EV_INT_sequence, sequence);
}

stock fm_set_user_health(index, health) 
{
	health > 0 ? set_pev(index, pev_health, float(health)) : dllfunc(DLLFunc_ClientKill, index)
	return 1
}

stock fm_get_user_money(index) 
{
	return get_pdata_int(index, FM_MONEY_OFFSET)
}

stock fm_set_user_money(index, money, flash = 1) 
{
	set_pdata_int(index, FM_MONEY_OFFSET, money);
	
	message_begin(MSG_ONE, get_user_msgid("Money"), _, index);
	write_long(money);
	write_byte(flash ? 1 : 0);
	message_end();
}