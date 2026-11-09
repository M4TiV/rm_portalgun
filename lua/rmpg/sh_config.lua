-- Shared constants and console variables
RMPG = RMPG or {}

RMPG.WEAPON = "weapon_rm_portalgun"
RMPG.BOMB = "rmpg_prime_bomb"
RMPG.DETONATOR = "weapon_rmpg_detonator"
RMPG.MR_BOX = "weapon_rmpg_meeseeks_box"
RMPG.MEESEEKS = "rmpg_meeseeks"
-- Mr. Meeseeks model (shipped with the addon) and the stand-in used if it is missing
RMPG.MR_MODEL = "models/player/meeseeks/meeseeks.mdl"
RMPG.MR_FALLBACK = "models/player/corpse1.mdl"
RMPG.FREEZERAY = "weapon_rmpg_freezeray"
RMPG.FREEZEKNIFE = "weapon_rmpg_freezeknife"
RMPG.SYRINGE = "weapon_rmpg_dna_syringe"
RMPG.TANK = "rmpg_phoenix_tank"
RMPG.DRONE = "rmpg_prime_drone"
RMPG.REMOTE = "weapon_rmpg_drone_remote"
RMPG.PILLS = "weapon_rmpg_pills"
RMPG.PILL = "weapon_rmpg_pill"
RMPG.NEUTRINO = "rmpg_neutrino_bomb"
RMPG.LASER = "weapon_rmpg_laser"
RMPG.WORM = "rmpg_brain_worm"
RMPG.VERSION = "0.8"
RMPG.ARM = "weapon_rmpg_akira"
RMPG.IMPL_ON, RMPG.IMPL_OFF, RMPG.IMPL_FIRE, RMPG.IMPL_GRAB, RMPG.IMPL_HOOK, RMPG.IMPL_CLONE, RMPG.IMPL_SWAP = 1, 2, 3, 4, 5, 6, 7
RMPG.IMPL_POWER = 8 -- the Akira laser's big burst (IMPL_FIRE is its normal shot)
RMPG.IMPL_BITS = 4
-- Limbs that can be torn off (sv_gore.lua): the bone each one hangs from. The Rick Prime chip loses the four with a bit each
RMPG.LIMBS = { larm = "ValveBiped.Bip01_L_UpperArm", rarm = "ValveBiped.Bip01_R_UpperArm", lleg = "ValveBiped.Bip01_L_Thigh",
	rleg = "ValveBiped.Bip01_R_Thigh", head = "ValveBiped.Bip01_Head1" }
RMPG.LIMB_BIT = { larm = 1, rarm = 2, lleg = 4, rleg = 8 }
RMPG.EYEPATCH = "weapon_rmpg_eyepatch"
RMPG.EVAC_CHIP = "rmpg_evac_chip"
RMPG.CLONE = "rmpg_clone"
-- Drone modes: attack everyone except friends, protect the pilot (the remote in hand always steers them)
RMPG.DRONE_ATTACK, RMPG.DRONE_PROTECT = 1, 2
RMPG.UNITS_PER_METER = 52.49 -- 1 Hammer unit = 1.905 cm
RMPG.DEFAULT_COLOR = Vector(84, 255, 64)

