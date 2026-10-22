extends GdUnitTestSuite


func _rng(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _draw(rotation: MapRotation, pool: Array[String], rng: RandomNumberGenerator, count: int) -> Array[String]:
	var result: Array[String] = []
	for i in count:
		result.append(rotation.next(pool, rng))
	return result


func test_every_map_is_played_once_per_pass() -> void:
	var pool: Array[String] = ["a", "b", "c", "d", "e"]
	var rotation := MapRotation.new()
	var rng := _rng()
	for pass_index in 4:
		var drawn := _draw(rotation, pool, rng, pool.size())
		drawn.sort()
		assert_array(drawn).is_equal(pool)


func test_no_repeat_across_pass_boundary() -> void:
	var pool: Array[String] = ["a", "b", "c"]
	var rotation := MapRotation.new()
	var drawn := _draw(rotation, pool, _rng(3), 60)
	for i in range(1, drawn.size()):
		assert_str(drawn[i]).is_not_equal(drawn[i - 1])


func test_same_seed_gives_same_order() -> void:
	var pool: Array[String] = ["a", "b", "c", "d"]
	var first := _draw(MapRotation.new(), pool, _rng(11), 8)
	var second := _draw(MapRotation.new(), pool, _rng(11), 8)
	assert_array(first).is_equal(second)


func test_single_map_pool_repeats() -> void:
	var pool: Array[String] = ["only"]
	assert_array(_draw(MapRotation.new(), pool, _rng(), 3)).is_equal(["only", "only", "only"])


func test_empty_pool_returns_empty_name() -> void:
	var pool: Array[String] = []
	assert_str(MapRotation.new().next(pool, _rng())).is_equal("")


func test_removed_maps_are_dropped_from_the_running_pass() -> void:
	var rotation := MapRotation.new()
	var rng := _rng()
	var full: Array[String] = ["a", "b", "c", "d"]
	rotation.next(full, rng)
	var reduced: Array[String] = ["a", "b"]
	for i in 6:
		assert_bool(reduced.has(rotation.next(reduced, rng))).is_true()


func test_sequential_order_wraps_around() -> void:
	var rotation := MapRotation.new()
	var pool: Array[String] = ["a", "b", "c"]
	var drawn: Array[String] = []
	for i in 7:
		drawn.append(rotation.next_in_order(pool))
	assert_array(drawn).is_equal(["a", "b", "c", "a", "b", "c", "a"])


func test_sequential_order_restarts_when_current_map_leaves_pool() -> void:
	var rotation := MapRotation.new()
	var pool: Array[String] = ["a", "b", "c"]
	rotation.next_in_order(pool)
	rotation.next_in_order(pool)
	var reduced: Array[String] = ["a", "c"]
	assert_str(rotation.next_in_order(reduced)).is_equal("a")
	assert_str(MapRotation.new().next_in_order([] as Array[String])).is_equal("")
