const std = @import("std");
const rl = @import("rl.zig");
const Character = @import("character.zig");
const Map = @import("map.zig");
const Box = @import("box2d.zig");
const tracy = @import("tracy");
const physics = @import("physics.zig");

const print = std.debug.print;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var hero: Character = undefined;
var map: Map = undefined;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

pub fn main() !void {
    tracy.setThreadName("Main");
    defer tracy.message("Graceful main thread exit");

    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT | rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "game");

    physics.init(allocator);

    var camera = rl.Camera2D {.offset = .{.x = SCREEN_WIDTH/2-16,.y = SCREEN_HEIGHT/2-16}, .rotation = 0, .target = .{.x = 0,.y = 0}, .zoom = 2.0 };

    const weapons_tex = rl.LoadTexture("data/sprites/weapons.png");
    defer rl.UnloadTexture(weapons_tex);

    hero = Character.hero(3 * 16 + 10, 2 * 16 + 8);
    
    hero.weapon = Character.Weapon.init(.{.x=0,.y=2}, &hero, weapons_tex, rl.Rectangle{.x=6,.y=9,.width=7,.height=16}, .{.x=3, .y=12});
    
    var enemies = std.ArrayList(Character).init(allocator);
    defer enemies.deinit();
    
    try enemies.append(Character.slime(3 * 16 + 10, 10 * 16 + 8));
    try enemies.append(Character.slime(4 * 16 + 10 - 4, 11 * 16 + 8 - 4));
    try enemies.append(Character.slime(2 * 16 + 10 + 4, 11 * 16 + 8 - 4));

    map = Map.room_1();
    const coll_rects = try Map.get_collision_rects(allocator);
    var objects = try Map.get_objects(allocator);

    var rect: rl.Rectangle = undefined;
    for (map.layers) |layer| {
        for (layer, 0..) |colls, x| {
            for (colls, 0..) |tile_id, y| {
                if (objects.getPtr(tile_id)) |obj| {
                    rect.width = obj.src_rect.width;
                    rect.height = obj.src_rect.height;
                    rect.x = @floatFromInt(y * 16);
                    rect.y = @floatFromInt(x * 16);
                    obj.body_handle = physics.world.addBody(Box.Body.init(.{ .x = rect.x + rect.width / 2, .y = rect.y + rect.height / 2 - 3 }, .{ .x = rect.width, .y = rect.height }, obj.mass, 0.2));
                } else if (coll_rects.get(tile_id)) |value| {
                    rect.x = @floatFromInt(y * 16);
                    rect.x += value.x;
                    rect.y = @floatFromInt(x * 16);
                    rect.y += value.y;
                    rect.width = value.width;
                    rect.height = value.height;
                    _ = physics.world.addBody(Box.Body.init(.{ .x = rect.x + rect.width / 2, .y = rect.y + rect.height / 2 }, .{ .x = rect.width, .y = rect.height }, std.math.inf(f32), 0.2));
                }
            }
        }
    }
    
    camera.target = physics.get_pos(hero.body);

    while (!rl.WindowShouldClose()) {
        tracy.frameMark();

        const dt = rl.GetFrameTime();

        const wheel_move = rl.GetMouseWheelMove();
        if (@abs(wheel_move) > rl.EPSILON) {
            camera.zoom += wheel_move;
        }

        hero.update(dt, enemies.items);
        
        // hero.weapon.?.rot += 1;

        physics.step(dt);

        camera.target = map.get_center();// rl.Vector2Lerp(camera.target, map.get_center(), dt * 2);
        camera.offset.x = @floatFromInt(@divFloor(rl.GetScreenWidth(),2)-16);
        camera.offset.y = @floatFromInt(@divFloor(rl.GetScreenHeight(),2)-16);
        camera.zoom = @floatFromInt(rl.GetScreenHeight());
        camera.zoom /= SCREEN_HEIGHT * 0.5;

        rl.BeginDrawing();
        rl.ClearBackground(rl.GetColor(0x140b28ff));
        
        //const texts = std.fmt.allocPrint(allocator, "src: {f}", .{hero.attack_src_angle});
        //rl.DrawText("", 20, 20, , 24, rl.BLACK);
        //const textd = std.fmt.allocPrint(allocator, "dst: {f}", .{hero.attack_dst_angle});
        //rl.DrawText("", 20, 40, , 24, rl.BLACK);

        rl.BeginMode2D(camera);

        map.draw();
        var obj_iterator = objects.valueIterator();
        while(obj_iterator.next()) |obj| {
            var position = physics.get_pos(obj.body_handle);
            position.x = position.x - obj.src_rect.width / 2;
            position.y = position.y - obj.src_rect.height / 2;
            obj.draw(map.texture, position);
        }
        
        for (enemies.items) |*enemy| {
            enemy.draw();
        }
        
        hero.draw();
        

        if (rl.IsKeyDown(rl.KEY_C)) {
            var body_iterator = physics.world.bodies.iterator();
            while (body_iterator.next()) |body| {
                rl.DrawRectangleV(.{.x = body.value_ptr.position.x - body.value_ptr.width.x / 2, .y = body.value_ptr.position.y - body.value_ptr.width.y / 2}, .{.x = body.value_ptr.width.x, .y = body.value_ptr.width.y}, rl.GetColor(0x00FF0088));
            }
        }

        rl.EndMode2D();

        rl.EndDrawing();
    }

    rl.CloseWindow();
}