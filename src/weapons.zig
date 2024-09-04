const std = @import("std");
const rl = @import("rl.zig");

const RenderSystem = @import("render_system.zig");
const ComponentSystem = @import("component_system.zig");

pub var wepons_texture: rl.Texture2D = undefined;

pub fn init() void {
    wepons_texture = rl.LoadTexture("data/sprites/weapons.png");
}

pub fn stick(slot: ?ComponentSystem.EntityHandle) !ComponentSystem.EntityHandle {
    const entity = try ComponentSystem.Entity.create(if (slot != null) slot.?.id else null);
    const renderer = try RenderSystem.add_renderer(.{
        .texture = wepons_texture,
        .rect = rl.Rectangle{.x=167,.y=107,.width=8,.height=17},
        .pivot = .{.x = 3, .y = 12 }
    });
    renderer.add_entity(entity);
    entity.set_pos(0, -6);
    entity.add_component(RenderSystem.RendererHandle, renderer);
    return entity;
}

pub fn sword(slot: ?ComponentSystem.EntityHandle) !ComponentSystem.EntityHandle {
    const entity = try ComponentSystem.Entity.create(if (slot != null) slot.?.id else null);
    const renderer = try RenderSystem.add_renderer(.{ .texture = wepons_texture, .rect = rl.Rectangle{.x=6,.y=9,.width=7,.height=16}, .pivot = .{.x = 3, .y = 12 }});
    renderer.add_entity(entity);
    entity.set_pos(0, -6);
    entity.add_component(RenderSystem.RendererHandle, renderer);
    return entity;
}