-- Sounds: the portal sounds you supplied plus stock Half-Life 2 / Garry's Mod sounds
RMPG.SND = {
	fire      = "rmpg/fire.wav",          -- gun_fire.wav (shot)
	open      = "rmpg/portal_open.wav",   -- portal_spawn.ogg (a portal opening)
	close     = "rmpg/portal_close.wav",  -- close_portal.ogg
	enter     = "rmpg/portal_enter.wav",  -- portal_enter.ogg
	empty     = "rmpg/empty.wav",         -- empty_portal_gun.ogg
	deploy    = "physics/metal/weapon_impact_soft1.wav",
	slosh     = "player/footsteps/slosh2.wav",
	coreHum   = "ambient/energy/spark2.wav",
	reloadOut = "physics/glass/glass_bottle_impact_hard1.wav",
	reloadIn  = "items/battery_pickup.wav",
	coreIn    = "items/suitchargeok1.wav",
	pickup    = "items/ammo_pickup.wav",
	uiClick   = "garrysmod/ui_click.wav",
	uiHover   = "garrysmod/ui_hover.wav",
	uiOpen    = "buttons/combine_button1.wav",
	uiClose   = "buttons/combine_button2.wav",
	uiError   = "buttons/button10.wav",
	beep      = "buttons/blip1.wav",
	sdCharge  = "weapons/physcannon/superphys_chargeup.wav",
	sdSuck    = "ambient/levels/labs/teleport_preblast_suckin1.wav",
	sdLoop    = "weapons/physcannon/energy_sing_loop4.wav",
	sdImplode = "ambient/levels/labs/teleport_postblast_thunder1.wav",
	sdBoom    = "weapons/physcannon/energy_sing_explosion2.wav",
	zap       = "weapons/physcannon/energy_disintegrate4.wav",
	-- Rick Prime's bomb and its detonator
	bombArm    = "npc/roller/mine/combine_mine_deploy1.wav",
	bombDisarm = "npc/roller/mine/combine_mine_deactivate1.wav",
	bombBlip   = "npc/roller/mine/rmine_blip1.wav",
	bombSiren  = "npc/attack_helicopter/aheli_megabomb_siren1.wav",
	bombPre    = "npc/roller/mine/rmine_predetonate.wav",
	bombBoom   = "ambient/energy/whiteflash.wav",
	bombBass   = "ambient/explosions/explode_4.wav",
	disint     = "ambient/levels/citadel/weapon_disintegrate%d.wav", -- 1..4
	detClick   = "buttons/button24.wav",
	-- energy shield
	shieldHit     = "weapons/physcannon/energy_bounce%d.wav",       -- 1..2
	shieldZap     = "ambient/energy/zap%d.wav",                     -- 1, 2, 3, 5..9
	shieldBreak   = "physics/glass/glass_largesheet_break%d.wav",   -- 1..3
	shieldBreak2  = "ambient/levels/labs/electric_explosion2.wav",
	shieldUp      = "ambient/levels/citadel/zapper_warmup1.wav",
	shieldImplant = "items/suitchargeok1.wav",
	-- Mr. Meeseeks
	mrHello  = "rmpg/meeseeks_hello.wav",                   -- "I'm Mr. Meeseeks, look at me!"
	mrPoof   = "garrysmod/balloon_pop_cute.wav",
	mrButton = "buttons/button17.wav",
	mrPunch  = "physics/body/body_medium_impact_hard%d.wav", -- 1..6
	mrSwing  = "npc/vort/claw_swing%d.wav",                  -- 1..2
	mrCraft  = "weapons/crowbar/crowbar_impact%d.wav",        -- 1..2
	mrHeal   = "items/smallmedkit1.wav",
	-- freezing
	freezeLoop  = "ambient/gas/steam_loop1.wav",
	thawLoop    = "ambient/gas/cannister_loop.wav",
	freezeDone  = "physics/glass/glass_impact_bullet%d.wav",   -- 1..4
	shatter     = "physics/glass/glass_largesheet_break%d.wav", -- 1..3
	frostWind   = "ambient/wind/wind_snippet%d.wav",            -- 1..5
	knifeSlash  = "weapons/knife/knife_slash%d.wav",            -- 1..2
	knifeHit    = "weapons/knife/knife_hit%d.wav",              -- 1..4
	knifeStab   = "weapons/knife/knife_stab.wav",
	knifeWall   = "weapons/knife/knife_hitwall1.wav",
	knifeDeploy = "weapons/knife/knife_deploy1.wav",
	-- Operation Phoenix
	phxInject   = "items/medshot4.wav",
	phxTake     = "npc/barnacle/barnacle_gulp1.wav",
	phxFlesh    = "physics/flesh/flesh_squishy_impact_hard%d.wav", -- 1..4
	phxLoop     = "ambient/water/underwater.wav",
	phxReady    = "ambient/machines/spinup.wav",
	phxTransfer = "ambient/levels/labs/teleport_winddown1.wav",
	phxSpill    = "ambient/water/water_splash1.wav",
	-- dramatic exit pills
	pillShake   = "physics/plastic/plastic_box_impact_soft%d.wav", -- 1..4
	pillSwallow = "npc/barnacle/barnacle_gulp2.wav",
	pillFade    = "ambient/levels/labs/teleport_weird_voices1.wav",
	pillGone    = "ambient/machines/teleport1.wav",
	-- neutrino bomb
	nbSiren     = "ambient/alarms/klaxon1.wav",
	nbBoom      = "ambient/explosions/explode_6.wav",
	nbBoom2     = "ambient/levels/labs/teleport_postblast_thunder1.wav",
	nbHole      = "ambient/levels/citadel/portal_beam_loop1.wav",
	nbMeteor    = "weapons/explode%d.wav", -- 3..5
	-- Rick's laser gun
	laserFire     = "weapons/gauss/fire1.wav",
	laserOverheat = "ambient/gas/steam2.wav",
	laserDry      = "weapons/pistol/pistol_empty.wav",
	laserCharge   = "weapons/gauss/chargeloop.wav",
	laserBig      = "weapons/physcannon/superphys_launch1.wav",
	laserZap      = "ambient/energy/zap%d.wav", -- 1..3
	-- brain worm
	wormBite    = "npc/barnacle/barnacle_tongue_pull%d.wav", -- 1..3
	wormScream  = "npc/headcrab_poison/ph_scream%d.wav",     -- 1..3
	wormEat     = "npc/barnacle/barnacle_digesting%d.wav",   -- 1..2
	wormMeow    = "npc/headcrab/idle%d.wav",                 -- 1..3
	plumbus     = "physics/rubber/rubber_tire_impact_soft%d.wav", -- 1..3
	armStart    = "ambient/energy/whiteflash.wav",
	armLoop     = "ambient/levels/citadel/zapper_loop2.wav",
	armStop     = "ambient/levels/citadel/weapon_disintegrate2.wav",
	armShot     = "weapons/airboat/airboat_gun_energy%d.wav", -- 1..2
	armShotZap  = "ambient/energy/zap%d.wav",                 -- 1..3
	-- the acid vats
	acidSizzle  = "ambient/levels/canals/toxic_slime_sizzle%d.wav", -- 1..4
	acidGurgle  = "ambient/levels/canals/toxic_slime_gurgle%d.wav", -- 2..8 (there is no 1)
	acidPain    = "player/pl_burnpain%d.wav",                       -- 1..3
	acidSplash  = "ambient/water/water_splash%d.wav",               -- 1..3
	acidBreath  = "player/breathe1.wav",
	fruitPop    = "garrysmod/balloon_pop_cute.wav",
	tentShoot   = "npc/roller/mine/rmine_blades_out%d.wav",      -- 1..3
	tentHit     = "physics/metal/sawblade_stick%d.wav",          -- 1..3
	tentBack    = "npc/roller/mine/rmine_blades_in%d.wav",       -- 1..3
	tentCatch   = "doors/heavy_metal_stop1.wav",
	tentThrow   = "physics/metal/metal_solid_strain%d.wav",      -- 1..5
	tentSlide   = "npc/manhack/grind%d.wav",                     -- 1..5
	tentServo   = "npc/dog/dog_servo%d.wav",                     -- 1..3
	tentClick   = "npc/turret_floor/click1.wav",
	tentDeploy  = "npc/turret_floor/deploy.wav",
	tentFold    = "npc/turret_floor/retract.wav",
	primeTear   = "physics/body/body_medium_break%d.wav",         -- 2..4
	primeBack   = "physics/flesh/flesh_impact_bullet%d.wav",      -- 1..5
	primeRevive = "ambient/levels/labs/teleport_postblast_thunder1.wav",
	primeSwap   = "ambient/machines/teleport1.wav",
	primeLaugh  = { "vo/citadel/br_laugh01.wav", "vo/npc/barney/ba_laugh01.wav", "vo/npc/barney/ba_laugh02.wav",
		"vo/npc/barney/ba_laugh04.wav", "vo/ravenholm/madlaugh01.wav", "vo/ravenholm/madlaugh04.wav" }, -- getting up after a fake death
	trapOpen    = "ambient/levels/labs/teleport_preblast_suckin1.wav",
	trapWind    = "ambient/wind/wind_snippet%d.wav",              -- 1..5
	trapTear    = "physics/body/body_medium_break%d.wav",         -- 2..4
	trapSwallow = "physics/flesh/flesh_bloody_break.wav",
	trapSpit    = "weapons/physcannon/superphys_small_zap%d.wav", -- 1..4
	trapCrunch  = "npc/barnacle/barnacle_crunch2.wav",
	implantOut  = "physics/flesh/flesh_squishy_impact_hard%d.wav", -- 1..4
	trapSquish  = "physics/flesh/flesh_squishy_impact_hard%d.wav", -- 1..4
	tsStart     = "ambient/machines/thumper_shutdown1.wav",
	tsEnd       = "ambient/machines/spinup.wav",
	wormDie     = "npc/antlion_grub/squashed.wav",
	wormRoar    = "npc/antlion_guard/angry%d.wav",              -- 1..3
	wormSmash   = "physics/concrete/boulder_impact_hard%d.wav", -- 1..4
	-- Evil Morty's eyepatch
	patchOn     = "npc/combine_soldier/gear1.wav",
	patchMode   = "buttons/button16.wav",
	patchHack   = "buttons/combine_button5.wav",
	-- gravity boots
	bootsOn     = "items/suitchargeok1.wav",
	bootsOff    = "items/suitchargeno1.wav",
	bootsStep   = "player/footsteps/metal%d.wav", -- 1..4
	-- emergency evacuation
	evacJump    = "ambient/energy/zap%d.wav",      -- 1..3
	-- clones from other dimensions
	cloneShot   = "weapons/pistol/pistol_fire2.wav",
	cloneHi     = "vo/npc/male01/hi0%d.wav",   -- 1..2
	clonePain   = "vo/npc/male01/pain0%d.wav", -- 1..9
	-- Rick Prime's drones
	droneLaser  = "weapons/airboat/airboat_gun_energy%d.wav", -- 1..2
	droneHum    = "npc/manhack/mh_engine_loop1.wav",
	droneOn     = "npc/turret_floor/deploy.wav",
	droneOff    = "npc/turret_floor/retract.wav",
	droneAlert  = "npc/turret_floor/active.wav",
	droneDie    = "npc/turret_floor/die.wav",
}

