class_name ManualInputReceipt
extends RefCounted
## An accepted physical character. Only TypingSession creates these receipts.
## Consumers drain once at the next fixed step; id is the deduplication key.

var id: String
var attempt_id: String
var target_id: StringName
var word: String
var character: String
var position: int
var completes_word: bool
var word_version: int = 0
