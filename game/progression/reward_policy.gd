class_name RewardPolicy
extends RefCounted
## Run experience purchases relic opportunities independently of profile growth.

const VERSION := "s2-1"
const INITIAL_THRESHOLD := 27
const INITIAL_LEVEL := 1
const INITIAL_OPPORTUNITIES := 0
const R021_BONUS_PERCENT := 35


static func next_threshold(previous: int) -> int:
	return roundi(previous * 1.13 + 4.0)