RMPG.DEST_RANDOM   = 1
RMPG.DEST_LOCATION = 2
RMPG.DEST_PLAYER   = 3
RMPG.DEST_MANUAL   = 4
RMPG.DEST_QUICK    = 5 -- exit where you aim, entrance right in front of you
RMPG.DEST_TRAP     = 6 -- one portal where you aim that tears apart whoever touches it (sv_trap.lua)
RMPG.DEST_UNIVERSE = 7 -- one portal to another player's game (the universe browser, kept in dev/wip for now)
RMPG.DEST_CHAIN    = 8 -- every shot adds a portal, and each leads into the one opened after it
RMPG.DEST_COORDS   = 9 -- the exit opens at coordinates you type, turned the way you set it
RMPG.DEST_MAP      = 10 -- a portal to another map: whoever goes in waits for the rest, then the map changes (sv_maptravel.lua)
RMPG.DEST_BITS     = 4 -- bits the mode takes in the "rmpg_dest" message

-- Portal gun models: 0 classic, 1 Prime, 2 Evil Morty's, 3 the prototype, 4 the kids' toy, 5 and 6 from Rick's cabinet
RMPG.GUN_COUNT = 7

-- Who may use a saved location: only you, the players you trust, or everyone
RMPG.SHARE_PRIVATE = 0
RMPG.SHARE_TRUSTED = 1
RMPG.SHARE_PUBLIC  = 2

-- Energy shield effects sent to clients
RMPG.SHIELD_HIT   = 0
RMPG.SHIELD_BREAK = 1
RMPG.SHIELD_UP    = 2

-- Mr. Meeseeks jobs
RMPG.MR_KILL     = 1 -- find and kill a target
RMPG.MR_FINDPROP = 2 -- find a prop of a model and bring it
RMPG.MR_MAKE     = 3 -- make a prop, a weapon, an entity or an NPC
RMPG.MR_FINDENT  = 4 -- find an entity of a class (brings small ones, leads you to the rest)
RMPG.MR_PROTECT  = 5 -- follow a player and fight whoever attacks them
RMPG.MR_GUARD    = 6 -- guard a spot
RMPG.MR_HEAL     = 7 -- patch you up
RMPG.MR_DISTRACT = 8 -- draw enemies away

-- Colour presets shown in the fluid tab
RMPG.PRESETS = {
	{ 84, 255, 64 },   -- classic C-137 green
	{ 40, 200, 255 },  -- cyan
	{ 70, 110, 255 },  -- blue
	{ 170, 80, 255 },  -- purple
	{ 255, 70, 200 },  -- pink
	{ 255, 60, 60 },   -- red
	{ 255, 150, 30 },  -- orange
	{ 255, 235, 60 },  -- yellow
	{ 240, 245, 255 }, -- white
}

local SV = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY)

