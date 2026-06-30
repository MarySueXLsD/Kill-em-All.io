require engine.core
require scripts/das/core/constants
require scripts/das/core/iso_math
require scripts/das/core/game_state

module world_terrain public

enum GrassOverlayKind {
    None = 0,
    Interior = 1,
    Edge = 2,
    Corner = 3,
}

struct GrassOverlayChoice {
    kind : GrassOverlayKind
    dir : int
}

struct A5Pick {
    gx : int
    gy : int
    priority : int
}

var private a1Textures : array<TextureId>
var private a2Textures : array<TextureId>
var private a3Textures : array<TextureId>
var private a4Textures : array<TextureId>
var private a5Textures : array<TextureId>
var private e1Textures : array<TextureId>
var public grassCells : array<bool>
var public a5Cells : array<bool>
var public roadCells : array<bool>
var private mapCullResX : int = -1
var private mapCullBounds : VisibleGridBounds
var private mapCullBoundsValid : bool = false
var private mapCellNodes : array<NodeId>
var private mapCellVisible : array<bool>


def grass_cell_index(gx, gy : int) : int {
    return gy * activeMapWidth + gx
}


def is_outside_world_cell(gx, gy : int) : bool {
    return gx < 0 || gy < 0 || gx >= activeMapWidth || gy >= activeMapHeight
}


def is_outside_grid_cell(gx, gy : int) : bool {
    return gx < activeGridMinX || gy < activeGridMinY || gx >= activeGridMinX + activeGridWidth || gy >= activeGridMinY + activeGridHeight
}


def is_grass_cell(gx, gy : int) : bool {
    if (is_outside_grid_cell(gx, gy)) {
        return false
    }
    if (is_outside_world_cell(gx, gy)) {
        return grass_noise(gx, gy) >= GROUND_GRASS_NOISE_THRESHOLD
    }
    let idx = grass_cell_index(gx, gy)
    if (idx < 0 || idx >= length(grassCells)) {
        return false
    }
    return grassCells[idx]
}


def public is_grass_at(gx, gy : int) : bool {
    return is_grass_cell(gx, gy)
}


def grid_hash(a, b : int) : int {
    var h = a * 92837111 + b * 689287499
    if (h < 0) {
        h = -h
    }
    return h
}


def grass_noise(gx, gy : int) : float {
    let cx = gx / GROUND_GRASS_NOISE_PATCH
    let cy = gy / GROUND_GRASS_NOISE_PATCH
    return float(grid_hash(cx, cy) % 1000) / 1000.0
}


def generate_grass_mask() {
    let count = activeMapWidth * activeMapHeight
    grassCells |> resize(count)
    for (gy in range(activeMapHeight)) {
        for (gx in range(activeMapWidth)) {
            let spawnDx = abs(float(gx) - PLAYER_SPAWN_GRID_X)
            let spawnDy = abs(float(gy) - PLAYER_SPAWN_GRID_Y)
            let inSpawn = spawnDx <= float(GROUND_SPAWN_GRASS_RADIUS) && spawnDy <= float(GROUND_SPAWN_GRASS_RADIUS)
            let idx = grass_cell_index(gx, gy)
            if (inSpawn) {
                grassCells[idx] = true
            } else {
                grassCells[idx] = grass_noise(gx, gy) >= GROUND_GRASS_NOISE_THRESHOLD
            }
        }
    }
    cleanup_grass_mask()
}


def grass_neighbor_count(gx, gy : int) : int {
    var count = 0
    if (is_grass_cell(gx + 1, gy)) {
        count += 1
    }
    if (is_grass_cell(gx, gy + 1)) {
        count += 1
    }
    if (is_grass_cell(gx - 1, gy)) {
        count += 1
    }
    if (is_grass_cell(gx, gy - 1)) {
        count += 1
    }
    return count
}


def cleanup_grass_mask() {
    let count = activeMapWidth * activeMapHeight
    var keep : array<bool>
    keep |> resize(count)
    for (gy in range(activeMapHeight)) {
        for (gx in range(activeMapWidth)) {
            let idx = grass_cell_index(gx, gy)
            if (!grassCells[idx]) {
                keep[idx] = false
            } else {
                let spawnDx = abs(float(gx) - PLAYER_SPAWN_GRID_X)
                let spawnDy = abs(float(gy) - PLAYER_SPAWN_GRID_Y)
                let inSpawn = spawnDx <= float(GROUND_SPAWN_GRASS_RADIUS) && spawnDy <= float(GROUND_SPAWN_GRASS_RADIUS)
                keep[idx] = inSpawn || grass_neighbor_count(gx, gy) >= GROUND_GRASS_MIN_NEIGHBORS
            }
        }
    }
    for (i in range(count)) {
        grassCells[i] = keep[i]
    }
}


