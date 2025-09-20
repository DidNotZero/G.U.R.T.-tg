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
	var/list/template_choices = list()
	for(var/template_id in ai_crew_get_template_ids())
		var/datum/crew_template/listed_template = ai_crew_get_template(template_id)
		if(!istype(listed_template))
			continue
		var/label = "[listed_template.get_display_name()] ([template_id])"
		template_choices[label] = template_id
	var/datum/crew_template/selected_template
	if(length(template_choices))
		var/selection = input(user, "Select a crew template", "AI Crew Spawn") as null|anything in template_choices
		if(isnull(selection))
			return
		selected_template = ai_crew_get_template(template_choices[selection])
	else
		selected_template = ai_crew_get_fallback_template()
	var/new_name = "AI Crew #[rand(100, 999)]"
	var/mob/living/carbon/human/new_human = ai_crew_spawn_human(spawn_turf, selected_template, new_name)
	if(!new_human)
		to_chat(user, span_danger("Failed to spawn a human pawn. Verify the feature flag and template configuration."))
		return
	var/datum/ai_controller/crew_human/controller = ai_crew_attach_controller(new_human, "admin spawn stub")
	if(!controller)
		to_chat(user, span_danger("Failed to attach an AI Crew controller; deleting the spawned mob."))
		qdel(new_human)
		return
	var/location = AREACOORD(new_human)
	log_admin("[key_name(user)] spawned AI Crew stub [new_human] at [location] using [selected_template?.template_id || "fallback"].")
	message_admins(span_adminnotice("[key_name_admin(user)] spawned AI Crew stub [new_human] at [location] using [selected_template?.template_id || "fallback"]."))
	var/summary = selected_template?.get_outfit_summary() || "fallback outfit"
	to_chat(user, span_notice("Spawned [new_human] with controller [controller.get_controller_label()] ([summary])."))

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

ADMIN_VERB(reapply_ai_crew_outfit, R_DEBUG, "Reapply AI Crew Outfit", "Reapply a stored AI Crew outfit to a selected pawn.", ADMIN_CATEGORY_DEBUG)
	if(!length(GLOB.ai_crew_controllers))
		to_chat(user, span_notice("No AI Crew controllers are currently active."))
		return
	var/list/choices = list()
	for(var/datum/ai_controller/crew_human/controller as anything in GLOB.ai_crew_controllers)
		if(QDELETED(controller))
			continue
		var/mob/living/carbon/human/human = controller.controlled_human
		if(!istype(human))
			continue
		var/label = "[controller.get_controller_label()] → [human]"
		choices[label] = human
	if(!length(choices))
		to_chat(user, span_notice("No AI Crew pawns available for outfit reapply."))
		return
	var/selection = input(user, "Select a pawn to refresh their outfit", "AI Crew Outfit") as null|anything in choices
	if(isnull(selection))
		return
	var/mob/living/carbon/human/target = choices[selection]
	if(!istype(target))
		to_chat(user, span_warning("The selected pawn is no longer valid."))
		return
	if(ai_crew_reapply_outfit(target, "admin reapply"))
		log_admin("[key_name(user)] reapplied AI Crew outfit for [target] at [AREACOORD(target)].")
		to_chat(user, span_notice("Reapplied AI Crew outfit for [target]."))
	else
		log_admin("[key_name(user)] attempted to reapply AI Crew outfit for [target], but it failed.")
		to_chat(user, span_warning("Failed to equip the AI Crew outfit; check ai_crew logs for details."))

ADMIN_VERB(open_ai_crew_inspector, R_DEBUG, "AI Crew Inspector", "Open the AI Crew blackboard inspector panel.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user?.mob
	if(!ismob(admin_mob))
		to_chat(user, span_warning("You must be controlling a mob to open the inspector."))
		return
	if(!length(GLOB.ai_crew_controllers))
		to_chat(user, span_notice("No AI Crew controllers are currently active; the inspector will open with an empty list."))
	GLOB.ai_crew_inspector.ui_interact(admin_mob)

#endif
