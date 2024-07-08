const std = @import("std");
const rl = @import("rl.zig");
const Box = @import("box2d.zig");
const RenderSystem = @import("render_system.zig");
const Entities = @import("entities.zig");
const ComponentSystem = @import("component_system.zig");
const Physics = @import("physics.zig");
const T = @This();

texture: rl.Texture2D = undefined,
layers: []const []const [] const usize = undefined,

edit_mode: bool = true,
edit_index: u64 = 0,
edit_entity: ?ComponentSystem.EntityHandle = null,

pub fn get_collision_rects(allocator: std.mem.Allocator) !std.AutoHashMap(usize, rl.Rectangle) {
    var map = std.AutoHashMap(usize, rl.Rectangle).init(allocator);
    try map.put(116, rl.Rectangle { .x = 14, .y = 0, .width = 2, .height = 16 });
    try map.put(114, rl.Rectangle { .x = 0, .y = 0, .width = 2, .height = 16 });
    try map.put(135, rl.Rectangle { .x = 0, .y = 12, .width = 16, .height = 4 });
    try map.put(95, rl.Rectangle { .x = 0, .y = 0, .width = 16, .height = 4 });

    try map.put(345, rl.Rectangle { .x = 2, .y = 11, .width = 12, .height = 5 });
    try map.put(347, rl.Rectangle { .x = 2, .y = 11, .width = 12, .height = 5 });

    try map.put(365, rl.Rectangle { .x = 0, .y = 0, .width = 16, .height = 16 });
    try map.put(367, rl.Rectangle { .x = 0, .y = 0, .width = 16, .height = 16 });
    try map.put(368, rl.Rectangle { .x = 0, .y = 0, .width = 16, .height = 16 });

    try map.put(357, rl.Rectangle { .x = 0, .y = 13, .width = 16, .height = 3 });
    try map.put(377, rl.Rectangle { .x = 0, .y = 0, .width = 16, .height = 16 });

    try map.put(333, rl.Rectangle { .x = 2, .y = 9, .width = 12, .height = 7 });
    try map.put(353, rl.Rectangle { .x = 0, .y = 0, .width = 16, .height = 16 });

    try map.put(380, rl.Rectangle { .x = 1, .y = 1, .width = 14, .height = 14 });
    try map.put(381, rl.Rectangle { .x = 1, .y = 1, .width = 14, .height = 14 });
    try map.put(382, rl.Rectangle { .x = 1, .y = 1, .width = 14, .height = 14 });
    return map;
}

const MapObject = struct {
    // iteractive object
    destroyable: bool = false,
    empty: bool = true,
    mass: f32 = 1.0,
    src_rect: rl.Rectangle = undefined,
    // position: rl.Vector2 = .{.x=0,.y=0},
    body_handle: Box.BodyHandle = undefined,
    iteractable: bool = false,
    id: usize = undefined,
    movable: bool = false,
    hp: i32 = 100,
    trigger: bool = false,

    pub fn iteract(self: *MapObject) void {
        switch (self.id) {
            380 => {
                self.src_rect.x = @mod((self.src_rect.x + 16), 48);
                // self.src_rect = rl.Rectangle { .x = 32, .y = 304, .width = 16, .height = 16 };
            },
            else => {}
        }
    }

    pub fn damage(self: *MapObject) bool {
        self.hp -= 50;
        return self.hp > 0;
    }

    pub fn draw(self: MapObject, texture: rl.Texture2D, position: rl.Vector2) void {
        rl.DrawTextureRec(texture, self.src_rect, position, rl.WHITE);
    }
};

// pub fn get_objects(allocator: std.mem.Allocator) !std.AutoHashMap(usize, MapObject) {
//     var map = std.AutoHashMap(usize, MapObject).init(allocator);

//     try map.put(358, .{});//std.math.inf(f32)
//     try map.put(378, .{.id = 378, .movable = false, .destroyable = true, .empty = false, .mass = std.math.inf(f32), .src_rect = rl.Rectangle { .x = 288, .y = 285, .width = 16, .height = 19 } });
//     try map.put(380, .{.id = 380, .iteractable = true, .empty = false, .mass = std.math.inf(f32), .src_rect = rl.Rectangle { .x = 0, .y = 304, .width = 16, .height = 16 } });

//     try map.put(328, .{.id = 328, .empty = false, .mass = std.math.inf(f32), .trigger = true, .src_rect = rl.Rectangle { .x = 128, .y = 256, .width = 16, .height = 16 } });

//     return map;
// }

