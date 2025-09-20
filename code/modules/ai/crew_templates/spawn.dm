#ifdef CREW_AI_FOUNDATION

/mob/living/carbon/human
	/// Template reference assigned when spawned by the AI crew tooling.
	var/datum/crew_template/ai_crew_template
	/// Cached identifier for log output when the datum reference is unavailable.
	var/ai_crew_template_id

/// Spawns a blank human and equips the configured outfit.
/proc/ai_crew_spawn_human(turf/spawn_turf, datum/crew_template/template = null, spawn_name = null)
	if(!AI_CREW_ENABLED)
		return null
	if(!istype(spawn_turf))
		return null
	if(!istype(template))
		template = ai_crew_get_fallback_template()
	var/mob/living/carbon/human/new_human = new(spawn_turf)
	if(spawn_name)
		new_human.fully_replace_character_name(new_human.real_name, spawn_name)
	new_human.ai_crew_template = template
	new_human.ai_crew_template_id = template?.template_id
	if(!ai_crew_apply_outfit(new_human, template?.get_outfit_type(), "spawn", template?.template_id))
		ai_crew_log("ai crew spawn outfit fallback", list(
			"mob" = REF(new_human),
			"template" = template?.template_id,
		), TRUE)
	return new_human

/// Applies an outfit to a human with fallback handling and logging.
/proc/ai_crew_apply_outfit(mob/living/carbon/human/target, outfit_type, outfit_reason = "spawn", template_id = null)
	if(!istype(target))
		return FALSE
	target.delete_equipment()
	var/list/log_payload = list(
		"mob" = REF(target),
		"reason" = outfit_reason,
	)
	if(template_id)
		log_payload["template"] = template_id
	if(outfit_type)
		log_payload["requested_outfit"] = outfit_type
		if(target.equip_species_outfit(outfit_type))
			ai_crew_log("equipped crew template outfit", log_payload)
			return TRUE
		ai_crew_log("failed crew template outfit", log_payload, TRUE)
		target.delete_equipment()
	log_payload["requested_outfit"] = AI_CREW_FALLBACK_OUTFIT
	if(target.equip_species_outfit(AI_CREW_FALLBACK_OUTFIT))
		ai_crew_log("equipped crew fallback outfit", log_payload, TRUE)
		return TRUE
	ai_crew_log("failed crew fallback outfit", log_payload, TRUE)
	return FALSE

/// Reapply the stored template outfit to the target human.
/proc/ai_crew_reapply_outfit(mob/living/carbon/human/target, outfit_reason = "manual")
	if(!istype(target))
		return FALSE
	var/datum/crew_template/template = target.ai_crew_template
	if(!istype(template))
		template = ai_crew_get_fallback_template()
	return ai_crew_apply_outfit(target, template?.get_outfit_type(), outfit_reason, template?.template_id)

#endif
