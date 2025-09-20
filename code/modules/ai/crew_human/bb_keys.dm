#ifdef CREW_AI_FOUNDATION

/// Blackboard key storing persona metadata (name, pronouns, species, job badge).
#define BB_CREW_PERSONA "crew_persona"
/// Blackboard key storing the 1-2 RimWorld-style persona traits.
#define BB_CREW_TRAITS "crew_traits"
/// Blackboard key tracking speaking tone (serious|dry|light, etc.).
#define BB_CREW_TONE "crew_tone"
/// Blackboard key storing cadence budgeting data (line budgets, overshoot windows).
#define BB_CREW_TALK_BUDGET "crew_talk_budget"
/// Blackboard key containing a ring buffer of the most recent heard utterances.
#define BB_CREW_LAST_HEARD "crew_last_heard"
/// Blackboard key storing the identifier of the zone the pawn currently occupies.
#define BB_CREW_ZONE "crew_zone"
/// Blackboard key storing the active high-level goal directive.
#define BB_CREW_GOAL "crew_goal"
/// Blackboard key storing the current navigation path (ordered list of turf refs).
#define BB_CREW_NAVPATH "crew_navpath"
/// Blackboard key storing the most recent intent produced by the LLM (ic|radio|emote).
#define BB_CREW_INTENT "crew_intent"
/// Blackboard key storing the radio channel target (common|med|eng|sec|sci|cargo|local).
#define BB_CREW_TARGET_CHANNEL "crew_target_channel"
/// Blackboard key signalling that the last speech emission fell back to canned text.
#define BB_CREW_FALLBACK_FLAG "crew_fallback_flag"

/// Maximum entries to keep in BB_CREW_LAST_HEARD ring buffer.
#define BB_CREW_LAST_HEARD_MAX_ENTRIES 12

/// Helper macro for admin inspector summaries when a value is not present.
#define CREW_BB_VALUE_EMPTY "<unset>"

#endif
