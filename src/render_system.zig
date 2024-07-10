const std = @import("std");
const rl = @import("rl.zig");
const ComponentSystem = @import("component_system.zig");

pub const Transform = struct {
    position: rl.Vector2 = rl.Vector2Zero(),
    rotation: f32 = 0.0,
};

fn HexToVector4(hexValue: u32) rl.Vector4 {
    var color: rl.Vector4 = undefined;

    color.x = @floatFromInt((hexValue >> 24) & 0xFF);
    color.x = color.x / 255.0;
    
    color.y = @floatFromInt((hexValue >> 16) & 0xFF);
    color.y = color.y / 255.0;
    
    color.z = @floatFromInt((hexValue >> 8) & 0xFF);
    color.z = color.z / 255.0;
    
    color.w = @floatFromInt(hexValue & 0xFF);
    color.w = color.w / 255.0;

    return color;
}

fn in_palette(palette: std.ArrayList(rl.Color), col: rl.Color) bool {
    for (palette) |color| {
        if (std.mem.eql(rl.Color, color, col)) {
            return true;
        }
    }
    return false;
}

fn extract_palette(tex: rl.Texture2D, allocator: std.mem.Allocator) std.ArrayList(rl.Color) {
    var palette = std.ArrayList(rl.Color).init(allocator);
    
    const image = rl.GetTextureData(tex);
    defer rl.UnloadImage(image);
    const pixels = rl.LoadImageColors(image);
    defer rl.UnloadImagedata(pixels);
    
    for (pixels) |pixel| {
        if (!in_palette(palette, pixels[i])) {
            palette.append(pixels[i]);
        }
    }
    
    return palette;
}

pub const Renderer = struct {
    texture: rl.Texture2D = undefined,
    rect: rl.Rectangle = undefined,
    pivot: rl.Vector2 = rl.Vector2Zero(),
    transform: Transform = Transform {},
    depth: f32 = 0.0,
    tint: rl.Color = rl.WHITE,
    entity: ?ComponentSystem.EntityHandle = null,
    palette: [6] u32 = .{
        vinik_palette[3],
        vinik_palette[4],
        vinik_palette[5],
        vinik_palette[6],
        vinik_palette[7],
        vinik_palette[0]
    },
    
    // swap palette 

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
        
        var palette: [256] rl.Vector4 = undefined;
        for (0..256) |i| {
            palette[i] = HexToVector4(vinik_palette[i % vinik_palette.len]);
        }
        
        rl.SetShaderValueV(swap_shader,
                           rl.GetShaderLocation(swap_shader, "palette"),
                           &palette[0], rl.SHADER_UNIFORM_VEC4, 256);
        
        // for (0..self.palette.len) |i| {
        //     var uni_name: [128]u8 = std.mem.zeroes([128]u8);
        //     const slice = try std.fmt.bufPrint(&uni_name, "palette[{d}]", .{ i });
        //     const palete_id = rl.GetShaderLocation(swap_shader, slice.ptr);
        //     if (palete_id != -1) {
        //         const palette = HexToVector4(self.palette[i]);
        //         rl.SetShaderValue(swap_shader, palete_id, &palette, rl.SHADER_UNIFORM_VEC4);
        //     }
        // }
        
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

const vinik_palette: []const u32 = &.{
    0x00000000,
    0x6f6776FF,
    0x9a9a97FF,
    0xc5ccb8FF,
    0x8b5580FF,
    0xc38890FF,
    0xa593a5FF,
    0x666092FF,
    0x9a4f50FF,
    0xc28d75FF,
    0x7ca1c0FF,
    0x416aa3FF,
    0x8d6268FF,
    0xbe955cFF,
    0x68aca9FF,
    0x387080FF,
    0x6e6962FF,
    0x93a167FF,
    0x6eaa78FF,
    0x557064FF,
    0x9d9f7fFF,
    0x7e9e99FF,
    0x5d6872FF,
    0x433455FF,
};

pub var gallocator: std.mem.Allocator = undefined;
pub var renderables: std.ArrayList(Renderer) = undefined;
pub var arena: std.heap.ArenaAllocator = undefined;
pub var arena_allocator: std.mem.Allocator = undefined;
pub var swap_shader: rl.Shader = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    gallocator = allocator;
    arena = std.heap.ArenaAllocator.init(gallocator);
    arena_allocator = arena.allocator();
    renderables = std.ArrayList(Renderer).init(allocator);
    
    swap_shader = rl.LoadShader(0, "data/shaders/palette_swap.fs");
}

pub fn add_renderer(renderer: Renderer) !RendererHandle {
    try renderables.append(renderer);
    return .{ .id = renderables.items.len - 1 };
}

pub fn draw(world_top: f32, world_bottom: f32) !void {
    rl.BeginShaderMode(swap_shader);
    
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
    
    rl.EndShaderMode();
}