package main

import "core:fmt"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

MAX_LEVEL_CHARS :: 3
MAX_XP_CHARS :: 10
MAX_ENGRAM_CHARS :: 2
MAX_ENGRAM_LEVEL_INCREASE_CHARS :: 3
MAX_ENGRAM_MULTIPLIER_CHARS :: 4
MAX_ENGRAMS :: 100
DEFAULT_MAX_DINO_LEVEL :: 300
DEFAULT_MAX_DINO_XP :: 1000000
DEFAULT_MAX_PLAYER_LEVEL :: 600
DEFAULT_MAX_PLAYER_XP :: 10000000
DEFAULT_ENGRAMS_START :: 8
DEFAULT_ENGRAM_LEVEL_INCREASE :: 20
DEFAULT_ENGRAM_MULTIPLIER :: 1.25

Dino_Inputs :: enum {
	LEVEL,
	XP,
}

Player_Inputs :: enum {
	LEVEL,
	XP,
	ENGRAM,
	ENGRAM_GROWTH_THRESHOLD,
}

Number_Input :: struct {
	builder:    strings.Builder,
	max_len:    int,
	panel_size: rl.Rectangle,
	title:      cstring,
	value:      int,
}

Float_Input :: struct {
	builder:    strings.Builder,
	max_len:    int,
	panel_size: rl.Rectangle,
	title:      cstring,
	value:      f32,
}

Leveling_Data :: struct {
	dino_inputs:             [Dino_Inputs]Number_Input,
	dino_data:               [dynamic]int,
	player_inputs:           [Player_Inputs]Number_Input,
	player_data:             [dynamic]int,
	engram_multiplier_input: Float_Input,
	engram_data:             [dynamic]int,
}

number_input_make :: proc(
	title: cstring,
	default_value, max_len: int,
	size: rl.Rectangle,
) -> Number_Input {
	return(
		Number_Input {
			builder = strings.builder_make_none(),
			max_len = max_len,
			panel_size = size,
			title = title,
			value = default_value,
		} \
	)
}


number_input_update :: proc(self: ^Number_Input) -> bool {
	if !rl.CheckCollisionPointRec(rl.GetMousePosition(), self.panel_size) {
		return false
	}
	did_write := false
	len := strings.builder_len(self.builder)
	rl.SetMouseCursor(.IBEAM)
	key := rl.GetCharPressed()
	key_int := i32(key)
	for key_int >= 48 && key_int <= 57 && len < self.max_len {
		strings.write_rune(&self.builder, key)
		key = rl.GetCharPressed()
		key_int = i32(key)
		did_write = true
	}
	if rl.IsKeyPressed(.BACKSPACE) && len > 0 {
		old_len := len
		strings.pop_rune(&self.builder)
		did_write = true
	}

	if did_write {
		self.value = strconv.parse_int(strings.to_string(self.builder)) or_else 0
	}

	return true
}

number_input_draw :: proc(self: ^Number_Input) {
	rl.GuiDummyRec(self.panel_size, "")
	rl.GuiLabel(
		rl.Rectangle {
			self.panel_size.x,
			self.panel_size.y,
			self.panel_size.width,
			self.panel_size.height * 0.5,
		},
		self.title,
	)
	rl.GuiLabel(
		rl.Rectangle {
			self.panel_size.x,
			self.panel_size.y + self.panel_size.height * 0.5,
			self.panel_size.width,
			self.panel_size.height * 0.5,
		},
		rl.TextFormat("%d", self.value),
	)
}

float_input_make :: proc(
	title: cstring,
	default_value: f32,
	max_len: int,
	size: rl.Rectangle,
) -> Float_Input {
	return(
		Float_Input {
			builder = strings.builder_make_none(),
			max_len = max_len,
			panel_size = size,
			title = title,
			value = default_value,
		} \
	)
}

float_input_update :: proc(self: ^Float_Input) -> bool {
	if !rl.CheckCollisionPointRec(rl.GetMousePosition(), self.panel_size) {
		return false
	}
	did_write := false
	len := strings.builder_len(self.builder)
	rl.SetMouseCursor(.IBEAM)
	key := rl.GetCharPressed()
	key_int := i32(key)
	for key_int == 46 || (key_int >= 48 && key_int <= 57) && len < self.max_len {
		strings.write_rune(&self.builder, key)
		key = rl.GetCharPressed()
		key_int = i32(key)
		did_write = true
	}
	if rl.IsKeyPressed(.BACKSPACE) && len > 0 {
		old_len := len
		strings.pop_rune(&self.builder)
		did_write = true
	}

	if did_write {
		self.value = strconv.parse_f32(strings.to_string(self.builder)) or_else 1.0
	}

	return true
}

