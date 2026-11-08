class_name CharacterStage
extends PanelContainer
## Vitrine do personagem: painel escuro com holofote, chão iluminado e o personagem grande no
## centro. Usada na criação da carreira e na tela de personagem.

var view := CharacterView.new()
var backdrop := StageBackdrop.new()

var appearance: CharacterAppearance:
	set(value):
		view.appearance = value
	get:
		return view.appearance


func _init() -> void:
	theme_type_variation = &"StagePanel"
	# A luz e o personagem ficam recortados no formato arredondado do painel.
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW


func _ready() -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.floor_ratio = 0.94
	holder.add_child(backdrop)
	view.name = "CharacterPreview"
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_top = 12
	view.offset_bottom = -4
	holder.add_child(view)
