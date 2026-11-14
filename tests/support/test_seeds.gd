extends GutTest
## v0.11.1 Step 4: Seeds.count's rule, both branches, without depending on this process's environment.


func test_the_full_suite_runs_the_full_count() -> void:
	assert_eq(Seeds.count_for(1000, "1"), 1000)
	assert_eq(Seeds.count_for(150, "1"), 150)


func test_elsewhere_a_loop_runs_at_most_200() -> void:
	assert_eq(Seeds.count_for(1000, ""), 200, "unset")
	assert_eq(Seeds.count_for(1000, "0"), 200, "any other value")
	assert_eq(Seeds.count_for(1000, "true"), 200, 'only "1" switches it')
	assert_eq(Seeds.count_for(150, ""), 150, "a smaller loop keeps its count")


func test_count_reads_the_environment_variable() -> void:
	var want := Seeds.count_for(1000, OS.get_environment(Seeds.ENV))
	assert_eq(Seeds.count(1000), want)
