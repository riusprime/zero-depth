extends GutTest
## The native core gives the recorded results on this compiler and platform (NativeFixtures): every kernel's hash on
## its fixed, seeded inputs and the horde scene's state hash, as recorded from the owner's Windows build (MSVC).
## Linux CI (gcc) is the first real check of a second compiler; scripts/native/check_release.sh runs the same check
## against the release library. A failure here means the C++ rounds differently on this build: fix the build (its
## float flags, native/README.md), never re-record to make it pass.


func test_every_kernel_gives_the_recorded_hash() -> void:
	var want := NativeFixtures.read_kernels()
	assert_eq(want.size(), NativeFixtures.ORDER.size(), "a recorded hash for every kernel")
	var got := NativeFixtures.kernel_hashes()
	for k in NativeFixtures.ORDER:
		assert_eq(
			String(got.get(k, "")),
			String(want.get(k, "")),
			"the native core gives different results on this compiler/platform: kernel %s" % k
		)


func test_the_horde_scene_gives_the_recorded_hash() -> void:
	assert_eq(
		NativeFixtures.scene_hash(),
		NativeFixtures.read_scene(),
		"the native core gives different results on this compiler/platform: the horde scene"
	)


func test_the_same_inputs_give_the_same_hashes_twice() -> void:
	assert_eq(
		NativeFixtures.kernel_hashes(),
		NativeFixtures.kernel_hashes(),
		"self-determinism in one process"
	)
