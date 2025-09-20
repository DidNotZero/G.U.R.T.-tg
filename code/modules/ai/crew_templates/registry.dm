#ifdef CREW_AI_FOUNDATION

/// Registers a crew template, replacing any existing entry with the same id.
/proc/ai_crew_register_template(datum/crew_template/template)
	if(!istype(template))
		return FALSE
	if(isnull(template.template_id) || !length(template.template_id))
		ai_crew_log("crew template missing id", list(
			"type" = template.type,
		), TRUE)
		return FALSE
	LAZYINITLIST(GLOB.ai_crew_templates_by_id)
	LAZYINITLIST(GLOB.ai_crew_template_ids)
	var/template_id = lowertext(template.template_id)
	var/datum/crew_template/existing = GLOB.ai_crew_templates_by_id[template_id]
	if(existing && existing != template)
		GLOB.ai_crew_template_ids -= template_id
	GLOB.ai_crew_templates_by_id[template_id] = template
	if(!(template_id in GLOB.ai_crew_template_ids))
		GLOB.ai_crew_template_ids += template_id
	return TRUE

/// Retrieves a template by id, performing lazy bootstrap if required.
/proc/ai_crew_get_template(template_id)
	if(isnull(template_id))
		return null
	ai_crew_bootstrap_default_templates()
	return GLOB.ai_crew_templates_by_id?[lowertext(template_id)]

/// Returns all registered template ids (shallow copy).
/proc/ai_crew_get_template_ids()
	ai_crew_bootstrap_default_templates()
	if(!islist(GLOB.ai_crew_template_ids))
		return list()
	return GLOB.ai_crew_template_ids.Copy()

/// Picks a template, optionally biasing toward a preferred id.
/proc/ai_crew_pick_template(preferred_id = null)
	var/datum/crew_template/template = ai_crew_get_template(preferred_id)
	if(istype(template))
		return template
	var/list/template_ids = ai_crew_get_template_ids()
	if(!length(template_ids))
		return null
	return ai_crew_get_template(pick(template_ids))

/// Ensures our default templates exist; safe to call multiple times.
/proc/ai_crew_bootstrap_default_templates()
	if(GLOB.ai_crew_templates_bootstrapped)
		return TRUE
	GLOB.ai_crew_templates_bootstrapped = TRUE
	if(!islist(GLOB.ai_crew_templates_by_id))
		GLOB.ai_crew_templates_by_id = list()
	if(!islist(GLOB.ai_crew_template_ids))
		GLOB.ai_crew_template_ids = list()
	new /datum/crew_template/assistant()
	new /datum/crew_template/engineer()
	new /datum/crew_template/medic()
	return TRUE

/// Acquire a template for fallback when none are available.
/proc/ai_crew_get_fallback_template()
	var/datum/crew_template/template = ai_crew_get_template(AI_CREW_DEFAULT_TEMPLATE_ID)
	if(istype(template))
		return template
	return new /datum/crew_template/assistant()

GLOBAL_VAR_INIT(ai_crew_templates_bootstrap_flag, ai_crew_bootstrap_default_templates())

#endif