float_input_draw :: proc(self: ^Float_Input) {
	rl.GuiDummyRec(self.panel_size, "")
	rl.GuiLabel(
		rl.Rectangle {
			self.panel_size.x,
			self.panel_size.y,
			self.panel_size.width,
			self.panel_size.height * 0.5,
		},
		self.title,
	)
	rl.GuiLabel(
		rl.Rectangle {
			self.panel_size.x,
			self.panel_size.y + self.panel_size.height * 0.5,
			self.panel_size.width,
			self.panel_size.height * 0.5,
		},
		rl.TextFormat("%f", self.value),
	)
}


leveling_data_make :: proc() -> Leveling_Data {
	leveling_data := Leveling_Data{}
	leveling_data.dino_inputs[.LEVEL] = number_input_make(
		"Max Dino Level",
		DEFAULT_MAX_DINO_LEVEL,
		MAX_LEVEL_CHARS,
		{250, 5, 100, 40},
	)
	leveling_data.dino_inputs[.XP] = number_input_make(
		"Max Dino XP",
		DEFAULT_MAX_DINO_XP,
		MAX_LEVEL_CHARS,
		{400, 5, 100, 40},
	)
	leveling_data.dino_data = calculate_levels(DEFAULT_MAX_DINO_LEVEL, DEFAULT_MAX_DINO_XP)
	leveling_data.player_inputs[.LEVEL] = number_input_make(
		"Max Dino Level",
		DEFAULT_MAX_PLAYER_LEVEL,
		MAX_LEVEL_CHARS,
		{150, 5, 100, 40},
	)
	leveling_data.player_inputs[.XP] = number_input_make(
		"Max Dino XP",
		DEFAULT_MAX_PLAYER_XP,
		MAX_XP_CHARS,
		{300, 5, 100, 40},
	)
	leveling_data.player_inputs[.ENGRAM] = number_input_make(
		"Starting Engrams",
		DEFAULT_MAX_PLAYER_XP,
		MAX_ENGRAM_CHARS,
		{450, 5, 100, 40},
	)
	leveling_data.player_inputs[.ENGRAM_GROWTH_THRESHOLD] = number_input_make(
		"Levels Between Engram Increase",
		DEFAULT_ENGRAM_LEVEL_INCREASE,
		MAX_ENGRAM_LEVEL_INCREASE_CHARS,
		{600, 5, 100, 40},
	)
	leveling_data.player_data = calculate_levels(DEFAULT_MAX_PLAYER_LEVEL, DEFAULT_MAX_PLAYER_XP)
	leveling_data.engram_multiplier_input = float_input_make(
		"Engram Increase Multiplier",
		DEFAULT_ENGRAM_MULTIPLIER,
		MAX_ENGRAM_MULTIPLIER_CHARS,
		{850, 5, 100, 40},
	)
	leveling_data.engram_data = calculate_engrams(
		DEFAULT_MAX_PLAYER_LEVEL,
		DEFAULT_ENGRAMS_START,
		DEFAULT_ENGRAM_LEVEL_INCREASE,
		DEFAULT_ENGRAM_MULTIPLIER,
	)
	return leveling_data
}

leveling_data_max_xp :: proc(self: ^Leveling_Data, is_dino := true) -> int {
	if is_dino {
		return self.dino_inputs[.XP].value
	} else {
		return self.player_inputs[.XP].value
	}
}

leveling_data_max_level :: proc(self: ^Leveling_Data, is_dino := true) -> int {
	if is_dino {
		return len(self.dino_data)
	} else {
		return len(self.player_data)
	}
}

leveling_data_level_data :: proc(self: ^Leveling_Data, is_dino := true) -> ^[dynamic]int {
	if is_dino {
		return &self.dino_data
	} else {
		return &self.player_data
	}
}

leveling_data_update :: proc(self: ^Leveling_Data, is_dino := true) {
	use_ibeam := false
	if is_dino {
		for &dino_input in self.dino_inputs {
			if number_input_update(&dino_input) {
				use_ibeam = true
			}
		}
	} else {
		for &player_input in self.player_inputs {
			if number_input_update(&player_input) {
				use_ibeam = true
			}
		}
		if float_input_update(&self.engram_multiplier_input) {
			use_ibeam = true
		}
	}
	if use_ibeam {
		rl.SetMouseCursor(.IBEAM)
	} else {
		rl.SetMouseCursor(.DEFAULT)
	}
}

leveling_data_draw :: proc(self: ^Leveling_Data, is_dino := true) {
	if is_dino {
		for &dino_input in self.dino_inputs {
			number_input_draw(&dino_input)
		}
	} else {
		for &player_input in self.player_inputs {
			number_input_draw(&player_input)
		}
		float_input_draw(&self.engram_multiplier_input)
	}
}

