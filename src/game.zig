const std = @import("std");
const rl = @import("rl.zig");
const Character = @import("character.zig");
const Map = @import("map.zig");
const Box = @import("box2d.zig");
const tracy = @import("tracy");
const Physics = @import("physics.zig");
const RenderSystem = @import("render_system.zig");
const ComponentSystem = @import("component_system.zig");
const AbilitySystem = @import("ability_system.zig");
const AnimationSystem = @import("animation_system.zig");
const Weapons = @import("weapons.zig");
const Entities = @import("entities.zig");

const print = std.debug.print;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var map: Map = undefined;

const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 800;

pub fn main() !void {
    tracy.setThreadName("Main");
    defer tracy.message("Graceful main thread exit");

    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT | rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "game");

    Physics.init(allocator);
    RenderSystem.init(allocator);
    ComponentSystem.init(allocator);
    AnimationSystem.init(allocator);
    AbilitySystem.init(allocator);
    Entities.init();
    Weapons.init();
    
    _ = try ComponentSystem.add_new_state();

    var camera = rl.Camera2D {
        .offset = .{
            .x = SCREEN_WIDTH / 2 - 16,
            .y = SCREEN_HEIGHT / 2 - 16
        },
        .rotation = 0,
        .target = .{ .x = 0, .y = 0 },
        .zoom = 2.0
    };

    _ = try Entities.enemy(3 * 16 + 10, 10 * 16 + 8);
    _ = try Entities.enemy(4 * 16 + 10 - 4, 11 * 16 + 8 - 4);
    _ = try Entities.enemy(2 * 16 + 10 + 4, 11 * 16 + 8 - 4);

    map = Map.room_1();
    const coll_rects = try Map.get_collision_rects(allocator);

    var rect: rl.Rectangle = undefined;
    for (map.layers) |layer| {
        for (layer, 0..) |colls, x| {
            for (colls, 0..) |tile_id, y| {
                if (coll_rects.get(tile_id)) |value| {
                    rect.x = @floatFromInt(y * 16);
                    rect.x += value.x;
                    rect.y = @floatFromInt(x * 16);
                    rect.y += value.y;
                    rect.width = value.width;
                    rect.height = value.height;
                    var tile_coll = try ComponentSystem.Entity.create(null);
                    const physics_handle = Physics.create_body(tile_coll,
                                                               rect.x + rect.width / 2,
                                                               rect.y + rect.height / 2,
                                                               rect.width,
                                                               rect.height,
                                                               std.math.inf(f32),
                                                               0.2, 0.0);
                    tile_coll.add_component(Physics.PhysicsBodyHandle, physics_handle);
                }
            }
        }
    }

    const gero_entity_handle = try Entities.hero(56, 40);
    
    if (gero_entity_handle.get_child()) |weapon_slot| {
        const entity_handle = try Weapons.stick(weapon_slot);
        if (weapon_slot.get_component(AbilitySystem.AttackAbilityHandle)) |attack| {
            attack.set_weapon(entity_handle);
        }
    }
    
    _ = try Weapons.sword(null);
    
    var timer: f64 = 0.0;
    var current: f64 = 0.0;
    var accumulator: f64 = 0.0;
    var fresh: f64 = 0.0;
    var delta: f64 = 0.0;
    
    const FIXED_TIME = 1.0 / 60.0;

    while (!rl.WindowShouldClose()) {
        tracy.frameMark();
        
        fresh = rl.GetTime();
        delta = fresh - current;
        
        current = fresh;
        accumulator += delta;
        
        const dt = rl.GetFrameTime();

        const wheel_move = rl.GetMouseWheelMove();
        if (@abs(wheel_move) > rl.EPSILON) {
            camera.zoom += wheel_move;
        }

        AbilitySystem.update(camera, dt);
        AnimationSystem.update(dt);

        while (accumulator >= FIXED_TIME) {
            if (!map.edit_mode) {
                Physics.step(dt);
            }
        
            accumulator -= FIXED_TIME;
            timer += FIXED_TIME;
        }

        camera.target = map.get_center();
        camera.offset.x = @floatFromInt(@divFloor(rl.GetScreenWidth(), 2) - 16);
        camera.offset.y = @floatFromInt(@divFloor(rl.GetScreenHeight(), 2) - 16);
        camera.zoom = @floatFromInt(rl.GetScreenHeight());
        camera.zoom /= SCREEN_HEIGHT * 0.5;

        rl.BeginDrawing();
        rl.ClearBackground(rl.GetColor(0x140b28ff));
        
        rl.BeginMode2D(camera);

        try map.draw(camera);

        const world_top = rl.GetScreenToWorld2D(.{ .x = 0, .y = 0 }, camera);
        const world_bottom = rl.GetScreenToWorld2D(.{ .x = 0, .y = @floatFromInt(rl.GetScreenHeight()) }, camera);
        try RenderSystem.draw(world_top.y, world_bottom.y);

        if (rl.IsKeyDown(rl.KEY_C)) {
            var body_iterator = Physics.world.bodies.iterator();
            while (body_iterator.next()) |body| {
                rl.DrawRectangleV(.{
                    .x = body.value_ptr.position.x - body.value_ptr.width.x / 2,
                    .y = body.value_ptr.position.y - body.value_ptr.width.y / 2
                }, .{
                    .x = body.value_ptr.width.x,
                    .y = body.value_ptr.width.y
                }, rl.GetColor(0x00FF0088));
            }
        }

        try AbilitySystem.draw();
        rl.EndMode2D();

        rl.EndDrawing();
    }

    rl.CloseWindow();
}