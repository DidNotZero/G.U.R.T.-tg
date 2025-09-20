#ifdef CREW_AI_FOUNDATION

/// Defines persona and wardrobe metadata for a single AI crew archetype.
/datum/crew_template
	/// Stable identifier used to persist and look up the template.
	var/template_id
	/// Display label used in admin tooling.
	var/display_name
	/// Optional pronoun set (they/them, she/her, he/him, or custom string).
	var/pronouns
	/// Nominal job title displayed to admins and used for outfit selection.
	var/job_title
	/// Type path of the preferred species for this template.
	var/species_type = /datum/species/human
	/// Outfit type equipped on spawn.
	var/outfit_type
	/// Persona trait identifiers pulled from the trait registry (max 2 expected).
	var/list/traits
	/// Optional HEXACO factor weights (values 0..1).
	var/list/hexaco
	/// Soft biasing toward more or less speech output (percentage multiplier).
	var/talkiness_bias = 0
	/// Soft biasing toward formality in phrasing.
	var/formality_bias = 0
	/// Short note surfaced in admin tooling describing the outfit mapping.
	var/outfit_note
	/// Track when this template was last modified (unix timestamp).
	var/last_modified = 0
	/// Internal guard to avoid repeated registration when cloning datums.
	var/tmp/_auto_registered = FALSE


/datum/crew_template/New(skip_register = FALSE)
	traits = traits ? traits.Copy() : list()
	hexaco = hexaco ? hexaco.Copy() : list()
	. = ..()
	if(!_auto_registered)
		_auto_registered = TRUE
		if(!skip_register)
			ai_crew_register_template(src)

/// Returns the type path for the configured outfit if valid.
/datum/crew_template/proc/get_outfit_type()
	return ispath(outfit_type, /datum/outfit) ? outfit_type : null

/// Returns a human-readable label for display.
/datum/crew_template/proc/get_display_name()
	if(display_name)
		return display_name
	if(template_id)
		return template_id
	return "[type]"

/// Summarize the outfit mapping for admin inspectors.
/datum/crew_template/proc/get_outfit_summary()
	var/list/summary = list()
	if(outfit_type)
		summary += "outfit=[outfit_type]"
	else
		summary += "outfit=<missing>"
	if(job_title)
		summary += "job=[job_title]"
	if(outfit_note)
		summary += "note=[outfit_note]"
	return summary.Join(", ")

/// Applies the configured outfit to the provided human, returning success.
/datum/crew_template/proc/apply_outfit(mob/living/carbon/human/target, outfit_reason = "template")
	return ai_crew_apply_outfit(target, get_outfit_type(), outfit_reason, template_id)

/// Helper that ensures the template registry does not share mutable lists.
/datum/crew_template/proc/copy()
	var/datum/crew_template/cloned = new type(TRUE)
	cloned.template_id = template_id
	cloned.display_name = display_name
	cloned.pronouns = pronouns
	cloned.job_title = job_title
	cloned.species_type = species_type
	cloned.outfit_type = outfit_type
	cloned.traits = traits.Copy()
	cloned.hexaco = hexaco.Copy()
	cloned.talkiness_bias = talkiness_bias
	cloned.formality_bias = formality_bias
	cloned.outfit_note = outfit_note
	cloned.last_modified = last_modified
	return cloned

/// Default assistant-style template used when no external definitions exist.
/datum/crew_template/assistant
	template_id = "crew_assistant"
	display_name = "Assistant Crew"
	pronouns = "they/them"
	job_title = JOB_ASSISTANT
	outfit_type = /datum/outfit/job/assistant/consistent
	outfit_note = "Matches station assistant loadout"

/// Engineering technician baseline mapping.
/datum/crew_template/engineer
	template_id = "crew_engineer"
	display_name = "Engineering Crew"
	pronouns = "she/her"
	job_title = JOB_STATION_ENGINEER
	outfit_type = /datum/outfit/job/engineer
	outfit_note = "Engineering jumpsuit, toolbelt, hardhat"

/// Medical responder baseline mapping.
/datum/crew_template/medic
	template_id = "crew_medic"
	display_name = "Medical Crew"
	pronouns = "he/him"
	job_title = JOB_MEDICAL_DOCTOR
	outfit_type = /datum/outfit/job/doctor
	outfit_note = "Medical scrubs and belt essentials"

#endif
