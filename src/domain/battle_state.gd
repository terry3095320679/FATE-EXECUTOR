class_name BattleState
extends RefCounted

signal health_changed(player_health: int, enemy_health: int)
signal turn_finished(result: PokerHandResult, enemy_damage: int)
signal battle_finished(player_won: bool)

var player_max_health: int = 100
var player_health: int = 100
var player_hand_size: int = 8
var enemy_id: StringName
var enemy_name_key: String
var enemy_intent_key: String
var enemy_max_health: int
var enemy_health: int
var enemy_attack: int
var round_number: int = 1
var is_finished: bool = false


func _init(enemy_definition: Dictionary = {}) -> void:
	enemy_id = StringName(enemy_definition.get("id", "enemy"))
	enemy_name_key = str(enemy_definition.get("name_key", enemy_definition.get("name", "battle.enemy_type")))
	enemy_intent_key = str(enemy_definition.get("intent_key", "battle.intent_caption"))
	enemy_max_health = int(enemy_definition.get("max_health", 1))
	enemy_health = enemy_max_health
	enemy_attack = int(enemy_definition.get("attack", 1))


func resolve_player_hand(result: PokerHandResult) -> void:
	if is_finished or result.hand_id == &"":
		return
	apply_player_hand(result)
	if is_finished:
		turn_finished.emit(result, 0)
		return
	resolve_enemy_action()
	turn_finished.emit(result, enemy_attack)


func apply_player_hand(result: PokerHandResult) -> bool:
	if is_finished or result.hand_id == &"":
		return false
	enemy_health = maxi(0, enemy_health - result.damage)
	health_changed.emit(player_health, enemy_health)
	if enemy_health == 0:
		is_finished = true
		battle_finished.emit(true)
		return true
	return false


func resolve_enemy_action() -> bool:
	if is_finished:
		return false
	player_health = maxi(0, player_health - enemy_attack)
	health_changed.emit(player_health, enemy_health)
	if player_health == 0:
		is_finished = true
		battle_finished.emit(false)
		return true
	round_number += 1
	return false