RMPG.CV = {
	charges   = CreateConVar("rmpg_charges", "30", SV, "Portal gun: shots per fluid flask", 1, 999),
	flasks    = CreateConVar("rmpg_start_flasks", "3", SV, "Portal gun: spare flasks given with the gun", 0, 99),
	infinite  = CreateConVar("rmpg_infinite_flasks", "0", SV, "Portal gun: reloading never uses up flasks", 0, 1),
	lifetime  = CreateConVar("rmpg_portal_lifetime", "30", SV, "Portal gun: seconds a portal stays open (0 = forever)", 0, 3600),
	maxPairs  = CreateConVar("rmpg_max_pairs", "2", SV, "Portal gun: portal pairs per player", 1, 10),
	size      = CreateConVar("rmpg_portal_size", "64", SV, "Portal gun: half size of the portal texture in units", 32, 160),
	findDist  = CreateConVar("rmpg_find_distance", "400", SV, "Portal gun: distance from the target player (~10 steps)", 100, 2000),
	sdRadius  = CreateConVar("rmpg_sd_radius", "5", SV, "Portal gun: self-destruct radius in metres", 1, 50),
	sdCore    = CreateConVar("rmpg_sd_core_radius", "12", SV, "Portal gun: self-destruct radius with the energy core, metres", 1, 80),
	sdOwner   = CreateConVar("rmpg_sd_hurt_owner", "1", SV, "Portal gun: self-destruct can vaporise its owner", 0, 1),
	coreMenu  = CreateConVar("rmpg_core_from_menu", "1", SV, "Portal gun: allow installing the energy core from the menu", 0, 1),
	tpProps   = CreateConVar("rmpg_teleport_props", "1", SV, "Portal gun: portals carry physics props", 0, 1),
	tpNPCs    = CreateConVar("rmpg_teleport_npcs", "1", SV, "Portal gun: portals carry NPCs", 0, 1),
	tpCars    = CreateConVar("rmpg_teleport_vehicles", "1", SV, "Portal gun: portals carry vehicles", 0, 1),
	npcFollow = CreateConVar("rmpg_npc_follow", "1", SV, "Portal gun: NPCs follow players through portals", 0, 1),
	fireDelay = CreateConVar("rmpg_fire_cooldown", "0.3", SV, "Portal gun: seconds between shots", 0.1, 5),
	bombTimer = CreateConVar("rmpg_bomb_timer", "3", SV, "Prime bomb: seconds from the detonator click to the blast", 1, 30),
	bombKill  = CreateConVar("rmpg_bomb_kill_radius", "2.75", SV, "Prime bomb: everything this close is disintegrated, metres", 0.5, 20),
	bombPull  = CreateConVar("rmpg_bomb_pull_radius", "4", SV, "Prime bomb: pulls things this close toward itself while counting down, metres", 0, 30),
	bombBlast = CreateConVar("rmpg_bomb_blast_radius", "10", SV, "Prime bomb: knock-back and 30-40% damage radius, metres", 1, 60),
	bombNear  = CreateConVar("rmpg_bomb_damage_near", "40", SV, "Prime bomb: percent of max health taken within 5 m (outside the disintegration radius)", 0, 100),
	bombFar   = CreateConVar("rmpg_bomb_damage_far", "30", SV, "Prime bomb: percent of max health taken at the edge of the blast", 0, 100),
	shieldRecover = CreateConVar("rmpg_shield_recover", "90", SV, "Energy shield: seconds a cracked shield needs to come back", 5, 600),
	shieldRegen   = CreateConVar("rmpg_shield_regen", "8", SV, "Energy shield: percent restored per second after a hit", 0, 100),
	shieldKeep    = CreateConVar("rmpg_shield_keep", "1", SV, "Energy shield: the implant survives death", 0, 1),
	shieldCap     = CreateConVar("rmpg_shield_capacity", "250", SV, "Energy shield: damage a full shield holds; a hit this big always cracks it", 20, 5000),
	shieldDelay   = CreateConVar("rmpg_shield_delay", "2", SV, "Energy shield: seconds before it starts recharging after a hit (bigger hits wait longer)", 0, 60),
	shieldRocket  = CreateConVar("rmpg_shield_rocket", "40", SV, "Energy shield: percent a rocket takes at most", 0, 100),
	shieldBolt    = CreateConVar("rmpg_shield_crossbow", "30", SV, "Energy shield: percent a crossbow bolt takes", 0, 100),
	mrMax         = CreateConVar("rmpg_mr_max", "4", SV, "Mr. Meeseeks: how many one player can have at once", 1, 30),
	mrHealth      = CreateConVar("rmpg_mr_health", "60", SV, "Mr. Meeseeks: health", 1, 2000),
	mrDamage      = CreateConVar("rmpg_mr_damage", "12", SV, "Mr. Meeseeks: punch damage", 0, 500),
	mrSpeed       = CreateConVar("rmpg_mr_speed", "260", SV, "Mr. Meeseeks: running speed", 50, 800),
	mrLife        = CreateConVar("rmpg_mr_life", "300", SV, "Mr. Meeseeks: seconds an open-ended job (protect, guard, distract) lasts", 20, 3600),
	mrCraft       = CreateConVar("rmpg_mr_craft_time", "4", SV, "Mr. Meeseeks: seconds to make a prop (weapons take 1.5x)", 1, 60),
	mrWeapons     = CreateConVar("rmpg_mr_make_weapons", "1", SV, "Mr. Meeseeks: may make weapons", 0, 1),
	mrMakeEnts    = CreateConVar("rmpg_mr_make_ents", "1", SV, "Mr. Meeseeks: may make entities from the spawn menu", 0, 1),
	mrMakeNPCs    = CreateConVar("rmpg_mr_make_npcs", "1", SV, "Mr. Meeseeks: may make NPCs (experimental)", 0, 1),
	mrBanJobs     = CreateConVar("rmpg_mr_ban_jobs", "", SV, "Mr. Meeseeks: numbers of the jobs he will not take, comma separated"),
	mrBanProps    = CreateConVar("rmpg_mr_ban_props", "", SV, "Mr. Meeseeks: comma separated parts of model paths he will not make"),
	mrBanWeapons  = CreateConVar("rmpg_mr_ban_weapons", "", SV, "Mr. Meeseeks: comma separated parts of weapon classes he will not make"),
	mrBanEnts     = CreateConVar("rmpg_mr_ban_ents", "", SV, "Mr. Meeseeks: comma separated parts of entity classes he will not make"),
	mrBanNPCs     = CreateConVar("rmpg_mr_ban_npcs", "", SV, "Mr. Meeseeks: comma separated parts of NPC classes he will not make"),
	mrPvP         = CreateConVar("rmpg_mr_pvp", "1", SV, "Mr. Meeseeks: may fight other players", 0, 1),
	mrFrenzy      = CreateConVar("rmpg_mr_frenzy", "1", SV, "Mr. Meeseeks: one that cannot finish its job for too long goes crazy and attacks its owner", 0, 1),
	mrFrenzyTime  = CreateConVar("rmpg_mr_frenzy_time", "120", SV, "Mr. Meeseeks: seconds of failing before it goes crazy", 20, 1800),
	freezeTime    = CreateConVar("rmpg_freeze_time", "25", SV, "Freezing: seconds until a frozen player or NPC dies unless thawed", 3, 600),
	freezeBeam    = CreateConVar("rmpg_freeze_beam", "1.2", SV, "Freezing: seconds of the freeze ray to freeze something", 0.1, 20),
	freezeHits    = CreateConVar("rmpg_freeze_knife_hits", "2", SV, "Freezing: knife slashes to freeze (a stab freezes at once)", 1, 20),
	freezeShatter = CreateConVar("rmpg_freeze_shatter", "1", SV, "Freezing: a fall or a hard hit shatters frozen things", 0, 1),
	freezePlayers = CreateConVar("rmpg_freeze_players", "1", SV, "Freezing: players can be frozen", 0, 1),
	freezeProps   = CreateConVar("rmpg_freeze_props", "1", SV, "Freezing: props can be frozen", 0, 1),
	freezeHP      = CreateConVar("rmpg_freeze_statue_hp", "50", SV, "Freezing: damage an ice statue takes before it shatters", 1, 2000),
	phxFlesh      = CreateConVar("rmpg_phx_flesh_time", "10", SV, "Operation Phoenix: seconds the meat body takes to form", 1, 300),
	phxSkin       = CreateConVar("rmpg_phx_skin_time", "30", SV, "Operation Phoenix: seconds for the skin to cover it", 1, 600),
	phxAuto       = CreateConVar("rmpg_phx_auto", "1", SV, "Operation Phoenix: a ready body takes its consciousness automatically when that player dies", 0, 1),
	phxBlacklist  = CreateConVar("rmpg_phx_blacklist", "", SV, "Operation Phoenix: comma separated parts of model paths whose DNA cannot be taken"),
	phxAnyMind    = CreateConVar("rmpg_phx_any_mind", "1", SV, "Operation Phoenix: any player's consciousness can be chosen for a body (off: only your own)", 0, 1),
	phxMinScale   = CreateConVar("rmpg_phx_min_scale", "0.5", SV, "Operation Phoenix: the smallest body size (a child), part of the normal size", 0.3, 1),
	phxTankHP     = CreateConVar("rmpg_phx_tank_health", "150", SV, "Operation Phoenix: damage the tank glass takes before it breaks", 1, 5000),
	pillDelay     = CreateConVar("rmpg_pill_delay", "3", SV, "Dramatic pills: seconds after swallowing before you start to fade", 0, 30),
	pillFade      = CreateConVar("rmpg_pill_fade", "3", SV, "Dramatic pills: seconds of fading out", 0.5, 30),
	nbTimer       = CreateConVar("rmpg_neutrino_timer", "10", SV, "Neutrino bomb: seconds of countdown", 1, 120),
	nbRadius      = CreateConVar("rmpg_neutrino_radius", "120", SV, "Neutrino bomb: blast radius in metres", 10, 1000),
	nbKill        = CreateConVar("rmpg_neutrino_kill_radius", "20", SV, "Neutrino bomb: everything this close is torn apart, metres", 1, 300),
	nbDamage      = CreateConVar("rmpg_neutrino_damage", "300", SV, "Neutrino bomb: shock wave damage just outside the tearing radius (less further out)", 0, 5000),
	nbHole        = CreateConVar("rmpg_neutrino_hole_time", "12", SV, "Neutrino bomb: seconds the black hole lasts (0 = none)", 0, 120),
	nbHoleRadius  = CreateConVar("rmpg_neutrino_hole_radius", "25", SV, "Neutrino bomb: the black hole pulls things this close, metres", 2, 200),
	nbMeteors     = CreateConVar("rmpg_neutrino_meteors", "1", SV, "Neutrino bomb: the thrown-up ground falls as burning meteorites", 0, 1),
	laserShots    = CreateConVar("rmpg_laser_shots", "18", SV, "Laser gun: shots in a row before it overheats", 1, 200),
	laserCool     = CreateConVar("rmpg_laser_cool", "2.5", SV, "Laser gun: seconds to cool down after overheating", 0.5, 30),
	laserDamage   = CreateConVar("rmpg_laser_damage", "20", SV, "Laser gun: damage per shot", 0, 1000),
	laserChargeT  = CreateConVar("rmpg_laser_charge_time", "2", SV, "Laser gun: seconds of holding RMB for a full charge", 0.3, 10),
	laserChargeD  = CreateConVar("rmpg_laser_charge_damage", "200", SV, "Laser gun: damage of a fully charged shot", 0, 2000),
	laserKick     = CreateConVar("rmpg_laser_charge_kick", "500", SV, "Laser gun: how hard a full shot throws you back", 0, 3000),
	laserPierce   = CreateConVar("rmpg_laser_charge_pierce", "1", SV, "Laser gun: charged shots go through walls and bodies and bounce off at a glancing angle", 0, 1),
	laserOverload = CreateConVar("rmpg_laser_overload", "7", SV, "Laser gun: seconds it can be held at full charge before it overloads, 0 = never", 0, 60),
	laserOverDmg  = CreateConVar("rmpg_laser_overload_damage", "35", SV, "Laser gun: damage of an overload to the one holding it", 0, 500),
	wormDamage    = CreateConVar("rmpg_worm_damage", "8", SV, "Brain worm: base bite damage (bigger worms bite and crush harder)", 0, 500),
	wormHeadGrow  = CreateConVar("rmpg_worm_headgrow", "0.5", SV, "Brain worm: how much it grows a minute inside a head, in players (1 = as tall as a player)", 0.05, 10),
	wormGrowOut   = CreateConVar("rmpg_worm_growout", "0.1", SV, "Brain worm: how much it grows a minute outside, in players (eating adds more)", 0, 10),
	wormMax       = CreateConVar("rmpg_worm_maxsize", "2", SV, "Brain worm: the biggest it gets, in players; full grown in a head it bursts out", 0.5, 4),
	patchXray     = CreateConVar("rmpg_patch_xray_range", "3000", SV, "Eyepatch: how far the X-ray sees enemies through walls", 200, 20000),
	patchHack     = CreateConVar("rmpg_patch_hack", "1", SV, "Eyepatch: hacking allowed", 0, 1),
	patchHackRange = CreateConVar("rmpg_patch_hack_range", "4000", SV, "Eyepatch: how far mechanisms can be hacked", 100, 30000),
	patchHackCool = CreateConVar("rmpg_patch_hack_cool", "1", SV, "Eyepatch: seconds between hacks", 0, 60),
	patchAim      = CreateConVar("rmpg_patch_aim", "1", SV, "Eyepatch: auto-aim allowed", 0, 1),
	patchAimTime  = CreateConVar("rmpg_patch_aim_time", "15", SV, "Eyepatch: seconds the auto-aim lasts", 1, 300),
	patchAimCool  = CreateConVar("rmpg_patch_aim_cool", "30", SV, "Eyepatch: seconds before the auto-aim can be used again", 0, 600),
	wormEnter     = CreateConVar("rmpg_worm_enter", "3", SV, "Brain worm: seconds a small worm on a head needs to get inside (0 = it never does)", 0, 60),
	wormMerge     = CreateConVar("rmpg_worm_merge", "1", SV, "Brain worm (experimental): worms that meet grow together into one", 0, 1),
	wormSplit     = CreateConVar("rmpg_worm_split", "1", SV, "Brain worm (experimental): a big worm with several people around tears itself up to go after them all", 0, 1),
	wormEatProps  = CreateConVar("rmpg_worm_eat_props", "1", SV, "Brain worm: eats loose props that fit into its mouth", 0, 1),
	wormEatPeople = CreateConVar("rmpg_worm_eat_people", "1", SV, "Brain worm: a big one swallows people whole", 0, 1),
	wormChunks    = CreateConVar("rmpg_worm_chunks", "1", SV, "Brain worm: leaves bloody pieces when it is killed", 0, 1),
	wormChunkTime = CreateConVar("rmpg_worm_chunk_time", "60", SV, "Brain worm: seconds its pieces stay", 5, 600),
	wormNest      = CreateConVar("rmpg_worm_nest", "1", SV, "Brain worm: worms build lairs and breed there", 0, 1),
	wormNestMax   = CreateConVar("rmpg_worm_nest_max", "2", SV, "Brain worm: lairs on the map at once", 1, 8),
	wormColony    = CreateConVar("rmpg_worm_colony_max", "8", SV, "Brain worm: how many worms one lair holds", 2, 30),
	wormBudTime   = CreateConVar("rmpg_worm_bud_time", "40", SV, "Brain worm: seconds between the queen's first workers", 5, 600),
	wormEggTime   = CreateConVar("rmpg_worm_egg_time", "30", SV, "Brain worm: seconds eggs take to hatch", 5, 600),
	wormNestHP    = CreateConVar("rmpg_worm_nest_health", "400", SV, "Brain worm: damage a lair takes before it is destroyed", 10, 5000),
	wormSlime     = CreateConVar("rmpg_worm_slime", "1", SV, "Brain worm: leaves a trail of slime where it crawls", 0, 1),
	armRadius     = CreateConVar("rmpg_implant_laser_radius", "20", SV, "Laser arm: radius of the beam (a crate is about 40 wide)", 2, 200),
	armRange      = CreateConVar("rmpg_implant_laser_range", "6000", SV, "Laser arm: how far the beam reaches", 100, 30000),
	armTime       = CreateConVar("rmpg_implant_laser_burst", "2", SV, "Laser arm: seconds one burst burns", 0.5, 30),
	armCool       = CreateConVar("rmpg_implant_laser_recharge", "15", SV, "Laser arm: seconds to recharge after a burst", 0.5, 300),
	armPvP        = CreateConVar("rmpg_implant_laser_pvp", "1", SV, "Laser arm: disintegrates other players too", 0, 1),
	armKeep       = CreateConVar("rmpg_implant_laser_keep", "1", SV, "Laser arm: the implant stays after death", 0, 1),
	armShotPct    = CreateConVar("rmpg_implant_laser_shot", "40", SV, "Akira laser: a normal shot takes this many percent of the target's full health", 1, 100),
	armShotDelay  = CreateConVar("rmpg_implant_laser_shot_delay", "0.45", SV, "Akira laser: seconds between normal shots", 0.1, 5),
	tentRange     = CreateConVar("rmpg_implant_tentacle_range", "2500", SV, "Tentacle: how far it reaches", 200, 10000),
	tentPull      = CreateConVar("rmpg_implant_tentacle_pull", "1500", SV, "Tentacle: how hard the hook pulls you", 200, 5000),
	tentCatch     = CreateConVar("rmpg_implant_tentacle_catch", "900", SV, "Tentacle: how far it reaches to catch a fall", 100, 4000),
	tentFall      = CreateConVar("rmpg_implant_tentacle_fall", "750", SV, "Tentacle: falling speed at which it catches you", 300, 3000),
	tentThrow     = CreateConVar("rmpg_implant_tentacle_throw", "800", SV, "Tentacle: how high Jump throws you when hanging", 100, 3000),
	tentSlide     = CreateConVar("rmpg_implant_tentacle_slide", "260", SV, "Tentacle: speed of sliding down with Ctrl", 50, 1500),
	tentPvP       = CreateConVar("rmpg_implant_tentacle_pvp", "1", SV, "Tentacle: can take hold of other players", 0, 1),
	tentKeep      = CreateConVar("rmpg_implant_tentacle_keep", "1", SV, "Tentacle: the implant stays after death", 0, 1),
	primeRegen    = CreateConVar("rmpg_implant_prime_regen", "5", SV, "Rick Prime chip: health per second that comes back by itself", 0, 100),
	primeHP       = CreateConVar("rmpg_implant_prime_hp", "250", SV, "Rick Prime chip: health after a revival", 1, 1000),
	primeArmor    = CreateConVar("rmpg_implant_prime_armor", "50", SV, "Rick Prime chip: armour after a revival", 0, 255),
	primeCool     = CreateConVar("rmpg_implant_prime_cool", "90", SV, "Rick Prime chip: seconds before it can revive again", 1, 3600),
	primeLimbs    = CreateConVar("rmpg_implant_prime_limbs", "1", SV, "Rick Prime chip: blasts tear off arms and legs, which come back", 0, 1),
	primeClones   = CreateConVar("rmpg_implant_prime_clones", "3", SV, "Rick Prime chip: bodies of yourself at most", 0, 10),
	primeGuard    = CreateConVar("rmpg_implant_prime_guard", "1", SV, "Rick Prime chip: your bodies follow you and shoot your enemies", 0, 1),
	primeDamage   = CreateConVar("rmpg_implant_prime_damage", "8", SV, "Rick Prime chip: damage of a body's pistol shot", 0, 500),
	primeKeep     = CreateConVar("rmpg_implant_prime_keep", "1", SV, "Rick Prime chip: stays after death", 0, 1),
	trapTime      = CreateConVar("rmpg_portal_trap_time", "10", SV, "Portal trap: seconds it stays open", 1, 120),
	trapPeople    = CreateConVar("rmpg_portal_trap_people", "1", SV, "Portal trap: tears apart players, NPCs and Lambda Players", 0, 1),
	chainMax      = CreateConVar("rmpg_chain_max", "6", SV, "Chained portals: how many one player can have at once (the oldest closes)", 2, 30),
	mapEveryone   = CreateConVar("rmpg_maptravel_everyone", "0", SV, "Portals to other maps: 0 = only superadmins can open them, 1 = everyone", 0, 1),
	mapWait       = CreateConVar("rmpg_maptravel_wait", "30", SV, "Portals to other maps: seconds the others have to go in after the one who opened it", 5, 300),
	cloneBots     = CreateConVar("rmpg_clone_bots", "1", SV, "Visitors: come as real player bots when the server has a free slot", 0, 1),
	cloneLambda   = CreateConVar("rmpg_clone_lambda", "1", SV, "Visitors: with the Lambda Players addon installed they come as Lambda Players", 0, 1),
	evacCharges   = CreateConVar("rmpg_evac_charges", "45", SV, "Evacuation: hits it takes before it needs to recharge", 1, 1000),
	evacRegen     = CreateConVar("rmpg_evac_regen", "80", SV, "Evacuation: seconds to recharge once it is spent", 0, 3600),
	evacMin       = CreateConVar("rmpg_evac_min", "55", SV, "Evacuation: shortest jump (55 is about a metre)", 20, 500),
	evacMax       = CreateConVar("rmpg_evac_max", "110", SV, "Evacuation: longest jump (110 is about two metres)", 20, 1000),
	evacBlast     = CreateConVar("rmpg_evac_blast", "1", SV, "Evacuation: also jumps out of explosions", 0, 1),
	evacBlastCost = CreateConVar("rmpg_evac_blast_cost", "5", SV, "Evacuation: how many hits an explosion counts for", 1, 100),
	evacKeep      = CreateConVar("rmpg_evac_keep", "1", SV, "Evacuation: the implant stays after death", 0, 1),
	cloneChance   = CreateConVar("rmpg_clone_chance", "0.25", SV, "Clones: percent chance a minute that a player gets a visit from their copy (0 = never)", 0, 100),
	cloneMax      = CreateConVar("rmpg_clone_max", "5", SV, "Clones: how many can be here at once", 1, 20),
	cloneDamage   = CreateConVar("rmpg_clone_damage", "8", SV, "Clones: damage of a hostile copy's shot", 0, 500),
	cloneHostile  = CreateConVar("rmpg_clone_hostile", "50", SV, "Clones: percent chance a copy comes to fight (else it brings a present)", 0, 100),
	droneMax      = CreateConVar("rmpg_drone_max", "6", SV, "Prime drones: how many one player can switch on", 1, 50),
	droneDamage   = CreateConVar("rmpg_drone_damage", "8", SV, "Prime drones: laser damage per shot", 0, 500),
	droneRate     = CreateConVar("rmpg_drone_firerate", "0.4", SV, "Prime drones: seconds between shots", 0.05, 5),
	droneRange    = CreateConVar("rmpg_drone_range", "1500", SV, "Prime drones: how far they look for targets", 200, 6000),
	droneHealth   = CreateConVar("rmpg_drone_health", "150", SV, "Prime drones: health", 1, 5000),
	dronePvP      = CreateConVar("rmpg_drone_pvp", "1", SV, "Prime drones: may shoot players who are not friends", 0, 1),
}

