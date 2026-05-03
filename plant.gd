extends Node2D

# --- Данные растения ---
var growth_stage: int = 0          # текущая стадия (0 - семя, 1 - росток и т.д.)
var final_stage: int = 3           # стадия, на которой растение считается взрослым
var days_to_grow: int = 1          # сколько дней до перехода на следующую стадию
var watered: bool = false          # полито ли сегодня

var plant_name: String = "Неизвестное растение"
var seed_texture: Texture2D        # базовая текстура (семени)

# Можно добавить массив текстур для каждой стадии
var stage_textures: Array[Texture2D] = []

func setup(seed_tex: Texture2D, name_str: String = "Растение") -> void:
	plant_name = name_str
	seed_texture = seed_tex
	$Sprite.texture = seed_tex

func water() -> void:
	watered = true

func advance_day() -> void:
	if growth_stage < final_stage:
		growth_stage += 1
		# Меняем спрайт, если есть текстуры для стадий
		if stage_textures.size() > growth_stage:
			$Sprite.texture = stage_textures[growth_stage]
	watered = false   # сбрасываем полив на следующий день
