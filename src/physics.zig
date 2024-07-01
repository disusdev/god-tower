const std = @import("std");
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