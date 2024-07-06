const std = @import("std");
const rl = @import("rl.zig");
const Box = @import("box2d.zig");
const ComponentSystem = @import("component_system.zig");

pub const PhysicsBodyHandle = struct {
    id: u64,
    
    pub fn set_vel(self: PhysicsBodyHandle, vel: rl.Vector2) void {
        if (world.bodies.getPtr(@intCast(self.id))) |body| {
            body.velocity.set(vel);
        }
    }
    
    pub fn get_vel(self: PhysicsBodyHandle) rl.Vector2 {
        if (world.bodies.get(@intCast(self.id))) |body| {
            return body.velocity.get();
        }
        return rl.Vector2Zero();
    }
    
    pub fn get_pos(self: PhysicsBodyHandle) rl.Vector2 {
        if (world.bodies.get(@intCast(self.id))) |body| {
            return body.position.get();
        }
        return rl.Vector2Zero();
    }
    
    pub fn set_pos(self: PhysicsBodyHandle, pos: rl.Vector2) void {
        if (world.bodies.getPtr(@intCast(self.id))) |body| {
            body.position.set(pos);
        }
    }
};

pub var world: Box.World = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    world = Box.World {
        .gravity = Box.Vec2{ .x = 0, .y = 0 },
        .iterations = 120,
        .accumulateImpulses = true,
        .warmStarting = true,
        .positionCorrection = true,
        .bodies = Box.World.BodyMap.init(allocator),
        .arbiters = Box.World.ArbiterMap.init(allocator),
    };
}

pub fn create_body(entity: ComponentSystem.EntityHandle, x: f32, y: f32, w: f32, h: f32, m: f32, f: f32, c: f32) PhysicsBodyHandle {
    return .{ .id = world.addBody(Box.Body.init(entity, .{ .x = x, .y = y }, .{ .x = w, .y = h }, m, f, c)) };
}

pub fn step(dt: f32) void {
    world.step(dt);
}

pub fn get_size(handle: Box.BodyHandle) rl.Vector2 {
    if (world.bodies.get(handle)) |body| {
        return rl.Vector2 {.x=body.width.x, .y=body.width.y};
    }
    return rl.Vector2Zero();
}

pub fn get_pos(handle: Box.BodyHandle) rl.Vector2 {
    if (world.bodies.get(handle)) |body| {
        return body.position.get();
    }
    return rl.Vector2Zero();
}

pub fn set_pos(handle: Box.BodyHandle, pos: rl.Vector2) void {
    if (world.bodies.getPtr(handle)) |body| {
        body.position.set(pos);
    }
}

pub fn set_vel(handle: Box.BodyHandle, vel: rl.Vector2) void {
    if (world.bodies.getPtr(handle)) |body| {
        body.velocity.set(vel);
    }
}

pub fn get_vel(handle: Box.BodyHandle) rl.Vector2 {
    if (world.bodies.get(handle)) |body| {
        return body.velocity.get();
    }
    return rl.Vector2Zero();
}