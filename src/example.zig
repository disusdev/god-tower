const std = @import("std");
const rl = @import("rl.zig");

const print = std.debug.print;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
const VELOCITY = 0.5;

pub fn main() !void {
    rl.SetConfigFlags(rl.FLAG_VSYNC_HINT | rl.FLAG_WINDOW_RESIZABLE);
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "game");

    var camera = rl.Camera2D {.offset = .{.x = SCREEN_WIDTH/2-16,.y = SCREEN_HEIGHT/2-16}, .rotation = 0, .target = .{.x = 0,.y = 0}, .zoom = 2.0 };

    rl.InitPhysics();
    defer rl.ClosePhysics();

    rl.SetPhysicsGravity(0, 0);

    const floor = rl.CreatePhysicsBodyRectangle(.{ .x = SCREEN_WIDTH/2, .y = SCREEN_HEIGHT }, SCREEN_WIDTH, 100, 10);
    const platformLeft = rl.CreatePhysicsBodyRectangle(.{ .x = SCREEN_WIDTH*0.25, .y = SCREEN_HEIGHT*0.6 }, SCREEN_WIDTH*0.25, 10, 10);
    const platformRight = rl.CreatePhysicsBodyRectangle(.{ .x = SCREEN_WIDTH*0.75, .y = SCREEN_HEIGHT*0.6 }, SCREEN_WIDTH*0.25, 10, 10);
    const wallLeft = rl.CreatePhysicsBodyRectangle(.{ .x = -5, .y = SCREEN_WIDTH/2 }, 10, SCREEN_HEIGHT, 10);
    const wallRight = rl.CreatePhysicsBodyRectangle(.{ .x = SCREEN_WIDTH + 5, .y = SCREEN_HEIGHT/2 }, 10, SCREEN_HEIGHT, 10);

    floor.*.enabled = false;
    platformLeft.*.enabled = false;
    platformRight.*.enabled = false;
    wallLeft.*.enabled = false;
    wallRight.*.enabled = false;

    //const body = rl.CreatePhysicsBodyCircle(.{ .x = SCREEN_WIDTH/2, .y = SCREEN_HEIGHT/2 }, 25, 1);
    const body = rl.CreatePhysicsBodyRectangle(.{ .x = SCREEN_WIDTH/2, .y = SCREEN_HEIGHT/2 }, 50, 50, 2);
    body.*.freezeOrient = true;
    //body.*.useGravity = false;
    // body.*.restitution = 2;

    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();

        if (rl.IsKeyDown(rl.KEY_RIGHT)) {
            body.*.velocity.x += 1 * dt;
        } else if (rl.IsKeyDown(rl.KEY_LEFT)) {
            body.*.velocity.x += -1 * dt;
        }

        if (rl.IsKeyDown(rl.KEY_UP)) {
            body.*.velocity.y += -1 * dt;
        } else if (rl.IsKeyDown(rl.KEY_DOWN)) {
            body.*.velocity.y += 1 * dt;
        }

        //body.*.velocity = rl.Vector2Scale(rl.Vector2Normalize(body.*.velocity), VELOCITY);

        // Vertical movement input checking if player physics body is grounded
        //if (rl.IsKeyDown(rl.KEY_UP) and body.*.isGrounded) {
        //    body.*.velocity.y = -VELOCITY * 4;
        //}

        body.*.velocity = rl.Vector2Add(body.*.velocity, rl.Vector2Scale(body.*.velocity, -0.2));

        const wheel_move = rl.GetMouseWheelMove();
        if (@abs(wheel_move) > rl.EPSILON) {
            camera.zoom += wheel_move;
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.GetColor(0x140b28ff));

        rl.RunPhysicsStep();

        //body.*.velocity = rl.Vector2Subtract(body.*.velocity, rl.Vector2Scale(body.*.velocity, -10.0));

        const bodiesCount: usize = @intCast(rl.GetPhysicsBodiesCount());
        for (0..bodiesCount) |i| {
            const pbody = rl.GetPhysicsBody(@intCast(i));
            const vertexCount: usize = @intCast(rl.GetPhysicsShapeVerticesCount(@intCast(i)));
            for (0..vertexCount) |j| {
                const vertexA = rl.GetPhysicsShapeVertex(pbody, @intCast(j));
                const jj: i32 = @intCast(if ((j + 1) < vertexCount) (j + 1) else 0);
                const vertexB = rl.GetPhysicsShapeVertex(pbody, jj);
                rl.DrawLineV(vertexA, vertexB, rl.GREEN);
            }
        }

        // rl.BeginMode2D(camera);
        // rl.EndMode2D();

        rl.EndDrawing();
    }

    rl.CloseWindow();
}