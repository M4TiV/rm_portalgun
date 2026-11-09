-- Rick and Morty Portal Gun: loader
RMPG = RMPG or {}

-- Parts that are still being finished are kept in rm_portalgun_workshop/dev/wip (its README says what goes where).
-- To bring one back: move its files into this addon and set its flag to true.
RMPG.WIP = false            -- freezing (freeze ray and knife) and the Prime drones
RMPG.WIP_TIMESTOP = false   -- the time stop device
RMPG.WIP_UNIVERSE = false   -- the universe browser and the "Rick and Morty: Universes" gamemode
RMPG.WIP_PICKLE = false     -- the pickle (rmpg_fruit_pickle): its entity and icon are in dev/wip
RMPG.WIP_PRIME_LIMBS = false -- Rick Prime's torn limbs: until version 1.0 (the old code is in dev/wip)

local shared = {
	"rmpg/sh_config.lua",
	"rmpg/sh_lang.lua",
	"rmpg/sh_shape.lua",
	"rmpg/sh_util.lua",
	"rmpg/sh_phoenix.lua",
	"rmpg/sh_fruit.lua",
	"rmpg/sh_boots.lua",
	"rmpg/sh_tentacle.lua",
	"rmpg/sh_neutrino.lua",
	"rmpg/sh_patch.lua",
}
local server = {
	"rmpg/sv_portals.lua",
	"rmpg/sv_bomb.lua",
	"rmpg/sv_shield.lua",
	"rmpg/sv_implants.lua",
	"rmpg/sv_meeseeks.lua",
	"rmpg/sv_phoenix.lua",
	"rmpg/sv_pills.lua",
	"rmpg/sv_neutrino.lua",
	"rmpg/sv_clones.lua",
	"rmpg/sv_visitbot.lua",
	"rmpg/sv_patch.lua",
	"rmpg/sv_happy.lua",
	"rmpg/sv_gore.lua",
	"rmpg/sv_prime.lua",
	"rmpg/sv_trap.lua",
	"rmpg/sv_maptravel.lua",
	"rmpg/sv_net.lua",
}
local client = {
	"rmpg/cl_render.lua",
	"rmpg/cl_model_parts.lua",
	"rmpg/cl_model.lua",
	"rmpg/cl_locations.lua",
	"rmpg/cl_hud.lua",
	"rmpg/cl_menu.lua",
	"rmpg/cl_radial.lua",
	"rmpg/cl_shield.lua",
	"rmpg/cl_utilities.lua",
	"rmpg/cl_meeseeks.lua",
	"rmpg/cl_phoenix.lua",
	"rmpg/cl_pills.lua",
	"rmpg/cl_neutrino.lua",
	"rmpg/cl_clones.lua",
	"rmpg/cl_patch.lua",
	"rmpg/cl_happy.lua",
	"rmpg/cl_prime.lua",
	"rmpg/cl_trap.lua",
	"rmpg/cl_maptravel.lua",
	"rmpg/cl_implants.lua",
	"rmpg/cl_items.lua",
	"rmpg/cl_tentacle.lua",
	"rmpg/cl_bombpad.lua",
	"rmpg/cl_cloneicon.lua",
	"rmpg/cl_desktop.lua",
	"rmpg/cl_wiki.lua",
}
if RMPG.WIP then
	table.insert(shared, "rmpg/sh_freeze.lua")
	for _, f in ipairs({ "rmpg/sv_freeze.lua", "rmpg/sv_drones.lua" }) do table.insert(server, f) end
	table.insert(client, "rmpg/cl_freeze.lua")
end
if RMPG.WIP_TIMESTOP then
	table.insert(server, "rmpg/sv_timestop.lua")
	table.insert(client, "rmpg/cl_timestop.lua")
