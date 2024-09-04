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
pub var palette_texture: rl.Texture2D = undefined;
pub var slime_textures: [10] rl.Texture2D = undefined;

pub fn init() void {
    dungeon_texture = rl.LoadTexture("data/sprites/dungeon_tiles.png");
    base_texture = rl.LoadTexture("data/sprites/base.png");
    palette_texture = rl.LoadTexture("data/sprites/pal1.png");
    slime_textures[0] = rl.LoadTexture("data/sprites/slimes/acidslime/acidslime_atlas.png");
    slime_textures[1] = rl.LoadTexture("data/sprites/slimes/iceslime/iceslime_atlas.png");
    slime_textures[2] = rl.LoadTexture("data/sprites/slimes/ironslime/ironslime_atlas.png");
    slime_textures[3] = rl.LoadTexture("data/sprites/slimes/lightningslime/lightningslime_atlas.png");
    slime_textures[4] = rl.LoadTexture("data/sprites/slimes/ravaslime/ravaslime_atlas.png");
    slime_textures[5] = rl.LoadTexture("data/sprites/slimes/slime/slime_atlas.png");
    slime_textures[6] = rl.LoadTexture("data/sprites/slimes/soilslime/soilslime_atlas.png");
    slime_textures[7] = rl.LoadTexture("data/sprites/slimes/soulslime/soulslime_atlas.png");
    slime_textures[8] = rl.LoadTexture("data/sprites/slimes/stormslime/stormslime_atlas.png");
    slime_textures[9] = rl.LoadTexture("data/sprites/slimes/thornslime/thornslime_atlas.png");
}

pub fn hero(x: f32, y: f32) !ComponentSystem.EntityHandle {
    var entity = try ComponentSystem.Entity.create(null);
    const renderer = try RenderSystem.add_renderer(.{
        .texture = base_texture,
        .pivot = .{ .x = 8, .y = 18 },
        .entity = entity,
        .palette_texture = palette_texture,
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
        .animations = Animations.hero_animations,
    });

    entity.add_component(Physics.PhysicsBodyHandle, body);
    entity.add_component(RenderSystem.RendererHandle, renderer);
    entity.add_component(AbilitySystem.MoveAbilityHandle, move);
    entity.add_component(AnimationSystem.AnimatorHandle, animator);    
    entity.add_component(AnimationSystem.AnimatorControllerHandle, controller);
    entity.add_component(AbilitySystem.StatsHandle, AbilitySystem.StatsHandle.create(.{
        .hp = 100,
        .owner = entity,
    }));
    
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
        .palette_texture = palette_texture,
        .palette_index = 1,
        .scale = 0.8,
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
        .animations = Animations.hero_animations,
    });

    entity.add_component(Physics.PhysicsBodyHandle, body);
    entity.add_component(RenderSystem.RendererHandle, renderer);
    entity.add_component(AbilitySystem.BrainHandle, brain);
    entity.add_component(AnimationSystem.AnimatorHandle, animator);    
    entity.add_component(AnimationSystem.AnimatorControllerHandle, controller);
    entity.add_component(AbilitySystem.StatsHandle, AbilitySystem.StatsHandle.create(.{
        .hp = 30,
        .owner = entity,
    }));
    
    return entity;
}

pub fn box() !ComponentSystem.EntityHandle {
    var entity_handle = try ComponentSystem.Entity.create(null);
    
    const rendr_handle = try RenderSystem.add_renderer(.{
        .texture = dungeon_texture,
        .pivot = .{ .x = 8, .y = 11 },
        .rect = .{ .x = 288, .y = 285, .width = 16, .height = 19 },
        .entity = entity_handle,
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
    });
    const physics_handle = Physics.create_body(entity_handle, 0, 0, 15, 13, std.math.inf(f32), 0.2, 10.0);
    
    entity_handle.add_component(Physics.PhysicsBodyHandle, physics_handle);
    entity_handle.add_component(RenderSystem.RendererHandle, rendr_handle);
    
    return entity_handle;
}

pub fn slime(index: u32, x: f32, y: f32) !ComponentSystem.EntityHandle {
    var entity = try ComponentSystem.Entity.create(null);
    const renderer = try RenderSystem.add_renderer(.{
        .texture = slime_textures[index],
        .pivot = .{ .x = 63, .y = 83 },
        .entity = entity,
        .scale = 0.4,
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
        .animations = Animations.slime_animations,
    });

    entity.add_component(Physics.PhysicsBodyHandle, body);
    entity.add_component(RenderSystem.RendererHandle, renderer);
    entity.add_component(AbilitySystem.BrainHandle, brain);
    entity.add_component(AnimationSystem.AnimatorHandle, animator);    
    entity.add_component(AnimationSystem.AnimatorControllerHandle, controller);
    entity.add_component(AbilitySystem.StatsHandle, AbilitySystem.StatsHandle.create(.{
        .hp = 10,
        .owner = entity,
    }));
    
    return entity;
}
