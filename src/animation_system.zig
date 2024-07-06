const std = @import("std");
const rl = @import("rl.zig");
const RenderSystem = @import("render_system.zig");
const AbilitySystem = @import("ability_system.zig");
const Animations = @import("animations.zig");
const Physics = @import("physics.zig");

pub const Frame = struct {
    rect: rl.Rectangle,
    duration: u32,
};

pub const Animation = [] const Frame;

pub const AnimatorController = struct {
    const Direction = enum(u8) {
        Up = 0,
        SideRight = 1,
        Down = 2,
        SideLeft = 3
    };

    // input?
    // move: ?AbilitySystem.MoveAbilityHandle,
    // brain: ?AbilitySystem.BrainHandle,
    body: Physics.PhysicsBodyHandle,
    animator: AnimatorHandle,
    renderer: RenderSystem.RendererHandle,

    last_idx: u64 = 0,
    
    fn update(self: *AnimatorController) void {
        const axis = self.body.get_vel();
        //if (self.move) |move| {
        //    if (self.animator.is_playing() and self.last_idx != 2) {
        //        const action = move.get_action();
        //        if (action) {
        //            self.animator.play(Animations.hero_animations[2], false);
        //        }
        //    }
        //    if (self.animator.is_playing() and self.last_idx == 2) {
        //        return;
        //    }
        //    axis = move.get_axis();
        //} else if (self.brain) {
        //    axis = brain.get_axis();
        //}
        
        var dir: Direction = Direction.Down;
        if (axis.x > 0.5) {
            dir = .SideRight;
        } else if (axis.x < -0.5) {
            dir = .SideLeft;
        } else if (axis.y < -rl.EPSILON) {
            dir = .Up;
        } else if (axis.y > rl.EPSILON) {
            dir = .Down;
        }
        
        switch (dir) {
            .SideLeft => {
                self.animator.set_flip(true);// flip = true;
            },
            .SideRight => {
                self.animator.set_flip(false);
            },
            else => {},
        }
        
        const id: u64 = if (rl.Vector2Length(axis) > rl.EPSILON) 1 else 0;
        if (self.last_idx != id or !self.animator.is_playing()) {
            self.last_idx = id;
            self.animator.play(Animations.hero_animations[self.last_idx], true);
        }
    }
};

pub const AnimatorControllerHandle = struct {
    id: u64,
    
    pub fn create(controller: AnimatorController) !AnimatorControllerHandle {
        try controllers.append(controller);
        return .{ .id = controllers.items.len };
    }
};

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

    fn play(self: *Animator, animation: Animation, loop: bool) void {
        self.is_playing = true;
        self.current_anim = animation;
        self.frame_idx = 0;
        self.frame_time = 0.0;
        self.loop = loop;
    }

    fn get_rect(self: Animator) rl.Rectangle {
        var rect = self.current_anim[self.frame_idx].rect;
        rect.width = if (self.flip) - @abs(rect.width) else @abs(rect.width);
        return rect;
    }
};

pub const AnimatorHandle = struct {
    id: u64,
    pub fn create(animator: Animator) !AnimatorHandle {
        try animators.append(animator);
        return .{ .id = animators.items.len };
    }
    pub fn play(self: AnimatorHandle, animation: Animation, loop: bool) void {
        animators.items[self.id].play(animation, loop);
    }
    pub fn set_flip(self: AnimatorHandle, flip: bool) void {
        animators.items[self.id].flip = flip;
    }
    pub fn set_loop(self: AnimatorHandle, loop: bool) void {
        animators.items[self.id].loop = loop;
    }
    pub fn is_playing(self: AnimatorHandle) bool {
        return animators.items[self.id].is_playing;
    }
};

pub var animators: std.ArrayList(Animator) = undefined;
pub var controllers: std.ArrayList(AnimatorController) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    animators = std.ArrayList(Animator).init(allocator);
    controllers = std.ArrayList(AnimatorController).init(allocator);
}

pub fn update(dt: f32) void {
    for (controllers.items) |*controller| {
        controller.update();
    }

    for (animators.items) |*animator| {
        animator.update(dt);
    }
}

pub fn add_animator(animator: Animator) !AnimatorHandle {
    try animators.append(animator);
    return .{ .id = animators.items.len - 1 };
}