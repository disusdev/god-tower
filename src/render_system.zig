const std = @import("std");
const rl = @import("rl.zig");
const ComponentSystem = @import("component_system.zig");

pub const Transform = struct {
    position: rl.Vector2 = rl.Vector2Zero(),
    rotation: f32 = 0.0,
};

pub const Renderer = struct {
    texture: rl.Texture2D = undefined,
    rect: rl.Rectangle = undefined,
    pivot: rl.Vector2 = rl.Vector2Zero(),
    transform: Transform = Transform {},
    depth: f32 = 0.0,
    tint: rl.Color = rl.WHITE,
    entity: ?ComponentSystem.EntityHandle = null,

    pub fn draw(self: Renderer) !void {
        if (self.entity) |entity| {
            if (!entity.get_enable()) {
                return;
            }
        }
        var pos = self.transform.position;
        var rot = self.transform.rotation;
        if (self.entity) |entity| {
            pos = entity.get_pos();
            rot = entity.get_rot();
        }
        rl.DrawTexturePro(self.texture,
                          self.rect,
                          rl.Rectangle {
                            .x = pos.x,
                            .y = pos.y,
                            .width = @abs(self.rect.width),
                            .height = @abs(self.rect.height)
                          },
                          self.pivot,
                          rot,
                          self.tint);
        // var depth_str: [128:0]u8 = std.mem.zeroes([128:0]u8);
        // const depth_slice = try std.fmt.bufPrint(&depth_str, "{d:.3}", .{self.depth});
        // rl.DrawTextEx(rl.GetFontDefault(), @ptrCast(depth_slice.ptr), pos, 18, 0.5, rl.WHITE);
    }
};

fn cmpRenderer(context: void, a: Renderer, b: Renderer) bool {
    _ = context;
    return a.depth < b.depth;
}

pub const RendererHandle = struct {
    id: u64,
    pub fn set_rect(self: RendererHandle, rect: rl.Rectangle) void {
        renderables.items[self.id].rect = rect;
    }
    pub fn draw(self: RendererHandle) void {
        renderables.items[self.id].draw();
    }
    pub fn get_rect(self: RendererHandle) rl.Rectangle {
        return renderables.items[self.id].rect;
    }
    pub fn set_pos(self: RendererHandle, pos: rl.Vector2) void {
        renderables.items[self.id].transform.position = pos;
    }
    pub fn set_rot(self: RendererHandle, rot: f32) void {
        renderables.items[self.id].transform.rotation = rot;
    }
    pub fn add_entity(self: RendererHandle, entity: ComponentSystem.EntityHandle) void {
        renderables.items[self.id].entity = entity;
    }
};

pub var gallocator: std.mem.Allocator = undefined;
pub var renderables: std.ArrayList(Renderer) = undefined;
pub var arena: std.heap.ArenaAllocator = undefined;
pub var arena_allocator: std.mem.Allocator = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    gallocator = allocator;
    arena = std.heap.ArenaAllocator.init(gallocator);
    arena_allocator = arena.allocator();
    renderables = std.ArrayList(Renderer).init(allocator);
}

pub fn add_renderer(renderer: Renderer) !RendererHandle {
    try renderables.append(renderer);
    return .{ .id = renderables.items.len - 1 };
}

pub fn draw(world_top: f32, world_bottom: f32) !void {    
    for (renderables.items) |*renderer| {
        if (renderer.entity) |entity| {
            renderer.depth = rl.RLerp(world_top, world_bottom, entity.get_pos().y);
        } else {
            renderer.depth = rl.RLerp(world_top, world_bottom, renderer.transform.position.y);
        }
    }

    var to_draw = std.ArrayList(Renderer).init(arena_allocator);
    try to_draw.appendSlice(renderables.items);

    if (!std.sort.isSorted(Renderer, to_draw.items, {}, cmpRenderer)) {
        std.mem.sortUnstable(Renderer, to_draw.items, {}, cmpRenderer);
    }

    for (to_draw.items) |renderer| {
        try renderer.draw();
    }
}