-- Server settings that a superadmin may edit from the menu: name -> kind
RMPG.SERVER_SETTINGS = {
	{ "rmpg_fire_cooldown", "num", 0.1, 3, 1 },
	{ "rmpg_portal_lifetime", "num", 0, 300, 0 },
	{ "rmpg_max_pairs", "num", 1, 10, 0 },
	{ "rmpg_charges", "num", 1, 200, 0 },
	{ "rmpg_start_flasks", "num", 0, 20, 0 },
	{ "rmpg_infinite_flasks", "bool" },
	{ "rmpg_find_distance", "num", 100, 1500, 0 },
	{ "rmpg_portal_size", "num", 32, 160, 0 },
	{ "rmpg_sd_radius", "num", 1, 30, 0 },
	{ "rmpg_sd_core_radius", "num", 1, 60, 0 },
	{ "rmpg_sd_hurt_owner", "bool" },
	{ "rmpg_core_from_menu", "bool" },
	{ "rmpg_teleport_props", "bool" },
	{ "rmpg_teleport_npcs", "bool" },
	{ "rmpg_teleport_vehicles", "bool" },
	{ "rmpg_npc_follow", "bool" },
	{ "rmpg_bomb_timer", "num", 1, 10, 1 },
	{ "rmpg_bomb_kill_radius", "num", 0.5, 10, 2 },
	{ "rmpg_bomb_pull_radius", "num", 0, 15, 1 },
	{ "rmpg_bomb_blast_radius", "num", 1, 30, 0 },
	{ "rmpg_bomb_damage_near", "num", 0, 100, 0 },
	{ "rmpg_bomb_damage_far", "num", 0, 100, 0 },
	{ "rmpg_shield_capacity", "num", 20, 2000, 0 },
	{ "rmpg_shield_regen", "num", 0, 50, 0 },
	{ "rmpg_shield_delay", "num", 0, 20, 1 },
	{ "rmpg_shield_recover", "num", 10, 300, 0 },
	{ "rmpg_shield_rocket", "num", 0, 100, 0 },
	{ "rmpg_shield_crossbow", "num", 0, 100, 0 },
	{ "rmpg_shield_keep", "bool" },
	{ "rmpg_mr_max", "num", 1, 20, 0 },
	{ "rmpg_mr_health", "num", 1, 500, 0 },
	{ "rmpg_mr_damage", "num", 0, 100, 0 },
	{ "rmpg_mr_speed", "num", 50, 600, 0 },
	{ "rmpg_mr_life", "num", 20, 1200, 0 },
	{ "rmpg_mr_craft_time", "num", 1, 20, 0 },
	{ "rmpg_mr_make_weapons", "bool" },
	{ "rmpg_mr_make_ents", "bool" },
	{ "rmpg_mr_make_npcs", "bool" },
	{ "rmpg_mr_pvp", "bool" },
	{ "rmpg_mr_frenzy", "bool" },
	{ "rmpg_mr_frenzy_time", "num", 20, 600, 0 },
	{ "rmpg_freeze_time", "num", 3, 120, 0 },
	{ "rmpg_freeze_beam", "num", 0.1, 5, 1 },
	{ "rmpg_freeze_knife_hits", "num", 1, 10, 0 },
	{ "rmpg_freeze_shatter", "bool" },
	{ "rmpg_freeze_players", "bool" },
	{ "rmpg_freeze_props", "bool" },
	{ "rmpg_freeze_statue_hp", "num", 5, 300, 0 },
	{ "rmpg_phx_flesh_time", "num", 1, 60, 0 },
	{ "rmpg_phx_skin_time", "num", 1, 120, 0 },
	{ "rmpg_phx_auto", "bool" },
	{ "rmpg_phx_any_mind", "bool" },
	{ "rmpg_phx_min_scale", "num", 0.3, 1, 2 },
	{ "rmpg_phx_tank_health", "num", 10, 1000, 0 },
	{ "rmpg_pill_delay", "num", 0, 10, 1 },
	{ "rmpg_pill_fade", "num", 0.5, 10, 1 },
	{ "rmpg_neutrino_timer", "num", 3, 60, 0 },
	{ "rmpg_neutrino_radius", "num", 20, 400, 0 },
	{ "rmpg_neutrino_kill_radius", "num", 2, 100, 0 },
	{ "rmpg_neutrino_damage", "num", 0, 1000, 0 },
	{ "rmpg_neutrino_hole_time", "num", 0, 60, 0 },
	{ "rmpg_neutrino_hole_radius", "num", 5, 100, 0 },
	{ "rmpg_neutrino_meteors", "bool" },
	{ "rmpg_laser_shots", "num", 1, 60, 0 },
	{ "rmpg_laser_cool", "num", 0.5, 10, 1 },
	{ "rmpg_laser_damage", "num", 0, 200, 0 },
	{ "rmpg_laser_charge_time", "num", 0.3, 10, 1 },
	{ "rmpg_laser_charge_damage", "num", 0, 1000, 0 },
	{ "rmpg_laser_charge_kick", "num", 0, 2000, 0 },
	{ "rmpg_laser_charge_pierce", "bool" },
	{ "rmpg_laser_overload", "num", 0, 30, 0 },
	{ "rmpg_laser_overload_damage", "num", 0, 200, 0 },
	{ "rmpg_worm_damage", "num", 0, 100, 0 },
	{ "rmpg_worm_headgrow", "num", 0.05, 3, 2 },
	{ "rmpg_worm_growout", "num", 0, 1, 2 },
	{ "rmpg_worm_maxsize", "num", 0.5, 4, 1 },
	{ "rmpg_worm_enter", "num", 0, 15, 1 },
	{ "rmpg_worm_merge", "bool" },
	{ "rmpg_worm_split", "bool" },
	{ "rmpg_worm_eat_props", "bool" },
	{ "rmpg_worm_eat_people", "bool" },
	{ "rmpg_worm_chunks", "bool" },
	{ "rmpg_worm_chunk_time", "num", 5, 300, 0 },
	{ "rmpg_worm_nest", "bool" },
	{ "rmpg_worm_nest_max", "num", 1, 8, 0 },
	{ "rmpg_worm_colony_max", "num", 2, 30, 0 },
	{ "rmpg_worm_bud_time", "num", 5, 300, 0 },
	{ "rmpg_worm_egg_time", "num", 5, 300, 0 },
	{ "rmpg_worm_nest_health", "num", 10, 2000, 0 },
	{ "rmpg_worm_slime", "bool" },
	{ "rmpg_clone_lambda", "bool" },
	{ "rmpg_implant_laser_radius", "num", 5, 100, 0 },
	{ "rmpg_implant_laser_range", "num", 500, 15000, 0 },
	{ "rmpg_implant_laser_burst", "num", 0.5, 10, 1 },
	{ "rmpg_implant_laser_recharge", "num", 1, 60, 1 },
	{ "rmpg_implant_laser_pvp", "bool" },
	{ "rmpg_implant_laser_keep", "bool" },
	{ "rmpg_implant_laser_shot", "num", 5, 100, 0 },
	{ "rmpg_implant_laser_shot_delay", "num", 0.1, 2, 2 },
	{ "rmpg_implant_tentacle_range", "num", 200, 6000, 0 },
	{ "rmpg_implant_tentacle_pull", "num", 200, 4000, 0 },
	{ "rmpg_implant_tentacle_catch", "num", 100, 3000, 0 },
	{ "rmpg_implant_tentacle_fall", "num", 300, 2000, 0 },
	{ "rmpg_implant_tentacle_throw", "num", 100, 2000, 0 },
	{ "rmpg_implant_tentacle_slide", "num", 50, 1000, 0 },
	{ "rmpg_implant_tentacle_pvp", "bool" },
	{ "rmpg_implant_tentacle_keep", "bool" },
	{ "rmpg_implant_prime_regen", "num", 0, 50, 0 },
	{ "rmpg_implant_prime_hp", "num", 1, 500, 0 },
	{ "rmpg_implant_prime_armor", "num", 0, 255, 0 },
	{ "rmpg_implant_prime_cool", "num", 5, 600, 0 },
	{ "rmpg_implant_prime_limbs", "bool" },
	{ "rmpg_implant_prime_clones", "num", 0, 10, 0 },
	{ "rmpg_implant_prime_guard", "bool" },
	{ "rmpg_implant_prime_damage", "num", 0, 100, 0 },
	{ "rmpg_implant_prime_keep", "bool" },
	{ "rmpg_portal_trap_time", "num", 1, 60, 0 },
	{ "rmpg_portal_trap_people", "bool" },
	{ "rmpg_chain_max", "num", 2, 20, 0 },
	{ "rmpg_maptravel_everyone", "bool" },
	{ "rmpg_maptravel_wait", "num", 5, 120, 0 },
	{ "rmpg_clone_bots", "bool" },
	{ "rmpg_patch_xray_range", "num", 200, 10000, 0 },
	{ "rmpg_patch_hack", "bool" },
	{ "rmpg_patch_hack_range", "num", 100, 15000, 0 },
	{ "rmpg_patch_hack_cool", "num", 0, 10, 1 },
	{ "rmpg_patch_aim", "bool" },
	{ "rmpg_patch_aim_time", "num", 1, 60, 0 },
	{ "rmpg_patch_aim_cool", "num", 0, 120, 0 },
	{ "rmpg_evac_charges", "num", 1, 200, 0 },
	{ "rmpg_evac_regen", "num", 0, 300, 0 },
	{ "rmpg_evac_min", "num", 20, 300, 0 },
	{ "rmpg_evac_max", "num", 20, 400, 0 },
	{ "rmpg_evac_blast", "bool" },
	{ "rmpg_evac_blast_cost", "num", 1, 45, 0 },
	{ "rmpg_evac_keep", "bool" },
	{ "rmpg_clone_chance", "num", 0, 10, 2 },
	{ "rmpg_clone_max", "num", 1, 10, 0 },
	{ "rmpg_clone_damage", "num", 0, 100, 0 },
	{ "rmpg_clone_hostile", "num", 0, 100, 0 },
	{ "rmpg_drone_max", "num", 1, 20, 0 },
	{ "rmpg_drone_damage", "num", 0, 100, 0 },
	{ "rmpg_drone_firerate", "num", 0.1, 2, 2 },
	{ "rmpg_drone_range", "num", 300, 4000, 0 },
	{ "rmpg_drone_health", "num", 10, 1000, 0 },
	{ "rmpg_drone_pvp", "bool" },
}