def mud_neighbor(gx, gy, dgx, dgy : int) : bool {
    let nx = gx + dgx
    let ny = gy + dgy
    if (is_outside_grid_cell(nx, ny)) {
        return true
    }
    return !is_grass_cell(nx, ny)
}


def pick_a1_direction(gx, gy : int) : int {
    return grid_hash(gx * 3 + 1, gy * 5 + 7) % 4
}


def pick_interior_grass_direction(gx, gy : int) : int {
    let cx = gx / GROUND_GRASS_NOISE_PATCH
    let cy = gy / GROUND_GRASS_NOISE_PATCH
    return grid_hash(cx, cy) % 4
}


def pick_a5_direction(gx, gy : int) : int {
    return grid_hash(gx * 53 + 9, gy * 59 + 21) % 4
}


def is_a5_at(gx, gy : int) : bool {
    if (gx < 0 || gy < 0 || gx >= activeMapWidth || gy >= activeMapHeight) {
        return false
    }
    let idx = grass_cell_index(gx, gy)
    if (idx < 0 || idx >= length(a5Cells)) {
        return false
    }
    return a5Cells[idx]
}


def should_use_a5_interior(gx, gy : int) : bool {
    return is_a5_at(gx, gy)
}


def is_in_spawn_grass(gx, gy : int) : bool {
    let spawnDx = abs(float(gx) - PLAYER_SPAWN_GRID_X)
    let spawnDy = abs(float(gy) - PLAYER_SPAWN_GRID_Y)
    return spawnDx <= float(GROUND_SPAWN_GRASS_RADIUS) && spawnDy <= float(GROUND_SPAWN_GRASS_RADIUS)
}


def vertical_road_wave(gx, gy : float) : float {
    let sum = gx + gy
    return sin(sum / GROUND_ROAD_WAVE_SCALE) * GROUND_ROAD_WAVE_AMPLITUDE
}


def horizontal_road_wave(gx, gy : float) : float {
    let diff = gx - gy
    return sin(diff / GROUND_ROAD_WAVE_SCALE) * GROUND_ROAD_WAVE_AMPLITUDE
}


def on_vertical_road(gx, gy : int) : bool {
    let diff = float(gx - gy)
    let wave = vertical_road_wave(float(gx), float(gy))
    return abs(diff - wave) <= GROUND_ROAD_HALF_WIDTH
}


def on_horizontal_road(gx, gy : int) : bool {
    let sum = float(gx + gy)
    let center = float(activeMapWidth + activeMapHeight - 2) * 0.5
    let wave = horizontal_road_wave(float(gx), float(gy))
    return abs(sum - center - wave) <= GROUND_ROAD_HALF_WIDTH
}


def public is_road_at(gx, gy : int) : bool {
    if (gx < 0 || gy < 0 || gx >= activeMapWidth || gy >= activeMapHeight) {
        return false
    }
    let idx = grass_cell_index(gx, gy)
    if (idx < 0 || idx >= length(roadCells)) {
        return false
    }
    return roadCells[idx]
}


def feet_grid_cell(feet : float2) : int2 {
    let grid = world_to_grid(feet.x, feet.y)
    return int2(int(grid.x + 0.5), int(grid.y + 0.5))
}


def public terrain_speed_multiplier_at(feet : float2) : float {
    let cell = feet_grid_cell(feet)
    if (is_outside_world_cell(cell.x, cell.y)) {
        return TERRAIN_SPEED_MUD_MULTIPLIER
    }
    if (is_road_at(cell.x, cell.y)) {
        return TERRAIN_SPEED_ROAD_MULTIPLIER
    }
    if (is_grass_at(cell.x, cell.y)) {
        return TERRAIN_SPEED_GRASS_MULTIPLIER
    }
    return TERRAIN_SPEED_MUD_MULTIPLIER
}


def public is_base_walkable_at(feet : float2) : bool {
    if (!isBaseLevel) {
        return true
    }
    let cell = feet_grid_cell(feet)
    if (is_outside_world_cell(cell.x, cell.y)) {
        return false
    }
    return !is_grass_at(cell.x, cell.y)
}


