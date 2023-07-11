const std = @import("std");
const cli = @import("./cli.zig");
const Database = @import("./db.zig").Database;
const getHomeDir = @import("./utils/home.zig").getHomeDir;

fn printUsage() !void {
    var std_err = std.io.getStdErr().writer();
    var writer = std.io.bufferedWriter(std_err);

    const usage =
        \\Usage: zodo [command] [options]
        \\
        \\Commands:
        \\  add [contents]        Add a todo item
        \\  rm [item_id]          Remove a todo item
        \\  ls                    List all the todo items
    ;

    _ = try writer.write(usage);
    _ = try writer.write("\n");
    try writer.flush();
}

fn printOutput(str: []const u8) void {
    std.io.getStdOut().writeAll(str) catch {};
}

fn allocCompactItemList(allocator: std.mem.Allocator, db: *const Database) ![]u32 {
    var list = std.ArrayList(u32).init(allocator);
    for (db.items.items) |item_id| {
        if (db.item_table.contains(item_id)) {
            try list.append(item_id);
        }
    }
    return list.toOwnedSlice();
}

pub fn main() !void {
    var allocator = std.heap.c_allocator;

    // Parse the command to execute.
    var cli_parser = cli.parseCli(allocator) catch {
        try printUsage();
        return;
    };
    defer cli_parser.deinit();
    const cmd = cli_parser.result orelse {
        try printUsage();
        return;
    };

    // Get the database path.
    const home_dir = try getHomeDir();
    const db_path_comps = [_][]const u8{ home_dir, ".zodo_db" };
    var db_path = try std.fs.path.join(allocator, &db_path_comps);
    defer allocator.free(db_path);

    // Open the database.
    var db = Database.init(allocator, db_path) catch |err| {
        std.debug.print("error: failed to open the database ({})\n", .{err});
        return;
    };
    defer db.deinit();

    // Execute the command.
    switch (cmd) {
        cli.CommandType.add => |add| {
            db.add_item(add.contents) catch |err| {
                std.debug.print("error: failed to add the item ({})\n", .{err});
                return;
            };
            printOutput("📝 Item added!\n");
        },
        cli.CommandType.remove => |remove| {
            var compact_list = try allocCompactItemList(allocator, &db);
            defer allocator.free(compact_list);

            const index = remove.index;
            if ((index < 1) or (index > compact_list.len)) {
                std.debug.print("error: index out of bounds\n", .{});
                return;
            }

            const item_id = compact_list[index - 1];
            db.remove_item(item_id) catch |err| {
                std.debug.print("error: failed to remove the item ({})\n", .{err});
                return;
            };
            printOutput("✅ Item removed!\n");
        },
        cli.CommandType.list => {
            if (db.item_table.count() == 0) {
                printOutput("✨ Your list is clean!\n");
                return;
            }
            var compact_list = try allocCompactItemList(allocator, &db);
            defer allocator.free(compact_list);
            for (compact_list) |item_id, i| {
                const item = db.item_table.get(item_id) orelse {
                    std.debug.panic("fatal: inconsistent internal state\n", .{});
                    return;
                };
                var line = try std.fmt.allocPrint(allocator, "{}. {s}\n", .{ i + 1, item });
                printOutput(line);
                allocator.free(line);
            }
        },
    }
}
