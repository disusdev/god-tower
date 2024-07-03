const std = @import("std");
const rl = @import("rl.zig");
const Character = @import("character.zig");

const Transform = struct {
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

    pub fn draw(self: Renderer) void {
        rl.DrawTexturePro(self.texture,
                          self.rect,
                          rl.Rectangle {
                            .x = self.transform.position.x,
                            .y = self.transform.position.y,
                            .width = self.rect.width,
                            .height = self.rect.height
                          },
                          self.pivot,
                          self.transform.rotation,
                          self.tint);
    }
};

fn cmpRenderer(context: void, a: Renderer, b: Renderer) bool {
    _ = context;
    if (a.depth < b.depth) {
      return true;
    } else {
      return false;
    }
}

pub const RendererHandle = u64;

pub var renderables: std.ArrayList(Renderer) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    renderables = std.ArrayList(Renderer).init(allocator);
}

pub fn add_renderer(renderer: Renderer) !RendererHandle {
    const handler: RendererHandle = renderables.items.len;
    try renderables.append(renderer);
    return handler;
}

pub fn draw() void {
    std.mem.sort(Renderer, renderables.items, {}, cmpRenderer);
    for (renderables.items) |renderer| {
        renderer.draw();
    }
}

pub fn get_renderer(handler: RendererHandle) *Renderer {
    return &renderables.items[handler];
}