const std = @import("std");
const rl = @import("rl.zig");

const Physics = @import("physics.zig");
const RenderSystem = @import("render_system.zig");
const ComponentSystem = @import("component_system.zig");
const AbilitySystem = @import("ability_system.zig");
const AnimationSystem = @import("animation_system.zig");
const Animations = @import("animations.zig");

pub var dungeon_texture: rl.Texture2D = undefined;
pub var base_texture: rl.Texture2D = undefined;

pub fn init() void {
    dungeon_texture = rl.LoadTexture("data/sprites/dungeon_tiles.png");
    base_texture = rl.LoadTexture("data/sprites/base.png");
}

pub fn hero(x: f32, y: f32) !ComponentSystem.EntityHandle {
    var entity = try ComponentSystem.Entity.create(null);
    const renderer = try RenderSystem.add_renderer(.{
        .texture = base_texture,
        .pivot = .{ .x = 8, .y = 18 },
        .entity = entity,
    });
    const animator = try AnimationSystem.add_animator(.{
        .renderer = renderer
    });
    const body = Physics.create_body(entity, x, y, 8, 12, 2, 0.2, 8.0);
    const move = try AbilitySystem.add_move(.{
        .body = body
    });
    const controller = try AnimationSystem.AnimatorControllerHandle.create(.{
        .body = body,
        .animator = animator,
        .renderer = renderer,
    });
    //renderer.add_entity(entity);

    entity.add_component(Physics.PhysicsBodyHandle, body);
    entity.add_component(RenderSystem.RendererHandle, renderer);
    entity.add_component(AbilitySystem.MoveAbilityHandle, move);
    entity.add_component(AnimationSystem.AnimatorHandle, animator);    
    entity.add_component(AnimationSystem.AnimatorControllerHandle, controller);
    
    const weapon_slot = try ComponentSystem.Entity.create(entity.id);
    
    const attack_handle = try AbilitySystem.add_attack(.{
        .owner = entity,
        .weapon_slot = weapon_slot
    });
    weapon_slot.add_component(AbilitySystem.AttackAbilityHandle, attack_handle);
    
    return entity;
}

pub fn enemy(x: f32, y: f32) !ComponentSystem.EntityHandle {
    var entity = try ComponentSystem.Entity.create(null);
    const renderer = try RenderSystem.add_renderer(.{
        .texture = base_texture,
        .pivot = .{ .x = 8, .y = 18 },
        .entity = entity,
    });
    const animator = try AnimationSystem.add_animator(.{
        .renderer = renderer
    });
    const body = Physics.create_body(entity, x, y, 8, 12, 2, 0.2, 8.0);
    const brain = AbilitySystem.BrainHandle.create(.{
        .body = body
    });
    const controller = try AnimationSystem.AnimatorControllerHandle.create(.{
        .body = body,
        .animator = animator,
        .renderer = renderer,
    });
    //renderer.add_entity(entity);

    entity.add_component(Physics.PhysicsBodyHandle, body);
    entity.add_component(RenderSystem.RendererHandle, renderer);
    entity.add_component(AbilitySystem.BrainHandle, brain);
    entity.add_component(AnimationSystem.AnimatorHandle, animator);    
    entity.add_component(AnimationSystem.AnimatorControllerHandle, controller);
    
    return entity;
}

pub fn box() !ComponentSystem.EntityHandle {
    var entity_handle = try ComponentSystem.Entity.create(null);
    
    const rendr_handle = try RenderSystem.add_renderer(.{
        .texture = dungeon_texture,
        .pivot = .{ .x = 8, .y = 11 },
        .rect = .{ .x = 288, .y = 285, .width = 16, .height = 19 },
        .entity = entity_handle,
        // .enable = false,
    });
    const physics_handle = Physics.create_body(entity_handle, 56, 80, 16, 16, 2, 0.2, 10.0);
    
    entity_handle.add_component(Physics.PhysicsBodyHandle, physics_handle);
    entity_handle.add_component(RenderSystem.RendererHandle, rendr_handle);
    
    return entity_handle;
}

pub fn pillar() !ComponentSystem.EntityHandle {
    var entity_handle = try ComponentSystem.Entity.create(null);
    
    const rendr_handle = try RenderSystem.add_renderer(.{
        .texture = dungeon_texture, 
        .pivot = .{ .x = 8, .y = 11 },
        .rect = .{ .x = 112, .y = 283, .width = 16, .height = 21 },
        .entity = entity_handle,
        // .enable = false,
    });
    const physics_handle = Physics.create_body(entity_handle, 0, 0, 15, 13, std.math.inf(f32), 0.2, 10.0);
    
    entity_handle.add_component(Physics.PhysicsBodyHandle, physics_handle);
    entity_handle.add_component(RenderSystem.RendererHandle, rendr_handle);
    
    return entity_handle;
}