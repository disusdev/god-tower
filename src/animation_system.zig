const std = @import("std");
const rl = @import("rl.zig");
const RenderSystem = @import("render_system.zig");

pub const Frame = struct {
    rect: rl.Rectangle,
    duration: u32,
};

pub const Animation = [] const Frame;

const Animator = struct {
    renderer: RenderSystem.RendererHandle,
    current_anim: Animation = undefined,
    frame_idx: usize = 0,
    frame_time: f32 = 0.0,
    loop: bool = true,
    flip: bool = false,
    is_playing: bool = false,

    fn update(self: *Animator, dt: f32) void {
        self.frame_time += dt;
        if (self.frame_time >= (@as(f32, @floatFromInt(self.current_anim[self.frame_idx].duration)) * 0.001)) {
            if (self.loop == false and (self.frame_idx + 1) == self.current_anim.len) {
                // on anmiation end
                self.is_playing = false;
                return;
            }
            self.frame_idx = (self.frame_idx + 1) % self.current_anim.len;
            self.frame_time = 0.0;
        }

        self.renderer.set_rect(self.get_rect());
    }

    fn play(self: *Animator, animation: Animation) void {
        self.is_playing = true;
        self.current_anim = animation;
        self.frame_idx = 0;
        self.frame_time = 0.0;
    }

    fn get_rect(self: Animator) rl.Rectangle {
        var rect = self.current_anim[self.frame_idx].rect;
        rect.width = if (self.flip) - @abs(rect.width) else @abs(rect.width);
        return rect;
    }
};

pub const AnimatorHandle = struct {
    id: u64,
    pub fn play(self: AnimatorHandle, animation: Animation) void {
        animators.items[self.id].play(animation);
    }
};

pub var animators: std.ArrayList(Animator) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    animators = std.ArrayList(Animator).init(allocator);
}

pub fn update(dt: f32) void {
    for (animators.items) |*animator| {
        animator.update(dt);
    }
}

pub fn add_animator(animator: Animator) !AnimatorHandle {
    try animators.append(animator);
    return .{ .id = animators.items.len - 1 };
}