end
if RMPG.WIP_UNIVERSE then
	table.insert(server, #server, "rmpg/sv_universe.lua")
	table.insert(client, "rmpg/cl_universe.lua")
end

for _, f in ipairs(shared) do
	if SERVER then AddCSLuaFile(f) end
	include(f)
end

if SERVER then
	for _, f in ipairs(client) do AddCSLuaFile(f) end
	for _, f in ipairs(server) do include(f) end

	-- Content for clients joining a dedicated server without the Workshop copy
	local content = {
		"materials/rmpg/portal_sheet.png", "materials/rmpg/portal_outline.png",
		"materials/rmpg/glow.png", "materials/rmpg/ring.png", "materials/rmpg/icon_anim.png",
		"materials/entities/weapon_rm_portalgun.png", "materials/entities/rmpg_flask.png",
		"materials/entities/rmpg_core.png", "materials/entities/rmpg_prime_bomb.png",
		"materials/entities/rmpg_shield_chip.png", "materials/rmpg/hex.png", "materials/entities/weapon_rmpg_meeseeks_box.png",
		"materials/entities/weapon_rmpg_dna_syringe.png", "materials/entities/weapon_rmpg_detonator.png", "materials/entities/rmpg_phoenix_tank.png",
		"materials/entities/rmpg_acid_vat.png", "materials/entities/rmpg_acid_vat_fake.png", "materials/entities/rmpg_fruit_potato.png", "materials/entities/weapon_rmpg_pills.png", "materials/entities/weapon_rmpg_laser.png", "materials/entities/rmpg_brain_worm.png", "materials/entities/weapon_rmpg_worm_syringe.png", "materials/entities/weapon_rmpg_eyepatch.png", "materials/entities/weapon_rmpg_grav_boots.png", "materials/entities/rmpg_evac_chip.png", "materials/rmpg/fx_blank.vtf", "materials/rmpg/fx_blank_grey.vtf", "materials/entities/rmpg_clone.png", "materials/entities/weapon_rmpg_pill.png", "materials/entities/rmpg_neutrino_bomb.png",
	}
	for _, f in ipairs(content) do resource.AddSingleFile(f) end
	-- models (AddFile also sends their .vvd / .vtx / .phy) and their materials
	for _, f in ipairs({ "models/rmpg/portalgun_classic.mdl", "models/rmpg/portalgun_prime.mdl", "models/rmpg/fluid_flask.mdl",
		"models/rmpg/prime_bomb.mdl", "models/rmpg/tent_link.mdl", "models/rmpg/tent_ball.mdl", "models/rmpg/tent_mount.mdl", "models/rmpg/tent_claw.mdl", "models/rmpg/tent_wire.mdl", "models/rmpg/shield_chip.mdl", "models/rmpg/meeseeks_box.mdl", "models/rmpg/phoenix_tank.mdl", "models/rmpg/pill_bottle.mdl", "models/rmpg/pill.mdl", "models/rmpg/laser_gun.mdl", "models/rmpg/rock_a.mdl", "models/rmpg/rock_b.mdl", "models/rmpg/neutrino_bomb.mdl", "models/rmpg/brain_worm.mdl", "models/rmpg/worm_seg.mdl", "models/rmpg/eyepatch.mdl", "models/rmpg/eyepatch_strap.mdl", "models/rmpg/grav_boots.mdl", "models/rmpg/grav_boots_prop.mdl", "models/rmpg/dna_syringe.mdl", "models/rmpg/worm_syringe.mdl", "models/rmpg/detonator.mdl", "models/rmpg/energy_core.mdl", "models/rmpg/worm_chunk.mdl", "models/rmpg/plumbus.mdl", "materials/models/rmpg/rmpg_plumbus.vmt", "materials/models/rmpg/rmpg_pal6.vtf", "materials/rmpg/fx_heart.vmt", "materials/entities/weapon_rmpg_plumbus.png", "models/rmpg/worm_nest.mdl", "models/rmpg/worm_egg.mdl", "materials/rmpg/decal_slime_big.vmt", "materials/entities/rmpg_arm_chip.png", "materials/entities/rmpg_tentacle_chip.png", "materials/entities/rmpg_prime_chip.png", "materials/entities/rmpg_worm_nest.png", "models/player/meeseeks/meeseeks.mdl", "materials/models/meeseeks/meeseeks.vmt",
		"materials/models/rmpg/rmpg_palette2.vmt", "materials/models/rmpg/rmpg_lens_off.vmt", "materials/models/rmpg/rmpg_lens_on.vmt",
		"materials/models/rmpg/rmpg_chip_core.vmt", "materials/models/rmpg/rmpg_tent.vmt",
		"materials/models/rmpg/rmpg_palette.vmt", "materials/models/rmpg/rmpg_glass.vmt", "materials/models/rmpg/rmpg_fluid.vmt",
		"materials/models/rmpg/rmpg_glass_green.vmt", "materials/models/rmpg/rmpg_emit.vmt", "materials/models/rmpg/rmpg_white.vtf",
		"materials/models/rmpg/rmpg_worm_flesh.vmt", "materials/models/rmpg/rmpg_chitin.vmt", "materials/models/rmpg/rmpg_pal3.vtf",
		"materials/rmpg/fx_flame1.vmt", "materials/rmpg/fx_flame2.vmt", "materials/rmpg/fx_smoke.vmt", "materials/rmpg/fx_chip.vmt",
		"materials/rmpg/fx_smile.vmt", "materials/rmpg/fx_star.vmt", "materials/rmpg/fx_rainbow.vmt", "materials/rmpg/fx_holo.vmt", "materials/rmpg/fx_pixel.vmt", "materials/models/rmpg/rmpg_boots.vmt", "materials/models/rmpg/rmpg_pal4.vtf", "materials/models/rmpg/rmpg_items.vmt", "materials/models/rmpg/rmpg_pal5.vtf", "materials/models/rmpg/rmpg_goo_green.vmt", "materials/models/rmpg/rmpg_goo_pink.vmt", "materials/models/rmpg/rmpg_goo_mark.vmt", "materials/models/rmpg/rmpg_goo_worm.vmt", "materials/models/rmpg/rmpg_goo_empty.vmt" }) do
		resource.AddFile(f)
	end
	for _, s in ipairs(file.Find("sound/rmpg/*.wav", "GAME")) do
		resource.AddSingleFile("sound/rmpg/" .. s)
	end
else
	for _, f in ipairs(client) do include(f) end
end
