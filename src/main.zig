const std = @import("std");
const rl = @import("rl.zig");

const print = std.debug.print;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const Rect = struct {x:f32,y:f32,w:f32,h:f32};
const Size = struct {w:u32,h:u32};
const JFrame = struct { filename:[]const u8, frame: Rect, rotated: bool, trimmed: bool, spriteSourceSize: Rect, sourceSize: Size, duration: u32 };
const JFrameTag = struct {name: []const u8, from: u32, to: u32, direction: []const u8, color: []const u8};
const JAspMeta = struct {app:[]const u8, version:[]const u8, image: []const u8, format: []const u8, size: Size, scale: f32, frameTags: []const JFrameTag};
const JAnim = struct { frames: []const JFrame, meta: JAspMeta };

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;

pub fn main() !void {
    const json_str = try std.fs.cwd().readFileAlloc(allocator, "data/sprites/doc.json", 1024 * 1024);
    const parsed = try std.json.parseFromSlice(JAnim, allocator, json_str, .{});
    defer parsed.deinit();

    var doc_animations = std.StringHashMap(std.ArrayList(JFrame)).init(allocator);
    defer doc_animations.deinit();

    for (parsed.value.meta.frameTags) |frame_tag| {
        var anim = std.ArrayList(JFrame).init(allocator);
        try anim.appendSlice(parsed.value.frames[frame_tag.from..frame_tag.to]);
        try doc_animations.put(frame_tag.name, anim);
    }

    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT | rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "game");

    const image = rl.LoadImage("data/sprites/doc.png");
    defer rl.UnloadImage(image);

    const texture = rl.LoadTextureFromImage(image);
    defer rl.UnloadTexture(texture);

    var anim_idx: usize = 0;
    var frame_counter: usize = 0;
    var frame_time: f32 = 0.0;
    const fliped = false;

    const anim_keys: []const []const u8 = &.{
        "run",
        "stick_drop"
    };

    var anim_key: []const u8 = "run";

    const player_pos = rl.Vector2 {.x=0.0,.y=0.0};

    const camera = rl.Camera2D {.offset = .{.x = SCREEN_WIDTH/2-16,.y = SCREEN_HEIGHT/2-16}, .rotation = 0, .target = .{.x = 0,.y = 0}, .zoom = 8.0 };

    while (!rl.WindowShouldClose()) {
        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            anim_idx = (anim_idx + 1) % anim_keys.len;
            anim_key = anim_keys[anim_idx];
            frame_counter = 0;
            frame_time = 0.0;
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.RAYWHITE);

        rl.BeginMode2D(camera);

        const animation = doc_animations.get(anim_key).?;
        var rect = animation.items[frame_counter].frame;

        if (fliped) {
            rect.w = -16;
        } else {
            rect.h = 16;
        }

        rl.DrawTextureRec(texture, .{.x=rect.x,.y=rect.y,.width=rect.w,.height=rect.h}, .{ .x=player_pos.x-@abs(rect.w)/2, .y=player_pos.y-@abs(rect.h)/2 }, rl.WHITE);

        rl.DrawFPS(0, 0);

        rl.EndMode2D();

        frame_time += rl.GetFrameTime();
        if (frame_time >= (@as(f32, @floatFromInt(animation.items[frame_counter].duration)) * 0.001)) {
            frame_counter = (frame_counter + 1) % animation.items.len;
            frame_time = 0.0;
        }

        rl.EndDrawing();
    }

    rl.CloseWindow();
}