pub fn draw(self: *T, camera: rl.Camera2D) !void {
    var rect: rl.Rectangle = undefined;
    for (self.layers) |layer| {
        for (layer, 0..) |colls, x| {
            for (colls, 0..) |tile_id, y| {
                //if (tile_id == 358 or
                //    tile_id == 378 or
                //    tile_id == 380) continue;
                rect.x = @floatFromInt(tile_id % 20);
                rect.y = @floatFromInt(tile_id / 20);
                rect.width = 16;
                rect.height = 16;
                rect.x *= rect.width;
                rect.y *= rect.height;
                var pos = rl.Vector2 { .x = @floatFromInt(y), .y = @floatFromInt(x) };
                pos.x *= rect.width;
                pos.y *= rect.height;
                rl.DrawTextureRec(self.texture, rect, pos, rl.WHITE);
            }
        }
    }
    
    if (rl.IsKeyPressed(rl.KEY_P)) {
        self.edit_mode = !self.edit_mode;
    }
    
    // @todo draw edit mode
    if (self.edit_mode) {
        if (rl.IsKeyPressed(rl.KEY_TAB)) {
            if (self.edit_entity == null) {
                self.edit_entity = try Entities.box();
            }
        }
        const mouse_pos = rl.GetMousePosition();
        var world_pos = rl.GetScreenToWorld2D(mouse_pos, camera);
        
        // 
        // rect.x = @floatFromInt(self.edit_index % 20);
        // rect.y = @floatFromInt(self.edit_index / 20);
        // rect.width = 16;
        // rect.height = 16;
        // 
        
        const x_left = @mod(world_pos.x, 8);
        const y_left = @mod(world_pos.y, 8);
        world_pos.x -= x_left;
        world_pos.y -= y_left;
        
        if (self.edit_entity) |entity| {
            entity.set_pos(world_pos.x, world_pos.y);
            if (entity.get_component(Physics.PhysicsBodyHandle)) |body| {
                body.set_pos(world_pos);
            }
        }
        
        if (rl.IsMouseButtonDown(0)) {
            self.edit_entity = null;
        }
        
        // rl.DrawTextureRec(self.texture, rect, world_pos, rl.WHITE);
    }
}

pub fn get_center(self: T) rl.Vector2 {
    return .{
        .x = @floatFromInt(self.layers[1][0].len * 8),
        .y = @floatFromInt(self.layers[1].len * 8)
    };
}

//pub fn spawn(self: T) !void {
//    var rect: rl.Rectangle = undefined;
//    for (self.layers) |layer| {
//        for (layer, 0..) |colls, x| {
//            for (colls, 0..) |tile_id, y| {
//                rect.x = @floatFromInt(tile_id % 20);
//                rect.y = @floatFromInt(tile_id / 20);
//                rect.width = 16;
//                rect.height = 16;
//                rect.x *= rect.width;
//                rect.y *= rect.height;
//                var pos = rl.Vector2 { .x = @floatFromInt(y), .y = @floatFromInt(x) };
//                pos.x *= rect.width;
//                pos.y *= rect.height;
//                
//                // rl.DrawTextureRec(self.texture, rect, pos, rl.WHITE);
//                _ = try RenderSystem.add_renderer(.{ .transform = .{ .position = pos }, .texture = self.texture, .pivot = .{.x = 0, .y = 0 }, .rect = rect});
//            }
//        }
//    }
//}

pub fn room_1() T {
    return T {
        .layers = &.{
            &.{},
            &.{// floor
                &.{118,135,135,135,135,135,117},
                &.{116,22,0,0,0,0,114},
                &.{116,42,0,0,0,0,114},
                &.{116,0,0,0,0,0,114},
                &.{116,0,0,0,0,0,114},
                &.{116,0,0,0,0,0,114},
                &.{116,0,0,0,0,0,114},
                &.{116,0,0,0,0,0,114},
                &.{116,0,0,0,0,0,114},
                &.{116,0,0,0,0,0,114},
                &.{116,0,0,0,1,2,114},
                &.{116,0,0,0,21,22,114},
                &.{116,0,0,0,41,42,114},
                &.{116,0,0,0,1,0,114},
                &.{116,0,0,0,0,0,114},
                &.{98,95,95,95,95,95,97},
            },
            &.{// wall
                //&.{60,60,347,333,348,60},
                //&.{60,60,367,353,368,60},
                //&.{60,345,60,60,60,345},
                //&.{60,365,60,60,60,365},
                //&.{60,345,60,60,60,345},
                //&.{60,365,60,60,60,365},
                //&.{60,357,357,357,358,357},
                //&.{60,377,377,377,378,377},
                //&.{60,345,60,60,60,345},
                //&.{60,365,60,60,60,365},
                //&.{60,345,60,60,60,345},
                //&.{60,365,60,60,60,365},
                //&.{60,345,60,60,60,345},
                //&.{60,365,60,60,60,365},
            },
            &.{// decor
                //&.{60,60,60,60,60,60},
                //&.{60,60,354,60,355,60},
                //&.{60,60,374,60,375,60},
                //&.{60,302,60,60,60,302},
                //&.{60,322,60,60,60,322},
                //&.{60,302,60,60,60,302},
                //&.{60,322,60,60,60,322},
                //&.{60,60,60,60,60,60},
                //&.{60,60,60,60,60,60},
                //&.{60,302,60,380,60,302},
                //&.{60,322,60,60,60,322},
                //&.{60,302,280,280,280,302},
                //&.{60,322,60,60,60,322},
                //&.{60,302,60,308,60,304},
                //&.{60,322,60,328,60,324},
            },
        },
        .texture = rl.LoadTexture("data/sprites/dungeon_tiles.png"),
    };
}