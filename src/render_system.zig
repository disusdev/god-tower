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
        if (!in_palette(palette, pixel)) {
            palette.append(pixel);
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
    palette_index: f32 = 0,
    palette_texture: ?rl.Texture2D = null,
    scale: f32 = 1.0,

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
        
        if (self.palette_texture) |tex| {
            rl.BeginShaderMode(swap_shader);
            
            rl.SetShaderValueTexture(swap_shader, paletteLoc, tex);
            
            const pal_size = [2]f32 {@floatFromInt(tex.width), @floatFromInt(tex.height)};
            const texelSize = [2]f32 { 1.0/pal_size[0], 1.0/pal_size[1] };
            rl.SetShaderValue(swap_shader, texelSizeLoc, &texelSize, rl.SHADER_UNIFORM_VEC2);
            
            const colorDivLoc = rl.GetShaderLocation(swap_shader, "colorDiv");
            const colorDiv: i32 = 8;
            rl.SetShaderValue(swap_shader, colorDivLoc, &colorDiv, rl.SHADER_UNIFORM_INT);
            
            rl.SetShaderValue(swap_shader, paletteIndexLoc, &self.palette_index, rl.SHADER_UNIFORM_FLOAT);
        }
        
        var pivot = self.pivot;
        pivot.x *= self.scale;
        pivot.y *= self.scale;
        
        rl.DrawTexturePro(self.texture,
                          self.rect,
                          rl.Rectangle {
                            .x = pos.x,
                            .y = pos.y,
                            .width = @abs(self.rect.width) * self.scale,
                            .height = @abs(self.rect.height) * self.scale
                          },
                          pivot,
                          rot,
                          self.tint);
        // var depth_str: [128:0]u8 = std.mem.zeroes([128:0]u8);
        // const depth_slice = try std.fmt.bufPrint(&depth_str, "{d:.3}", .{self.depth});
        // rl.DrawTextEx(rl.GetFontDefault(), @ptrCast(depth_slice.ptr), pos, 18, 0.5, rl.WHITE);
        
        rl.EndShaderMode();
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

var paletteLoc: i32 = undefined;
var texelSizeLoc: i32 = undefined;
var paletteIndexLoc: i32 = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    gallocator = allocator;
    arena = std.heap.ArenaAllocator.init(gallocator);
    arena_allocator = arena.allocator();
    renderables = std.ArrayList(Renderer).init(allocator);
    
    swap_shader = rl.LoadShader(0, "data/shaders/swap.fs");
    paletteLoc = rl.GetShaderLocation(swap_shader, "palette");
    texelSizeLoc = rl.GetShaderLocation(swap_shader, "texelSize");
    paletteIndexLoc = rl.GetShaderLocation(swap_shader, "paletteIndex");
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