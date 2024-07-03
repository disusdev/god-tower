const std = @import("std");
const rl = @import("rl.zig");
const Frame = @import("frame.zig");
const Box = @import("box2d.zig");
const physics = @import("physics.zig");
const T = @This();
const AbilitySystem = @import("ability_system.zig");
const RenderSystem = @import("render_system.zig");
const Renderer = RenderSystem.Renderer;

const Direction = enum(u8) {
    Up = 0,
    SideRight = 1,
    Down = 2,
    SideLeft = 3
};

const AnimationState = enum {
    Idle,
    Move,
    Attack,
    Hit
};

const Attributes = struct {
    hp: u32,
    attack: u32,
    defence: u32,
    speed: u32
};

const Animation = struct {
    current_anim: [] const Frame = undefined,
    state: AnimationState = .Idle,
    anim_idx: usize = 1,
    frame_idx: usize = 0,
    frame_time: f32 = 0.0,
    loop: bool = true,
    flip: bool = false,
};

pub const Weapon = struct {
    pos: rl.Vector2,
    target: *T,
    rot: f32,
    add_rot: f32,
    renderer: RenderSystem.RendererHandle,
    coef: f32,
    
    pub fn init(pos: rl.Vector2, target: *T, tex: rl.Texture2D, rect: rl.Rectangle, pivot: rl.Vector2) !Weapon {
        return Weapon {
            .pos = pos,
            .target = target,
            .rot = 0,
            .add_rot = 0,
            .renderer = try RenderSystem.add_renderer(.{ .texture = tex, .rect = rect, .pivot = pivot }),
            .coef = 0,
        };
    }
    
    pub fn update(self: *Weapon, progres: f32) void {
        var renderer = RenderSystem.get_renderer(self.renderer);

        const target_pos = physics.get_pos(self.target.body);
        const dst_rect = .{
            .x = target_pos.x+self.pos.y,
            .y = target_pos.y+self.pos.y,
            .width = renderer.rect.width,
            .height = renderer.rect.height
        };
        _ = progres;
        // self.add_rot = rl.Lerp(0, 45, progres * 0.5);
        renderer.transform.position = .{.x=dst_rect.x, .y=dst_rect.y};
        renderer.transform.rotation = self.rot + self.add_rot;
        // self.renderer.draw();
    }
};

weapon: ?Weapon = null,

body: Box.BodyHandle = undefined,

move: AbilitySystem.MoveAbility = .{},
attack: AbilitySystem.AttackAbility = .{},

stat_points: u32 = 0,
stats: Attributes = undefined,
exp: u32 = 0,
level: u32 = 0,

hp: i32 = 10,


animations: []const []const Frame = undefined,
renderer: Renderer = undefined,

dir: Direction = .Down,

animator: Animation = Animation {},

dmg_seed: i8 = -1,

dead: bool = false,

pub fn damage(self: *T, dmg: u32, seed: i8) u32 {
    if (seed == self.dmg_seed) return 0;
    if (self.hp <= 0) return 0;
    self.animator.state = .Hit;
    self.dmg_seed = seed;
    self.hp -= @intCast(dmg);
    if (self.hp == 0) {
        // light death
    } else if (self.hp < 0) {
        // brutal death
    }
    return dmg;
}

pub fn set_animation(self: *T, state: AnimationState, dir: Direction) void {
    var id: usize = 0;

    switch (dir) {
        .SideLeft => {
            self.animator.flip = true;
        },
        .SideRight => {
            self.animator.flip = false;
        },
        else => {},
    }

    if (state == .Move) {
        self.animator.loop = true;
        id = 1;
    } else if (state == .Attack) {
        self.animator.loop = false;
    } else if (state == .Hit) {
        self.animator.loop = false;
    } else {
        self.animator.loop = true;
    }

    if (id != self.animator.anim_idx) {
        self.animator.anim_idx = id;
        self.animator.current_anim = self.animations[self.animator.anim_idx];
        self.animator.frame_idx = 0;
        self.animator.frame_time = 0.0;
    }
}

