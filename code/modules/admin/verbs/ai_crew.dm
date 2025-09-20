#ifdef CREW_AI_FOUNDATION

ADMIN_VERB(spawn_ai_crew_stub, R_DEBUG, "Spawn AI Crew Stub", "Spawn an AI Crew-controlled human at your location for testing.", ADMIN_CATEGORY_DEBUG)
	if(!AI_CREW_ENABLED)
		to_chat(user, span_warning("AI Crew is currently disabled. Toggle the feature on before spawning test pawns."))
		return
	var/mob/admin_mob = user?.mob
	if(!ismob(admin_mob))
		to_chat(user, span_warning("Only mobs can spawn AI Crew test subjects."))
		return
	var/turf/spawn_turf = get_turf(admin_mob)
	if(!spawn_turf)
		to_chat(user, span_warning("Unable to determine a safe spawn turf."))
		return
	var/mob/living/carbon/human/new_human = new(spawn_turf)
	var/new_name = "AI Crew #[rand(100, 999)]"
	new_human.fully_replace_character_name(new_human.real_name, new_name)
	var/datum/ai_controller/crew_human/controller = ai_crew_attach_controller(new_human, "admin spawn stub")
	if(!controller)
		to_chat(user, span_danger("Failed to attach an AI Crew controller; deleting the spawned mob."))
		qdel(new_human)
		return
	var/location = AREACOORD(new_human)
	log_admin("[key_name(user)] spawned AI Crew stub [new_human] at [location].")
	message_admins(span_adminnotice("[key_name_admin(user)] spawned AI Crew stub [new_human] at [location]."))
	to_chat(user, span_notice("Spawned [new_human] with controller [controller.get_controller_label()]."))

ADMIN_VERB(list_ai_crew_controllers, R_DEBUG, "List AI Crew Controllers", "List active AI Crew controllers and their attached mobs.", ADMIN_CATEGORY_DEBUG)
	if(!length(GLOB.ai_crew_controllers))
		to_chat(user, span_notice("No active AI Crew controllers found."))
		return
	to_chat(user, span_notice("Active AI Crew controllers:"))
	for(var/datum/ai_controller/crew_human/controller as anything in GLOB.ai_crew_controllers)
		if(QDELETED(controller))
			continue
		var/mob/living/carbon/human/human = controller.controlled_human
		var/location = human ? AREACOORD(human) : "unknown"
		var/state = human ? human.stat : "no pawn"
		var/descriptor = human ? human.name : "(no mob)"
		to_chat(user, span_info(" - [controller.get_controller_label()] → [descriptor], stat=[state], loc=[location]"))

#endif