-- Settings of what is still being finished stay hidden until its flag is on (see rmpg_autorun.lua)
local REGEN = { rmpg_implant_prime_limbs = true }
for i = #RMPG.SERVER_SETTINGS, 1, -1 do
	local n = RMPG.SERVER_SETTINGS[i][1]
	if (not RMPG.WIP and (string.find(n, "^rmpg_drone_") or string.find(n, "^rmpg_freeze_")))
		or (not RMPG.WIP_PRIME_LIMBS and REGEN[n]) then
		table.remove(RMPG.SERVER_SETTINGS, i)
	end
end

-- Rebindable client actions: id, convar, default button code
RMPG.BINDS = {
	{ "radial", "rmpg_bind_radial", MOUSE_MIDDLE },
	{ "quick", "rmpg_bind_quick", KEY_B },
	{ "close", "rmpg_bind_close", KEY_G },
	{ "vertical", "rmpg_bind_vertical", KEY_N },
	{ "nextmode", "rmpg_bind_nextmode", KEY_NONE },
	{ "menu", "rmpg_bind_menu", KEY_NONE },
	{ "reload", "rmpg_bind_reload", KEY_NONE },
	{ "selfdestruct", "rmpg_bind_selfdestruct", KEY_NONE },
}

function RMPG.MaxCharges() return RMPG.CV.charges:GetInt() end
function RMPG.Radius() return RMPG.CV.size:GetFloat() end

