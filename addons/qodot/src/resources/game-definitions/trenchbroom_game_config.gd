@tool
## Defines a new game in TrenchBroom to express a set of entity definitions and editor behaviors.
class_name TrenchBroomGameConfig
extends Resource

## Button to export/update this game's folder in the TrenchBroom Games Path.
@export var export_file: bool:
	get:
		return export_file
	set(new_export_file):
		if new_export_file != export_file:
			if Engine.is_editor_hint():
				do_export_file()

## The /games folder in either your TrenchBroom installation or your OS' user data folder.
@export_global_dir var trenchbroom_games_folder : String

## Name of the game in TrenchBroom's game list.
@export var game_name : String = "Qodot"

## Icon for TrenchBroom's game list.
@export var icon : Texture2D

## Available map formats when creating a new map in Trenchbroom. The order of elements in the array is respected by Trenchbroom. The `initialmap` key value is optional.
@export var map_formats: Array[Dictionary] = [
	{ "format": "Valve", "initialmap": "initial_valve.map" },
	{ "format": "Standard", "initialmap": "initial_standard.map" },
	{ "format": "Quake2", "initialmap": "initial_quake2.map" },
	{ "format": "Quake3" }
]

## Textures matching these patterns will be hidden from Trenchbroom.
@export var texture_exclusion_patterns: Array[String] = ["*_ao", "*_emission", "*_heightmap", "*_metallic", "*_normal", "*_orm", "*_roughness", "*_sss", "*_albedo"]

## FGD resource to include with this game. If using multiple FGD resources, this should be the master FGD that contains them in the `base_fgd_files` resource array. 
## Use only one FGD resource. Using multiple FGDs in this array does not work as intended but is left as an array for backwards compatibility.
@export var fgd_files : Array[Resource]

## Scale expression that modifies the default display scale of entities in Trenchbroom. See the [**Trenchbroom Documentation**](https://trenchbroom.github.io/manual/latest/#game_configuration_files_entities) for more information.
@export var entity_scale: String = "1"

## Scale of textures on new brushes.
@export var default_uv_scale : Vector2 = Vector2(1, 1)

## Arrays containing the TrenchbroomTag resource type.
@export_category("Editor hint tags")

## Container for TrenchbroomTag resources that apply to brush entities.
@export var brush_tags : Array[Resource] = []

## Container for TrenchbroomTag resources that apply to textures.
@export var face_tags : Array[Resource] = []

## Private variable for storing fgd names, used in build_class_text().
var _fgd_filenames : Array = []

## Private default .cfg contents.
## See also: https://trenchbroom.github.io/manual/latest/#game_configuration_files
var _base_text: String = """{
	"version": 9,
	"name": "%s",
	"icon": "icon.png",
	"fileformats": [
		%s
	],
	"filesystem": {
		"searchpath": ".",
		"packageformat": { "extension": ".zip", "format": "zip" }
	},
	"materials": {
		"root": "textures",
		"extensions": [".bmp", ".exr", ".hdr", ".jpeg", ".jpg", ".png", ".tga", ".webp"],
		"excludes": [ %s ]
	},
	"entities": {
		"definitions": [ %s ],
		"defaultcolor": "0.6 0.6 0.6 1.0",
		"scale": %s
	},
	"tags": {
		"brush": [
			%s
		],
		"brushface": [
			%s
		]
	},
	"faceattribs": { 
		"defaults": {
			%s
		},
		"contentflags": [],
		"surfaceflags": []
	}
}
"""

func _init():
	if not icon:
		if ResourceLoader.exists("res://addons/qodot/icon.png"):
			icon = ResourceLoader.load("res://addons/qodot/icon.png")

## Matches tag key enum to the String name used in .cfg
static func get_match_key(tag_match_type: int) -> String:
	match tag_match_type:
		TrenchBroomTag.TagMatchType.MATERIAL:
			return "material"
		TrenchBroomTag.TagMatchType.CLASSNAME:
			return "classname"
		_:
			push_error("Tag match type %s is not valid" % [tag_match_type])
			return "ERROR"

## Generates completed text for a .cfg file.
func build_class_text() -> String:
	var map_formats_str : String = ""
	for map_format in map_formats:
		map_formats_str += "{ \"format\": \"" + map_format.format + "\""
		if map_format.has("initialmap"):
			map_formats_str += ", \"initialmap\": \"" + map_format.initialmap + "\""
		if map_format != map_formats[-1]:
			map_formats_str += " },\n\t\t"
		else:
			map_formats_str += " }"
	
	var texture_exclusion_patterns_str := ""
	for tex_pattern in texture_exclusion_patterns:
		texture_exclusion_patterns_str += "\"" + tex_pattern + "\""
		if tex_pattern != texture_exclusion_patterns[-1]:
			texture_exclusion_patterns_str += ", "
	
	var fgd_filename_str : String = "\"" + fgd_files[0].fgd_name + ".fgd\""

	var brush_tags_str = parse_tags(brush_tags)
	var face_tags_str = parse_tags(face_tags)
	var uv_scale_str = parse_default_uv_scale(default_uv_scale)
	return _base_text % [
		game_name,
		map_formats_str,
		texture_exclusion_patterns_str,
		fgd_filename_str,
		entity_scale,
		brush_tags_str,
		face_tags_str,
		uv_scale_str
	]

