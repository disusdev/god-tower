const std = @import("std");
const rl = @import("rl.zig");

const AnimationSystem = @import("animation_system.zig");
const Frame = AnimationSystem.Frame;
const Animation = []const Frame;

pub const hero_animations: []const Animation = &.{
    &.{// idle
        .{.rect = .{.x = 2 * 16, .y = 0, .width = 16, .height = 24}, .duration = 100},
        .{.rect = .{.x = 3 * 16, .y = 0, .width = 16, .height = 24}, .duration = 100},
        .{.rect = .{.x = 4 * 16, .y = 0, .width = 16, .height = 24}, .duration = 100},
        .{.rect = .{.x = 5 * 16, .y = 0, .width = 16, .height = 24}, .duration = 100},
    },
    &.{// run
        .{.rect = .{.x = 7 * 16, .y = 0, .width = 16, .height = 24}, .duration = 80},
        .{.rect = .{.x = 8 * 16, .y = 0, .width = 16, .height = 24}, .duration = 80},
        .{.rect = .{.x = 9 * 16, .y = 0, .width = 16, .height = 24}, .duration = 100},
        .{.rect = .{.x = 10 * 16, .y = 0, .width = 16, .height = 24}, .duration = 80},
    },
    &.{// action
        .{.rect = .{.x = 0 * 16, .y = 0, .width = 16, .height = 24}, .duration = 400},
    },
};