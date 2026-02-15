extends Node

## название точки
@export var point_name: String = ""
## -1 = для всех команд, 0 = команда 1, 1 = команда 2
@export var for_team: int = -1  

func is_for_team(team_id: int) -> bool:
	return for_team == -1 or for_team == team_id
