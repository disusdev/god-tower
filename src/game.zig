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

// var hero: Character = undefined;
var map: Map = undefined;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

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

    var camera = rl.Camera2D {.offset = .{.x = SCREEN_WIDTH/2-16,.y = SCREEN_HEIGHT/2-16}, .rotation = 0, .target = .{.x = 0,.y = 0}, .zoom = 2.0 };

    // const weapons_tex = rl.LoadTexture("data/sprites/weapons.png");
    // defer rl.UnloadTexture(weapons_tex);

    // hero = try Character.hero2(3 * 16 + 10, 2 * 16 + 8);
    
    // hero.weapon = try Character.Weapon.init(.{.x=0,.y=2}, &hero, weapons_tex, rl.Rectangle{.x=6,.y=9,.width=7,.height=16}, .{.x=3, .y=18});
    
    // var enemies = std.ArrayList(Character).init(allocator);
    // defer enemies.deinit();
    
    // try enemies.append(try Character.hero2(3 * 16 + 10, 10 * 16 + 8));
    // try enemies.append(try Character.hero2(4 * 16 + 10 - 4, 11 * 16 + 8 - 4));
    // try enemies.append(try Character.hero2(2 * 16 + 10 + 4, 11 * 16 + 8 - 4));

    _ = try Entities.enemy(3 * 16 + 10, 10 * 16 + 8);
    _ = try Entities.enemy(4 * 16 + 10 - 4, 11 * 16 + 8 - 4);
    _ = try Entities.enemy(2 * 16 + 10 + 4, 11 * 16 + 8 - 4);

    map = Map.room_1();
    // try map.spawn();
    const coll_rects = try Map.get_collision_rects(allocator);
    // var objects = try Map.get_objects(allocator);

    var rect: rl.Rectangle = undefined;
    for (map.layers) |layer| {
        for (layer, 0..) |colls, x| {
            for (colls, 0..) |tile_id, y| {
                //if (objects.getPtr(tile_id)) |obj| {
                //    // Physics.
                //    // Physics.set_pos(obj.body, .{.x=@as(f32, @floatFromInt(y * 16)) + 8.0, .y=@as(f32, @floatFromInt(x * 16)) + 9.5});
                //} else
                if (coll_rects.get(tile_id)) |value| {
                    rect.x = @floatFromInt(y * 16);
                    rect.x += value.x;
                    rect.y = @floatFromInt(x * 16);
                    rect.y += value.y;
                    rect.width = value.width;
                    rect.height = value.height;
                    
                    var tile_coll = try ComponentSystem.Entity.create(null);
                    const physics_handle = Physics.create_body(tile_coll, rect.x + rect.width / 2,  rect.y + rect.height / 2, rect.width, rect.height, std.math.inf(f32), 0.2, 0.0);
                    tile_coll.add_component(Physics.PhysicsBodyHandle, physics_handle);
                }
            }
        }
    }

    const gero_entity_handle = try Entities.hero(56, 40);
    
    const weapon_slot_handle = try ComponentSystem.Entity.create(gero_entity_handle.id);
    
    const entity_handle = try Weapons.stick(weapon_slot_handle);
    
    const attack_handle = try AbilitySystem.add_attack(.{ .owner = gero_entity_handle, .weapon_slot = weapon_slot_handle, .weapon = entity_handle });
    weapon_slot_handle.add_component(AbilitySystem.AttackAbilityHandle, attack_handle);

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

        //hero.update(dt, enemies.items);
        // const coef = rl.Vector2DotProduct(.{.x=1,.y=0}, .{.x=@cos(hero.weapon.?.rot * rl.DEG2RAD),.y=@sin(hero.weapon.?.rot * rl.DEG2RAD)});
        // hero.weapon.?.coef = coef;

        AbilitySystem.update(camera, dt);
        AnimationSystem.update(dt);

        // for (enemies.items) |*enemy| {
        //     enemy.update_state(dt, enemies.items);
        // }
        
        // hero.weapon.?.rot += 1;

        // self.move.exec(self.*, .{.x=x_axis, .y=y_axis}, if(self.animator.state == .Attack) 0.5 else 1);
        {
            //var obj_iterator = objects.valueIterator();
            //while(obj_iterator.next()) |obj| {
            //    obj.move.exec(obj.*, .{.x=0, .y=0}, 0);
            //}
        }

        while (accumulator >= FIXED_TIME) {
            if (!map.edit_mode) {
                Physics.step(dt);
            }
        
            accumulator -= FIXED_TIME;
            timer += FIXED_TIME;
        }

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

        try map.draw(camera);
        // var obj_iterator = objects.valueIterator();
        // while(obj_iterator.next()) |obj| {
        //     var position = Physics.get_pos(obj.body);
        //     const size = Physics.get_size(obj.body);
        //     position.x = position.x - size.x / 2;
        //     position.y = position.y - size.y / 2;
        //     obj.draw();
        // }
        
        // for (enemies.items) |*enemy| {
        //     enemy.draw();
        // }
        
        // hero.draw();

        const world_top = rl.GetScreenToWorld2D(.{.x=0,.y=0}, camera);
        const world_bottom = rl.GetScreenToWorld2D(.{.x=0,.y=@floatFromInt(rl.GetScreenHeight())}, camera);
        try RenderSystem.draw(world_top.y, world_bottom.y);
        

        if (rl.IsKeyDown(rl.KEY_C)) {
            var body_iterator = Physics.world.bodies.iterator();
            while (body_iterator.next()) |body| {
                rl.DrawRectangleV(.{.x = body.value_ptr.position.x - body.value_ptr.width.x / 2, .y = body.value_ptr.position.y - body.value_ptr.width.y / 2}, .{.x = body.value_ptr.width.x, .y = body.value_ptr.width.y}, rl.GetColor(0x00FF0088));
            }
        }

        try AbilitySystem.draw();
        rl.EndMode2D();

        rl.EndDrawing();
    }

    rl.CloseWindow();
}