pub fn draw(self: *T) void {
    if (self.dead) return;

    var pos = rl.Vector2Zero();
    if (physics.world.bodies.getPtr(self.body)) |body| {
        pos.x = body.position.x;
        pos.y = body.position.y;
    }

    self.set_animation(self.animator.state, self.dir);

    var rect = self.animator.current_anim[self.animator.frame_idx].rect;
    rect.width = if (self.animator.flip) -@abs(rect.width) else @abs(rect.width);

    rl.DrawTextureRec(self.renderer.texture, rect, .{ .x=pos.x-@abs(self.animator.current_anim[self.animator.frame_idx].rect.width)/2, .y=pos.y-6-@abs(self.animator.current_anim[self.animator.frame_idx].rect.height)/2 }, rl.WHITE);

    self.animator.frame_time += rl.GetFrameTime();
    if (self.animator.frame_time >= (@as(f32, @floatFromInt(self.animator.current_anim[self.animator.frame_idx].duration)) * 0.001)) {
        if (self.animator.loop == false and (self.animator.frame_idx + 1) == self.animator.current_anim.len) {
            if (self.animator.state == .Hit and self.hp <= 0) {
                self.dead = true;
            }
            self.animator.state = .Idle;
            return;
        }
        self.animator.frame_idx = (self.animator.frame_idx + 1) % self.animator.current_anim.len;
        self.animator.frame_time = 0.0;
    }
    
    if (self.weapon) |*w| {
        w.rot = self.attack.angle + 90;
    }
    
    //rl.DrawLineV(self.attack.attack_line[0], self.attack.attack_line[1], rl.GREEN);
}

pub fn update(self: *T, dt: f32, characters: [] T) void {
    if (self.animator.state == .Hit) {
        return;
    }

    self.attack.step(self, characters, dt);
    if (self.weapon) |*w| {
        w.update(self.attack.attack_progress);
    }

    var axis = rl.Vector2 {
        .x = rl.GetGamepadAxisMovement(0, 0),
        .y = rl.GetGamepadAxisMovement(0, 1)
    };
    
    const up = rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP);
    const down = rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN);
    const left = rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT);
    const right = rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT);

    axis.x = @floatFromInt(@as(i32, @intFromBool(right)) - @as(i32, @intFromBool(left)));
    axis.y = @floatFromInt(@as(i32, @intFromBool(down)) - @as(i32,@intFromBool(up)));

    if (axis.x > 0.5) {
        self.dir = .SideRight;
    } else if (axis.x < -0.5) {
        self.dir = .SideLeft;
    } else if (axis.y < -rl.EPSILON) {
        self.dir = .Up;
    } else if (axis.y > rl.EPSILON) {
        self.dir = .Down;
    }

    self.move.exec(self.*, axis, if(self.animator.state == .Attack) 0.5 else 1);
    
    if (self.animator.state != .Attack) {
        if (rl.IsKeyPressed(rl.KEY_RIGHT_CONTROL) or
            rl.IsKeyPressed(rl.KEY_LEFT_CONTROL) or
            rl.IsGamepadButtonPressed(0, rl.GAMEPAD_BUTTON_RIGHT_FACE_LEFT) or
            rl.IsMouseButtonPressed(0)) {
            self.animator.state = .Attack;
            self.attack.exec(self);
            physics.set_vel(self.body, rl.Vector2Zero());
        } else if (rl.Vector2Length(physics.get_vel(self.body)) > 0.1) {
            self.animator.state = .Move;
        } else {
            self.animator.state = .Idle;
        }
    }
}

pub fn hero2(x:f32, y:f32) T {
    return T {
        .body = physics.world.addBody(Box.Body.init(.{ .x = x, .y = y }, .{ .x = 8.0, .y = 12.0 }, 2.0, 0.2)),
        .renderer = .{ .texture = rl.LoadTexture("data/sprites/base.png"), .pivot = .{.x = 5, .y = 11 } },
        .animations = &.{
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
        }
    };
}

pub fn box(x:f32, y:f32) T {
    return T {
        .body = physics.world.addBody(Box.Body.init(.{ .x = x, .y = y }, .{ .x = 16.0, .y = 19.0 }, 2.0, 0.2)),
        .renderer = .{ .texture = rl.LoadTexture("data/sprites/dungeon_tiles.png") },
        .animations = &.{
            &.{// idle
                .{.rect = .{.x = 288, .y = 285, .width = 16, .height = 19}, .duration = 100},
            },
        }
    };
}
