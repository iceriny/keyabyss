class_name VocabularyImport
extends RefCounted

var title: String = ""
var entries: Array[VocabularyEntry] = []
var issues: PackedStringArray = PackedStringArray()
var duplicates: int = 0
var raw_count: int = 0
var error: String = ""
