class_name BattleState
extends RefCounted

signal health_changed(player_health: int, enemy_health: int)
signal turn_finished(result: PokerHandResult, enemy_damage: int)
signal battle_finished(player_won: bool)
signal block_changed(player_block: int)

var player_max_health: int = 100
var player_health: int = 100
var player_hand_size: int = 8
var player_block: int = 0
var enemy_id: StringName
var enemy_type: String = "normal"
var enemy_name_key: String
var enemy_intent_key: String
var stage: int = 1
var enemy_base_health: int
var enemy_base_attack: int
var enemy_max_health: int
var enemy_health: int
var enemy_attack: int
var round_number: int = 1
var is_finished: bool = false
var last_enemy_damage: int = 0


func _init(enemy_definition: Dictionary = {}) -> void:
	enemy_id = StringName(enemy_definition.get("id", "enemy"))
	enemy_type = str(enemy_definition.get("enemy_type", "normal"))
	stage = maxi(1, int(enemy_definition.get("stage", 1)))
	enemy_name_key = str(enemy_definition.get("name_key", enemy_definition.get("name", "battle.enemy_type")))
	enemy_intent_key = str(enemy_definition.get("intent_key", "battle.intent_caption"))
	enemy_base_health = maxi(1, int(enemy_definition.get(
		"base_health", enemy_definition.get("max_health", 1)
	)))
	enemy_base_attack = maxi(0, int(enemy_definition.get(
		"base_attack", enemy_definition.get("attack", 1)
	)))
	enemy_max_health = maxi(1, int(enemy_definition.get(
		"final_health", enemy_definition.get("max_health", enemy_base_health)
	)))
	enemy_health = enemy_max_health
	enemy_attack = maxi(0, int(enemy_definition.get(
		"final_attack", enemy_definition.get("attack", enemy_base_attack)
	)))


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
	var blocked := mini(player_block, enemy_attack)
	player_block -= blocked
	last_enemy_damage = enemy_attack - blocked
	player_health = maxi(0, player_health - last_enemy_damage)
	block_changed.emit(player_block)
	health_changed.emit(player_health, enemy_health)
	if player_health == 0:
		is_finished = true
		battle_finished.emit(false)
		return true
	round_number += 1
	return false


func gain_block(amount: int) -> int:
	if amount <= 0:
		return player_block
	player_block += amount
	block_changed.emit(player_block)
	return player_block


func set_player_state(max_health: int, current_health: int) -> void:
	player_max_health = maxi(1, max_health)
	player_health = clampi(current_health, 0, player_max_health)
	health_changed.emit(player_health, enemy_health)


func heal(amount: int) -> int:
	if amount <= 0 or player_health >= player_max_health:
		return 0
	var before := player_health
	player_health = mini(player_max_health, player_health + amount)
	health_changed.emit(player_health, enemy_health)
	return player_health - before
