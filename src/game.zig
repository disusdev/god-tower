const std = @import("std");
const rl = @import("rl.zig");
const Character = @import("character.zig");
const Map = @import("map.zig");
const Box = @import("box2d.zig");
const tracy = @import("tracy");

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

    var world: Box.World = Box.World{
        .gravity = Box.Vec2{ .x = 0, .y = 0 },
        .iterations = 6,
        .accumulateImpulses = true,
        .warmStarting = true,
        .positionCorrection = true,
        .bodies = Box.World.BodyMap.init(allocator),
        .arbiters = Box.World.ArbiterMap.init(allocator),
    };

    var camera = rl.Camera2D {.offset = .{.x = SCREEN_WIDTH/2-16,.y = SCREEN_HEIGHT/2-16}, .rotation = 0, .target = .{.x = 0,.y = 0}, .zoom = 2.0 };

    hero = Character.hero();
    hero.position.x = 3 * 16 + 10;
    hero.position.y = 2 * 16 + 8;

    map = Map.room_1();
    const coll_rects = try Map.get_collision_rects(allocator);
    var objects= try Map.get_objects(allocator);

    var rect: rl.Rectangle = undefined;
    for (map.layers) |layer| {
        for (layer, 0..) |colls, x| {
            for (colls, 0..) |tile_id, y| {
                if (objects.getPtr(tile_id)) |obj| {
                    rect.width = obj.src_rect.width;
                    rect.height = obj.src_rect.height;
                    rect.x = @floatFromInt(y * 16);
                    rect.y = @floatFromInt(x * 16);
                    obj.body_handle = world.addBody(Box.Body.init(.{ .x = rect.x + rect.width / 2, .y = rect.y + rect.height / 2 - 3 }, .{ .x = rect.width, .y = rect.height }, obj.mass, 0.2));
                } else if (coll_rects.get(tile_id)) |value| {
                    rect.x = @floatFromInt(y * 16);
                    rect.x += value.x;
                    rect.y = @floatFromInt(x * 16);
                    rect.y += value.y;
                    rect.width = value.width;
                    rect.height = value.height;
                    _ = world.addBody(Box.Body.init(.{ .x = rect.x + rect.width / 2, .y = rect.y + rect.height / 2 }, .{ .x = rect.width, .y = rect.height }, std.math.inf(f32), 0.2));
                }
            }
        }
    }

    const hero_body = world.addBody(Box.Body.init(.{ .x = hero.position.x, .y = hero.position.y }, .{ .x = 8.0, .y = 6.0 }, 2.0, 0.2));

    camera.target = hero.position;

    while (!rl.WindowShouldClose()) {
        tracy.frameMark();

        const dt = rl.GetFrameTime();

        const wheel_move = rl.GetMouseWheelMove();
        if (@abs(wheel_move) > rl.EPSILON) {
            camera.zoom += wheel_move;
        }

        hero.update();

        if (world.bodies.getPtr(hero_body)) |body| {
            body.velocity.x += hero.velocity.x * dt;
            body.velocity.y += hero.velocity.y * dt;

            body.velocity.x += body.velocity.x * -0.2;
            body.velocity.y += body.velocity.y * -0.2;
        }

        {
            const zone = tracy.initZone(@src(), .{ .name = "Important work" });
            defer zone.deinit();

            
            var obj_iterator = objects.valueIterator();
            while(obj_iterator.next()) |obj| {
                if (!obj.empty) {
                    var position = rl.Vector2Zero();
                    if (world.bodies.getPtr(obj.body_handle)) |body| {
                        position.x = body.position.x - obj.src_rect.width / 2;
                        position.y = body.position.y - obj.src_rect.height / 2;

                        if (rl.CheckCollisionPointRec(rl.Vector2Add(hero.position, rl.Vector2Scale(hero.velocity, 0.3)), .{.x=position.x,.y=position.y,.width=obj.src_rect.width,.height=obj.src_rect.height}) and obj.movable) {
                            body.velocity.x = hero.velocity.x;
                            body.velocity.y = hero.velocity.y;
                        } else {
                            body.velocity.x = 0;
                            body.velocity.y = 0;
                        }
                    }

                    if (obj.iteractable and (rl.IsKeyPressed(rl.KEY_LEFT_CONTROL) or rl.IsKeyPressed(rl.KEY_RIGHT_CONTROL))) {
                        if (rl.CheckCollisionCircleRec(rl.Vector2Add(hero.position, rl.Vector2Scale(hero.velocity, 0.4)), 12, .{.x=position.x,.y=position.y,.width=obj.src_rect.width,.height=obj.src_rect.height})) {
                            obj.iteract();
                        }
                    }

                    if (obj.destroyable and (rl.IsKeyPressed(rl.KEY_LEFT_CONTROL) or rl.IsKeyPressed(rl.KEY_RIGHT_CONTROL))) {
                        if (rl.CheckCollisionCircleRec(rl.Vector2Add(hero.position, rl.Vector2Scale(hero.velocity, 0.4)), 12, .{.x=position.x,.y=position.y,.width=obj.src_rect.width,.height=obj.src_rect.height})) {
                            if (!obj.damage()) {
                                _ = world.bodies.orderedRemove(obj.body_handle);
                                _ = objects.remove(obj.id);
                            }
                        }
                    }
                }
            }
        }

        world.step(dt);

        if (world.bodies.get(hero_body)) |body| {
            hero.position.x = body.position.x;
            hero.position.y = body.position.y - 6;
        }

        camera.target = map.get_center();// rl.Vector2Lerp(camera.target, map.get_center(), dt * 2);
        camera.offset.x = @floatFromInt(@divFloor(rl.GetScreenWidth(),2)-16);
        camera.offset.y = @floatFromInt(@divFloor(rl.GetScreenHeight(),2)-16);
        camera.zoom = @floatFromInt(rl.GetScreenHeight());
        camera.zoom /= SCREEN_HEIGHT * 0.5;

        rl.BeginDrawing();
        rl.ClearBackground(rl.GetColor(0x140b28ff));

        rl.BeginMode2D(camera);

        map.draw();
        var obj_iterator = objects.valueIterator();
        while(obj_iterator.next()) |obj| {
            var position = rl.Vector2Zero();
            if (world.bodies.get(obj.body_handle)) |body| {
                position.x = body.position.x - obj.src_rect.width / 2;
                position.y = body.position.y - obj.src_rect.height / 2;
            }
            obj.draw(map.texture, position);
        }
        hero.draw();

        //rl.DrawLineV(hero.position, rl.Vector2Add(hero.position, hero.velocity), rl.GREEN);


        if (rl.IsKeyDown(rl.KEY_C)) {
            var body_iterator = world.bodies.iterator();
            while (body_iterator.next()) |body| {
                rl.DrawRectangleV(.{.x = body.value_ptr.position.x - body.value_ptr.width.x / 2, .y = body.value_ptr.position.y - body.value_ptr.width.y / 2}, .{.x = body.value_ptr.width.x, .y = body.value_ptr.width.y}, rl.GetColor(0x00FF0088));
            }
        }

        rl.EndMode2D();

        rl.EndDrawing();
    }

    rl.CloseWindow();
}