#ifdef CREW_AI_FOUNDATION

/datum/unit_test/ai_crew_outfits
	var/original_flag
	var/mob/living/carbon/human/spawned_human
	var/mob/living/carbon/human/fallback_only

/datum/unit_test/ai_crew_outfits/Run()
	original_flag = CONFIG_GET(flag/ai_crew_enabled)
	CONFIG_SET(flag/ai_crew_enabled, TRUE)

	var/datum/crew_template/template = ai_crew_get_fallback_template()
	TEST_ASSERT(istype(template), "Expected fallback template to be available")

	spawned_human = ai_crew_spawn_human(run_loc_floor_bottom_left, template, "Unit Test Crew")
	TEST_ASSERT(istype(spawned_human), "ai_crew_spawn_human should return a human mob")
	TEST_ASSERT(istype(spawned_human.w_uniform, /obj/item/clothing/under/color/grey), "Spawned outfit should equip the assistant uniform")
	TEST_ASSERT(spawned_human.ai_crew_template == template, "Spawned pawn should keep a reference to its template")
	TEST_ASSERT_EQUAL(spawned_human.ai_crew_template_id, template.template_id, "Template id should be cached on the pawn")

	fallback_only = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(ai_crew_apply_outfit(fallback_only, null, "unit test fallback", "unit_test"), "Fallback outfit application should succeed when no primary outfit provided")
	TEST_ASSERT(istype(fallback_only.w_uniform, /obj/item/clothing/under/color/grey), "Fallback outfit should equip the assistant uniform")

/datum/unit_test/ai_crew_outfits/Destroy()
	if(spawned_human)
		qdel(spawned_human)
	if(fallback_only)
		qdel(fallback_only)
	CONFIG_SET(flag/ai_crew_enabled, original_flag)
	return ..()

#endif