def public constrain_feet_move_for_terrain(from, to : float2) : float2 {
    var pos = constrain_feet_move_to_grid(from, to)
    if (!isBaseLevel) {
        return pos
    }
    if (is_base_walkable_at(pos)) {
        return pos
    }
    let slideX = constrain_feet_move_to_grid(from, float2(to.x, from.y))
    if (is_base_walkable_at(slideX)) {
        return slideX
    }
    let slideY = constrain_feet_move_to_grid(from, float2(from.x, to.y))
    if (is_base_walkable_at(slideY)) {
        return slideY
    }
    return from
}


def public terrain_adjusted_speed(baseSpeed : float; feet : float2) : float {
    return baseSpeed * terrain_speed_multiplier_at(feet)
}


def generate_road_mask() {
    let count = activeMapWidth * activeMapHeight
    roadCells |> resize(count)
    for (gy in range(activeMapHeight)) {
        for (gx in range(activeMapWidth)) {
            let idx = grass_cell_index(gx, gy)
            roadCells[idx] = on_vertical_road(gx, gy) || on_horizontal_road(gx, gy)
        }
    }
}


def pick_e1_direction(gx, gy : int) : int {
    return grid_hash(gx * 61 + 3, gy * 67 + 11) % 4
}


def mud_screen_offset(dgx, dgy : int) : float2 {
  // Map grid steps to screen axes: x=(dgx-dgy), y=(dgx+dgy); positive y is down on screen.
    return float2(float(dgx - dgy), float(dgx + dgy))
}


def accumulate_mud_screen_offset(v : float2; dgx, dgy : int; hasMud : bool) : float2 {
    if (!hasMud) {
        return v
    }
    let step = mud_screen_offset(dgx, dgy)
    return float2(v.x + step.x, v.y + step.y)
}


def mud_screen_vector(ul, ur, dl, dr, nw, ne, sw, se : bool) : float2 {
    var v = float2(0.0, 0.0)
    v = accumulate_mud_screen_offset(v, 0, 1, ul)
    v = accumulate_mud_screen_offset(v, 1, 0, ur)
    v = accumulate_mud_screen_offset(v, -1, 0, dl)
    v = accumulate_mud_screen_offset(v, 0, -1, dr)
    v = accumulate_mud_screen_offset(v, -1, 1, nw)
    v = accumulate_mud_screen_offset(v, 1, 1, ne)
    v = accumulate_mud_screen_offset(v, -1, -1, sw)
    v = accumulate_mud_screen_offset(v, 1, -1, se)
    return v
}


def pick_a3_from_mud_screen_vector(v : float2) : GrassOverlayChoice {
    // A3 E=top, N=left, S=right, W=down — direction grass meets mud on screen.
    let ax = abs(v.x)
    let ay = abs(v.y)
    if (ax > ay) {
        if (v.x < 0.0) {
            return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_N)
        }
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_S)
    }
    if (v.y < 0.0) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_W)
    }
    return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_E)
}


def pick_a4_from_mud_screen_vector(v : float2) : GrassOverlayChoice {
    // A4 E=top-left, N=bottom-left, S=top-right, W=bottom-right grass in tile.
    let grassX = -v.x
    let grassY = -v.y
    if (grassX <= 0.0 && grassY <= 0.0) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_W)
    }
    if (grassX <= 0.0 && grassY > 0.0) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_S)
    }
    if (grassX > 0.0 && grassY <= 0.0) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_N)
    }
    return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_E)
}


def pick_a3_for_opening_grass(grassUl, grassUr, grassDl, grassDr : bool) : GrassOverlayChoice {
    // Grass connects from one side; fringe faces the mud wrap (A3 E=top, N=left, S=right, W=down).
    if (grassDr) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_N)
    }
    if (grassUl) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_S)
    }
    if (grassUr) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_E)
    }
    if (grassDl) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_W)
    }
    return GrassOverlayChoice(kind = GrassOverlayKind.Interior, dir = GROUND_DIR_S)
}


