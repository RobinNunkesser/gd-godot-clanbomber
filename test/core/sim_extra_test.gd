class_name SimExtraTest
extends GdUnitTestSuite

const SAMPLES := 128000


func _histogram(disabled: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var counts := {}
	for i in SAMPLES:
		var type := SimExtra.roll(rng, disabled)
		counts[type] = counts.get(type, 0) + 1
	return counts


func _share(counts: Dictionary, type: int) -> float:
	return float(counts.get(type, 0)) / SAMPLES


func test_drop_distribution_matches_original() -> void:
	var counts := _histogram()
	assert_float(_share(counts, SimExtra.Type.POWER)).is_equal_approx(0.125, 0.01)
	assert_float(_share(counts, SimExtra.Type.BOMB)).is_equal_approx(0.125, 0.01)
	assert_float(_share(counts, SimExtra.Type.SKATEBOARD)).is_equal_approx(0.125, 0.01)
	assert_float(_share(counts, SimExtra.Type.KICK)).is_equal_approx(0.0625, 0.01)
	assert_float(_share(counts, SimExtra.Type.GLOVE)).is_equal_approx(0.0625, 0.01)
	for disease in [SimExtra.Type.OVERDRIVE, SimExtra.Type.REVERSE, SimExtra.Type.AUTOBOMB]:
		assert_float(_share(counts, disease)).is_equal_approx(1.0 / 128.0, 0.003)
	assert_float(1.0 - _share(counts, SimExtra.Type.NONE)).is_equal_approx(0.523, 0.01)


func test_disabled_type_never_drops() -> void:
	var counts := _histogram([SimExtra.Type.KICK, SimExtra.Type.GLOVE])
	assert_bool(counts.has(SimExtra.Type.KICK)).is_false()
	assert_bool(counts.has(SimExtra.Type.GLOVE)).is_false()
	assert_bool(counts.has(SimExtra.Type.POWER)).is_true()


func test_all_disabled_yields_nothing() -> void:
	var rng := RandomNumberGenerator.new()
	var all: Array = range(SimExtra.ALL_TYPES)
	for i in 100:
		assert_int(SimExtra.roll(rng, all)).is_equal(SimExtra.Type.NONE)
