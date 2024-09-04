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

pub const slime_animations: []const Animation = &.{
    &.{// idle
        .{.rect = .{.x = 0 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 1 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 2 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 3 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 4 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 5 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 6 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 7 * 128, .y = 0, .width = 128, .height = 128}, .duration = 80},
    },
    &.{// jump
        .{.rect = .{.x = 0 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 1 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 2 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 3 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 4 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 5 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 6 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
        .{.rect = .{.x = 7 * 128, .y = 3 * 128, .width = 128, .height = 128}, .duration = 80},
    },
    &.{// attack
        .{.rect = .{.x = 0 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 1 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 2 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 3 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 4 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 5 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 6 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 7 * 128, .y = 1 * 128, .width = 128, .height = 128}, .duration = 100},
    },
    &.{// die
        .{.rect = .{.x = 0 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 1 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 2 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 3 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 4 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 5 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 6 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
        .{.rect = .{.x = 7 * 128, .y = 2 * 128, .width = 128, .height = 128}, .duration = 100},
    },
};