def pick_fringe_overlay(
    gx, gy : int;
    ul, ur, dl, dr, nw, ne, sw, se : bool;
    interiorDir : int;
    interiorOnlyWhenIsolated : bool
) : GrassOverlayChoice {
    let mudTop = ul && ur
    let mudBottom = dl && dr
    let mudLeft = ul && dl
    let mudRight = ur && dr
    var mudCount = 0
    if (ul) {
        mudCount += 1
    }
    if (ur) {
        mudCount += 1
    }
    if (dl) {
        mudCount += 1
    }
    if (dr) {
        mudCount += 1
    }
    if (ul && dr && !ur && !dl) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_E)
    }
    if (ur && dl && !ul && !dr) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_S)
    }
    let mudVec = mud_screen_vector(ul, ur, dl, dr, nw, ne, sw, se)
    let isInteriorVec = abs(mudVec.x) < 0.001 && abs(mudVec.y) < 0.001
    if (interiorOnlyWhenIsolated) {
        if (mudCount == 0 && isInteriorVec) {
            return GrassOverlayChoice(kind = GrassOverlayKind.Interior, dir = interiorDir)
        }
    } elif (isInteriorVec) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Interior, dir = interiorDir)
    }
    if (mudCount == 3) {
        return pick_a3_for_opening_grass(!ul, !ur, !dl, !dr)
    }
    if (mudTop && mudLeft) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_N)
    }
    if (mudTop && mudRight) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_E)
    }
    if (mudBottom && mudLeft) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_W)
    }
    if (mudBottom && mudRight) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_S)
    }
    if (mudTop) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_E)
    }
    if (mudBottom) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_W)
    }
    if (mudLeft) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_N)
    }
    if (mudRight) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Edge, dir = GROUND_DIR_S)
    }
    if (mudCount == 0) {
        if (nw) {
            return pick_a3_from_mud_screen_vector(mud_screen_offset(-1, 1))
        }
        if (ne) {
            return pick_a3_from_mud_screen_vector(mud_screen_offset(1, 1))
        }
        if (sw) {
            return pick_a3_from_mud_screen_vector(mud_screen_offset(-1, -1))
        }
        if (se) {
            return pick_a3_from_mud_screen_vector(mud_screen_offset(1, -1))
        }
    }
    if (ul) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_E)
    }
    if (ur) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_S)
    }
    if (dl) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_N)
    }
    if (dr) {
        return GrassOverlayChoice(kind = GrassOverlayKind.Corner, dir = GROUND_DIR_W)
    }
    return GrassOverlayChoice(kind = GrassOverlayKind.Interior, dir = interiorDir)
}


def pick_grass_overlay(gx, gy : int) : GrassOverlayChoice {
    if (!is_grass_cell(gx, gy)) {
        return GrassOverlayChoice(kind = GrassOverlayKind.None, dir = 0)
    }
    // Grid neighbors around the diamond top: UL=(0,+1), UR=(+1,0), DL=(-1,0), DR=(0,-1).
    let ul = mud_neighbor(gx, gy, 0, 1)
    let ur = mud_neighbor(gx, gy, 1, 0)
    let dl = mud_neighbor(gx, gy, -1, 0)
    let dr = mud_neighbor(gx, gy, 0, -1)
    let nw = mud_neighbor(gx, gy, -1, 1)
    let ne = mud_neighbor(gx, gy, 1, 1)
    let sw = mud_neighbor(gx, gy, -1, -1)
    let se = mud_neighbor(gx, gy, 1, -1)
    return pick_fringe_overlay(gx, gy, ul, ur, dl, dr, nw, ne, sw, se, pick_interior_grass_direction(gx, gy), false)
}


def has_a5_near(gx, gy, radius : int) : bool {
    for (dy in range(-radius, radius + 1)) {
        for (dx in range(-radius, radius + 1)) {
            if (dx == 0 && dy == 0) {
                continue
            }
            if (is_a5_at(gx + dx, gy + dy)) {
                return true
            }
        }
    }
    return false
}


def sort_a5_picks_by_priority(var picks : array<A5Pick>) {
    let n = length(picks)
    for (i in range(1, n)) {
        let key = picks[i]
        var j = i - 1
        while (j >= 0 && picks[j].priority > key.priority) {
            picks[j + 1] = picks[j]
            j -= 1
        }
        picks[j + 1] = key
    }
}


def generate_a5_mask() {
    let count = activeMapWidth * activeMapHeight
    a5Cells |> resize(count)
    for (i in range(count)) {
        a5Cells[i] = false
    }
    var picks : array<A5Pick>
    for (gy in range(activeMapHeight)) {
        for (gx in range(activeMapWidth)) {
            if (pick_grass_overlay(gx, gy).kind != GrassOverlayKind.Interior) {
                continue
            }
            let roll = float(grid_hash(gx * 23 + 7, gy * 29 + 3) % 10000) / 10000.0
            if (roll >= GROUND_A5_CANDIDATE_CHANCE) {
                continue
            }
            push(picks, A5Pick(
                gx = gx,
                gy = gy,
                priority = grid_hash(gx * 41 + 13, gy * 43 + 19)
            ))
        }
    }
    sort_a5_picks_by_priority(picks)
    for (pick in picks) {
        if (has_a5_near(pick.gx, pick.gy, GROUND_A5_MIN_SPACING)) {
            continue
        }
        a5Cells[grass_cell_index(pick.gx, pick.gy)] = true
    }
}