leveling_data_calculate :: proc(self: ^Leveling_Data, is_dino := true) {
	if is_dino {
		clear(&self.dino_data)
		self.dino_data = calculate_levels(
			leveling_data_max_level(self, true),
			leveling_data_max_xp(self, true),
		)
	} else {
		clear(&self.player_data)
		self.player_data = calculate_levels(
			leveling_data_max_level(self, false),
			leveling_data_max_xp(self, false),
		)
		clear(&self.engram_data)
		self.engram_data = calculate_engrams(
			leveling_data_max_level(self, false),
			self.player_inputs[.ENGRAM].value,
			self.player_inputs[.ENGRAM_GROWTH_THRESHOLD].value,
			self.engram_multiplier_input.value,
		)
	}
}

main :: proc() {
	rl.InitWindow(1000, 1000, "Level Calculator")
	rl.SetTargetFPS(60)
	defer rl.CloseWindow()
	scale := rl.Vector2{}
	dino_mode := true

	leveling_data := leveling_data_make()

	{
		max_dino_level := leveling_data.dino_inputs[.LEVEL].value
		scale = calculate_scale(max_dino_level, leveling_data.dino_data[max_dino_level - 1])
	}

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.GRAY)

		leveling_data_update(&leveling_data, dino_mode)

		if rl.GuiButton({750, 960, 100, 40}, "Calculate Stats") {
			leveling_data_calculate(&leveling_data, dino_mode)
			scale = calculate_scale(
				leveling_data_max_level(&leveling_data, dino_mode),
				leveling_data_max_xp(&leveling_data, dino_mode),
			)
		}

		if rl.GuiButton({500, 960, 100, 40}, "Output to file") {
			write_file(&leveling_data)
		}

		if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.C) {
			copy_to_clipboard(&leveling_data)
		}

		if rl.GuiButton({250, 960, 100, 40}, "Swap Mode") {
			dino_mode = !dino_mode
			leveling_data_calculate(&leveling_data, dino_mode)
			scale = calculate_scale(
				leveling_data_max_level(&leveling_data, dino_mode),
				leveling_data_max_xp(&leveling_data, dino_mode),
			)
		}

		for level in 0 ..< leveling_data_max_level(&leveling_data, dino_mode) {
			rl.DrawCircleV(
				to_graph_pos(
					level,
					leveling_data_level_data(&leveling_data, dino_mode)[level],
					&scale,
				),
				2,
				rl.BLUE,
			)
		}

		draw_graph(
			leveling_data_max_level(&leveling_data, dino_mode),
			leveling_data_max_xp(&leveling_data, dino_mode),
		)

		leveling_data_draw(&leveling_data, dino_mode)
	}
}

draw_graph :: proc(max_level, max_xp: int) {
	rl.DrawLineEx({50, 950}, {50, 50}, 6, rl.BLACK)
	rl.DrawLineEx({50, 950}, {950, 950}, 6, rl.BLACK)
	for i := i32(50); i <= 950; i += 90 {
		rl.DrawLine(i, 50, i, 950, rl.BLACK)
		rl.DrawLine(50, i, 950, i, rl.BLACK)
	}
	rl.DrawRectangle(47, 947, 6, 6, rl.BLACK)
	rl.DrawText("0", 25, 975, 18, rl.BLACK)
	rl.DrawText(strings.clone_to_cstring(fmt.tprint(max_level)), 960, 945, 18, rl.BLACK)
	rl.DrawText(strings.clone_to_cstring(fmt.tprint(max_xp)), 25, 25, 18, rl.BLACK)
}

to_graph_pos :: proc(level, xp: int, scale: ^rl.Vector2) -> rl.Vector2 {
	return {50 + f32(level) * scale.x, f32(rl.GetScreenHeight() - 50) - f32(xp) * scale.y}
}

calculate_levels :: proc(max_level, max_xp: int) -> [dynamic]int {
	level_data := make([dynamic]int)
	reserve_dynamic_array(&level_data, max_level)
	exponential := linalg.log(f32(max_xp), f32(max_level))
	exponential_floor := linalg.floor(exponential * 100) / 100
	linear_mult :=
		(f32(max_xp) - linalg.pow(f32(max_level), exponential_floor)) / f32(max_level + 1)
	for level in 0 ..< max_level {
		append(
			&level_data,
			int(
				linalg.round(linalg.pow(f32(level), exponential_floor) + f32(level) * linear_mult),
			),
		)
	}
	return level_data
}

