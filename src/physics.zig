const std = @import("std");
const rl = @import("rl.zig");
const Box = @import("box2d.zig");

pub var world: Box.World = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    world = Box.World {
        .gravity = Box.Vec2{ .x = 0, .y = 0 },
        .iterations = 6,
        .accumulateImpulses = true,
        .warmStarting = true,
        .positionCorrection = true,
        .bodies = Box.World.BodyMap.init(allocator),
        .arbiters = Box.World.ArbiterMap.init(allocator),
    };
}

pub fn step(dt: f32) void {
    world.step(dt);
}

pub fn get_pos(handle: Box.BodyHandle) rl.Vector2 {
    if (world.bodies.get(handle)) |body| {
        return body.position.get();
    }
    return rl.Vector2Zero();
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