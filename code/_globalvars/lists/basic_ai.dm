///all basic ai subtrees
GLOBAL_LIST_EMPTY(ai_subtrees)

///basic ai controllers based on status
GLOBAL_LIST_INIT(ai_controllers_by_status, list(
	AI_STATUS_ON = list(),
	AI_STATUS_OFF = list(),
	AI_STATUS_IDLE = list(),
))

///basic ai controllers based on their z level
GLOBAL_LIST_EMPTY(ai_controllers_by_zlevel)

///all active AI Crew human controllers
GLOBAL_LIST_EMPTY(ai_crew_controllers)

#ifdef CREW_AI_FOUNDATION
///registered AI crew templates keyed by normalized id
GLOBAL_LIST_EMPTY(ai_crew_templates_by_id)
///ordered list of template identifiers for iteration and debug menus
GLOBAL_LIST_EMPTY(ai_crew_template_ids)
///flag indicating whether builtin templates were registered
GLOBAL_VAR_INIT(ai_crew_templates_bootstrapped, FALSE)
#endif

///basic ai controllers that are currently performing idled behaviors
GLOBAL_LIST_INIT_TYPED(unplanned_controllers, /list/datum/ai_controller, list(
	AI_STATUS_ON = list(),
	AI_STATUS_IDLE = list(),
))