calculate_scale :: proc(max_level, max_xp: int) -> rl.Vector2 {
	return(
		rl.Vector2 {
			f32(rl.GetScreenWidth() - 100) / f32(max_level),
			f32(rl.GetScreenHeight() - 100) / f32(max_xp),
		} \
	)
}

calculate_engrams :: proc(
	max_level, start, levels_to_increase: int,
	increase_multiplier: f32,
) -> [dynamic]int {
	engram_data := make([dynamic]int)
	engrams := start
	for i in 0 ..< max_level {
		if i % levels_to_increase == 0 {
			engrams = int(linalg.round(f32(engrams) * increase_multiplier))
		}
		append(&engram_data, engrams)
	}
	return engram_data
}

copy_to_clipboard :: proc(level_data: ^Leveling_Data) {
	rl.TraceLog(.INFO, "Creating output data...")
	string_builder := strings.builder_make_none()
	defer strings.builder_destroy(&string_builder)
	strings.write_string(&string_builder, fmt.tprint("LevelExperienceRampOverrides=\n("))
	for xp, level in level_data.player_data {
		if level == len(level_data.player_data) - 1 {
			strings.write_string(
				&string_builder,
				fmt.tprintf("ExperiencePointsForLevel[%d]=%d", level, xp),
			)
		} else {
			strings.write_string(
				&string_builder,
				fmt.tprintf("ExperiencePointsForLevel[%d]=%d,", level, xp),
			)
		}
	}
	strings.write_string(&string_builder, ")\n")
	strings.write_string(&string_builder, fmt.tprint("LevelExperienceRampOverrides=\n("))
	for xp, level in level_data.dino_data {
		if level == len(level_data.dino_data) - 1 {
			strings.write_string(
				&string_builder,
				fmt.tprintf("ExperiencePointsForLevel[%d]=%d", level, xp),
			)
		} else {
			strings.write_string(
				&string_builder,
				fmt.tprintf("ExperiencePointsForLevel[%d]=%d,", level, xp),
			)
		}
	}
	strings.write_string(&string_builder, ")\n")

	for engrams in level_data.engram_data {
		strings.write_string(
			&string_builder,
			fmt.tprintfln("OverridePlayerLevelEngramPoints=%d", engrams),
		)
	}
	strings.write_string(
		&string_builder,
		fmt.tprintfln(
			"OverrideMaxExperiencePointsPlayer=%d",
			level_data.player_data[level_data.player_inputs[.LEVEL].value - 1] + 1,
		),
	)
	strings.write_string(
		&string_builder,
		fmt.tprintfln(
			"OverrideMaxExperiencePointsDino=%d",
			level_data.dino_data[level_data.dino_inputs[.LEVEL].value - 1] + 1,
		),
	)
	rl.SetClipboardText(strings.to_cstring(&string_builder))
	rl.TraceLog(.INFO, "Copied data to clipboard!")
}

write_file :: proc(level_data: ^Leveling_Data) {
	if os.exists("output.ini") {
		os.remove("output.ini")
	}
	file, file_err := os.open("output.ini", os.O_WRONLY | os.O_CREATE)
	if file_err != nil {
		return
	}
	rl.TraceLog(.INFO, "Creating output data...")
	fmt.fprint(file, "LevelExperienceRampOverrides=\n(")
	for xp, level in level_data.dino_data {
		if level == len(level_data.dino_data) - 1 {
			fmt.fprintf(file, "ExperiencePointsForLevel[%d]=%d", level, xp)
		} else {
			fmt.fprintf(file, "ExperiencePointsForLevel[%d]=%d,", level, xp)
		}
	}
	fmt.fprintln(file, ")")
	fmt.fprint(file, "LevelExperienceRampOverrides=\n(")
	for xp, level in level_data.player_data {
		if level == len(level_data.player_data) - 1 {
			fmt.fprintf(file, "ExperiencePointsForLevel[%d]=%d", level, xp)
		} else {
			fmt.fprintf(file, "ExperiencePointsForLevel[%d]=%d,", level, xp)
		}
	}
	fmt.fprintln(file, ")")
	for engrams in level_data.engram_data {
		fmt.fprintfln(file, "OverridePlayerLevelEngramPoints=%d", engrams)
	}
	fmt.fprintfln(
		file,
		"OverrideMaxExperiencePointsPlayer=%d",
		level_data.player_data[level_data.player_inputs[.LEVEL].value - 1] + 1,
	)
	fmt.fprintfln(
		file,
		"OverrideMaxExperiencePointsDino=%d",
		level_data.dino_data[level_data.dino_inputs[.LEVEL].value - 1] + 1,
	)
	os.flush(file)
	os.close(file)
	rl.TraceLog(.INFO, "Wrote data to output.ini!")
}