if CLIENT then
	RMPG.CL = {
		lang      = CreateClientConVar("rmpg_lang", "auto", true, false, "Portal gun language: auto / ru / en"),
		vertical  = CreateClientConVar("rmpg_vertical_front", "0", true, true, "Place an upright portal in front of you"),
		-- first-person placement; the defaults are the tuned factory position
		vmScale   = CreateClientConVar("rmpg_vm_scale", "0.92", true, false),
		vmX       = CreateClientConVar("rmpg_vm_x", "0.3", true, false),
		vmY       = CreateClientConVar("rmpg_vm_y", "1.4", true, false),
		vmZ       = CreateClientConVar("rmpg_vm_z", "-1.8", true, false),
		vmPitch   = CreateClientConVar("rmpg_vm_pitch", "0", true, false),
		vmYaw     = CreateClientConVar("rmpg_vm_yaw", "0", true, false),
		vmRoll    = CreateClientConVar("rmpg_vm_roll", "0", true, false),
		r         = CreateClientConVar("rmpg_fluid_r", "84", true, true),
		g         = CreateClientConVar("rmpg_fluid_g", "255", true, true),
		b         = CreateClientConVar("rmpg_fluid_b", "64", true, true),
		hud       = CreateClientConVar("rmpg_hud", "1", true, false),
		preview   = CreateClientConVar("rmpg_preview", "1", true, false),
		outline   = CreateClientConVar("rmpg_toon_outline", "1", true, false),
		hands     = CreateClientConVar("rmpg_hands", "1", true, false),
		particles = CreateClientConVar("rmpg_particles", "1", true, false),
		uisounds  = CreateClientConVar("rmpg_ui_sounds", "1", true, false),
		model     = CreateClientConVar("rmpg_model", "0", true, true, "Portal gun model: 0 classic, 1 prime, 2 Evil Morty, 3 prototype, 4 kids, 5 cabinet vial, 6 cabinet antenna"),
		bodyOn    = CreateClientConVar("rmpg_body_custom", "0", true, true, "Portal gun: 1 = the body in your own colour, 0 = the model's own"),
		bodyR     = CreateClientConVar("rmpg_body_r", "236", true, true),
		bodyG     = CreateClientConVar("rmpg_body_g", "196", true, true),
		bodyB     = CreateClientConVar("rmpg_body_b", "44", true, true),
	}
	RMPG.CL.binds = {}
	for _, b in ipairs(RMPG.BINDS) do
		RMPG.CL.binds[b[1]] = CreateClientConVar(b[2], tostring(b[3]), true, false)
	end

	function RMPG.LocalColor()
		return Vector(RMPG.CL.r:GetInt(), RMPG.CL.g:GetInt(), RMPG.CL.b:GetInt())
	end

	-- The body colour you picked, or nil for the model's own
	function RMPG.LocalBody()
		if not RMPG.CL.bodyOn:GetBool() then return nil end
		return Vector(math.max(RMPG.CL.bodyR:GetInt(), 1), math.max(RMPG.CL.bodyG:GetInt(), 1), math.max(RMPG.CL.bodyB:GetInt(), 1))
	end
end
