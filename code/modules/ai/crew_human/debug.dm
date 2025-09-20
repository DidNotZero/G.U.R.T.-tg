#ifdef CREW_AI_FOUNDATION

GLOBAL_DATUM_INIT(ai_crew_inspector, /datum/ai_crew_inspector, new)

/// Human AI Crew blackboard key descriptions surfaced in the inspector UI.
var/static/list/ai_crew_blackboard_key_descriptions = list(
	BB_CREW_PERSONA = "Persona metadata (name, pronouns, job badge, species).",
	BB_CREW_TRAITS = "Persona traits seeded from the RimWorld-style registry.",
	BB_CREW_TONE = "High-level tone hint for LLM prompts (serious|dry|light).",
	BB_CREW_TALK_BUDGET = "Cadence budgeting state (baseline, overshoot windows, cooldowns).",
	BB_CREW_LAST_HEARD = "Rolling buffer of recently heard IC and radio utterances.",
	BB_CREW_ZONE = "Current station zone identifier assigned by the navgraph.",
	BB_CREW_GOAL = "Active high-level goal payload (wander, go-to, follow, avoid).",
	BB_CREW_NAVPATH = "Current navigation path awaiting execution.",
	BB_CREW_INTENT = "Most recent speech intent emitted by planning (ic|radio|emote).",
	BB_CREW_TARGET_CHANNEL = "Target radio channel requested for the next emission.",
	BB_CREW_FALLBACK_FLAG = "Whether the previous speech line used a local fallback.",
)

/// Returns a short string representing the type of a debug value.
/proc/ai_crew_debug_type(value)
	if(isnull(value))
		return "null"
	if(istext(value))
		return "text"
	if(isnum(value))
		return "num"
	if(islist(value))
		return "list"
	if(isdatum(value))
		var/datum/datum_value = value
		if(QDELETED(datum_value))
			return "datum (qdel)"
		return "[datum_value.type]"
	if(ispath(value))
		return "path"
	return "[value]"

/// Formats arbitrary values into human-readable summaries for the inspector UI.
/proc/ai_crew_debug_format_value(value, depth = 0, max_depth = 2)
	if(isnull(value))
		return CREW_BB_VALUE_EMPTY
	if(depth >= max_depth)
		return "..."
	if(istext(value))
		return value
	if(isnum(value))
		return num2text(value)
	if(islist(value))
		var/list/list_value = value
		if(!length(list_value))
			return "[]"
		var/list/parts = list()
		var/index = 0
		for(var/key in list_value)
			index++
			if(index > 5)
				parts += "..."
				break
			var/subvalue = list_value[key]
			var/fragment = ai_crew_debug_format_value(subvalue, depth + 1, max_depth)
			if(isnum(key) && key <= list_value.len)
				parts += fragment
			else
				parts += "[key]=[fragment]"
		return "[length(list_value)] entries: [jointext(parts, ", ")]"
	if(isdatum(value))
		var/datum/datum_value = value
		if(QDELETED(datum_value))
			return "<qdeleted> [datum_value.type]"
		var/descriptor = isatom(datum_value) ? "[datum_value]" : "[datum_value.type]"
		return "[descriptor] #[REF(datum_value)]"
	if(ispath(value))
		return "[value]"
	return "[value]"

/datum/ai_crew_inspector/ui_state(mob/user)
	return ADMIN_STATE(R_DEBUG)

/datum/ai_crew_inspector/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AICrewInspector", "AI Crew Inspector")
		ui.open()

/datum/ai_crew_inspector/ui_data(mob/user)
	var/list/controllers = list()
	for(var/datum/ai_controller/crew_human/controller as anything in GLOB.ai_crew_controllers)
		if(QDELETED(controller))
			continue
		controllers += list(controller.get_inspector_payload())
	return list(
		"controllers" = controllers,
		"updated_at" = world.time,
	)

/datum/ai_crew_inspector/ui_static_data(mob/user)
	return list(
		"key_descriptions" = ai_crew_blackboard_key_descriptions.Copy(),
	)

/datum/ai_crew_inspector/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	return FALSE

#endif