## Converts brush, face, and attribute tags into a .cfg-usable String.
func parse_tags(tags: Array) -> String:
	var tags_str := ""
	for brush_tag in tags:
		if brush_tag.tag_match_type >= TrenchBroomTag.TagMatchType.size():
			continue
		tags_str += "{\n"
		tags_str += "\t\t\t\t\"name\": \"%s\",\n" % brush_tag.tag_name
		var attribs_str := ""
		for brush_tag_attrib in brush_tag.tag_attributes:
			attribs_str += "\"%s\"" % brush_tag_attrib
			if brush_tag_attrib != brush_tag.tag_attributes[-1]:
				attribs_str += ", "
		tags_str += "\t\t\t\t\"attribs\": [ %s ],\n" % attribs_str
		tags_str += "\t\t\t\t\"match\": \"%s\",\n" % get_match_key(brush_tag.tag_match_type)
		tags_str += "\t\t\t\t\"pattern\": \"%s\"" % brush_tag.tag_pattern
		if brush_tag.texture_name != "":
			tags_str += ",\n"
			tags_str += "\t\t\t\t\"material\": \"%s\"" % brush_tag.texture_name
		tags_str += "\n"
		tags_str += "\t\t\t}"
		if brush_tag != tags[-1]:
			tags_str += ","
	return tags_str

## Converts array of flags to .cfg String.
func parse_flags(flags: Array) -> String:
	var flags_str := ""
	for attrib_flag in flags:
		flags_str += "{\n"
		flags_str += "\t\t\t\t\"name\": \"%s\",\n" % attrib_flag.attrib_name
		flags_str += "\t\t\t\t\"description\": \"%s\"\n" % attrib_flag.attrib_description
		flags_str += "\t\t\t}"
		if attrib_flag != flags[-1]:
			flags_str += ","
	return flags_str

## Converts default uv scale vector to .cfg String.
func parse_default_uv_scale(texture_scale : Vector2) -> String:
	var entry_str = "\"scale\": [{x}, {y}]"
	return entry_str.format({
		"x": texture_scale.x,
		"y": texture_scale.y
	})

## Exports or updates a folder in the /games directory, with an icon, .cfg, and all accompanying FGDs.
func do_export_file() -> void:
	var folder = trenchbroom_games_folder
	if folder.is_empty():
		folder = QodotProjectConfig.get_setting(QodotProjectConfig.PROPERTY.TRENCHBROOM_GAMES_FOLDER)
	if folder.is_empty():
		print("Skipping export: No TrenchBroom games folder")
		return
	
	# Make sure FGD file is set
	if !fgd_files.size() or not fgd_files[0] is QodotFGDFile:
		print("Skipping export: No FGD file")
		return
	
	# Create config folder name by combining games folder with the game name as a directory
	var config_folder = folder + "/" + game_name
	var config_dir := DirAccess.open(config_folder)
	if config_dir == null:
		print("Couldn't open directory, creating...")
		var err := DirAccess.make_dir_recursive_absolute(config_folder)
		if err != OK:
			print("Skipping export: Failed to create directory")
			return
		config_dir = DirAccess.open(config_folder)
	print("Exporting TrenchBroom Game Config Folder to ", config_folder)
	
	# Icon
	var icon_path : String = config_folder + "/icon.png"
	print("Exporting icon to ", icon_path)
	var export_icon : Image = icon.get_image()
	export_icon.resize(32, 32, Image.INTERPOLATE_LANCZOS)
	export_icon.save_png(icon_path)
	
	# .cfg
	var export_config_file: Dictionary = {}
	export_config_file.game_name = game_name
	export_config_file.target_file = config_folder + "/GameConfig.cfg"
	print("Exporting TrenchBroom Game Config File to ", export_config_file.target_file)
	var file = FileAccess.open(export_config_file.target_file, FileAccess.WRITE)
	file.store_string(build_class_text())
	file = null # Official way to close files in GDscript 2
	
	# FGD
	var export_fgd : QodotFGDFile = fgd_files[0].duplicate()
	export_fgd.target_folder = config_folder
	export_fgd.do_export_file()
	print("Export complete\n")
