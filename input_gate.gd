# InputGate.gd (Godot 4.x)
extends Node

var _locks: int = 0

var blocked: bool:
	get: return _locks > 0

func block() -> void:
	_locks += 1

func unblock() -> void:
	_locks = max(0, _locks - 1)
