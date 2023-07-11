const std = @import("std");
const String = @import("./utils/string.zig").String;
const Tokenizer = @import("./utils/tokenizer.zig").Tokenizer;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const RecordLineType = union(enum) {
    insertion: struct { id: u32, contents: []const u8 },
    deletion: u32,
};

const ParseRecordLineError = error{InvalidRecordLine};

fn parseRecordLine(line: []u8) !RecordLineType {
    var tokenizer = Tokenizer.init(line);
    const typ = tokenizer.readUntil(' ') orelse {
        return ParseRecordLineError.InvalidRecordLine;
    };

    if (std.mem.eql(u8, typ, "INS")) {
        const id_str = tokenizer.readUntil(' ') orelse {
            return ParseRecordLineError.InvalidRecordLine;
        };
        const id = try std.fmt.parseInt(u32, id_str, 10);
        return .{ .insertion = .{ .id = id, .contents = tokenizer.readRemains() } };
    } else if (std.mem.eql(u8, typ, "DEL")) {
        const id_str = tokenizer.readRemains();
        const id = try std.fmt.parseInt(u32, id_str, 10);
        return .{ .deletion = id };
    } else {
        return ParseRecordLineError.InvalidRecordLine;
    }
}

// TODO this is enough, isn't it?
const ItemTable = std.AutoHashMap(u32, []const u8);
const ItemIDList = std.ArrayList(u32);

pub const Database = struct {
    allocator: Allocator,
    arena: ArenaAllocator,
    path: []const u8,
    item_table: ItemTable,
    items: ItemIDList,
    cur_id: u32,

    const Self = @This();

    pub fn init(allocator: Allocator, path: []const u8) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        var arena_allocator = arena.allocator();
        errdefer arena.deinit();

        const dup_path = try arena_allocator.dupe(u8, path);
        var item_table = ItemTable.init(arena_allocator);
        var items = ItemIDList.init(arena_allocator);

        var file = std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch |err| {
            if (err != error.FileNotFound) {
                return err;
            }

            // Database is not created, init an empty one.
            return .{
                .allocator = allocator,
                .arena = arena,
                .path = dup_path,
                .item_table = item_table,
                .items = items,
                .cur_id = 0,
            };
        };
        defer file.close();

        var last_id: u32 = 0;
        var reader = std.io.bufferedReader(file.reader());
        const MAX_SIZE = std.math.maxInt(usize);
        while (try reader.reader().readUntilDelimiterOrEofAlloc(arena_allocator, '\n', MAX_SIZE)) |line| {
            var record_line = try parseRecordLine(line);
            switch (record_line) {
                RecordLineType.insertion => |ins| {
                    const id = ins.id;
                    last_id = id;
                    item_table.put(id, ins.contents) catch |err| {
                        // It's very terrible if this occurs, we have nothing
                        // to do but panic :(
                        std.debug.panic("fatal: {}\n", .{err});
                    };
                    items.append(id) catch |err| {
                        std.debug.panic("fatal: {}\n", .{err});
                    };
                },
                RecordLineType.deletion => |del| {
                    // It's ok to only remove the item from `item_table`,
                    // we can just skip the deleted ones while listing.
                    _ = item_table.remove(del);
                },
            }
        }

        return .{
            .allocator = allocator,
            .arena = arena,
            .path = dup_path,
            .item_table = item_table,
            .items = items,
            .cur_id = last_id,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    pub fn add_item(self: *Self, contents: []const u8) !void {
        const new_id = self.cur_id + 1;
        const dup_contents = try self.arena.allocator().dupe(u8, contents);
        try self.item_table.put(new_id, dup_contents);
        try self.items.append(new_id);
        self.cur_id = new_id;

        var buf = try std.fmt.allocPrint(self.allocator, "INS {} {s}\n", .{ new_id, contents });
        defer self.allocator.free(buf);
        try self.append_record_line(buf);
    }

    pub fn remove_item(self: *Self, id: u32) !void {
        if (!self.item_table.remove(id)) {
            return;
        }

        var buf = try std.fmt.allocPrint(self.allocator, "DEL {}\n", .{id});
        defer self.allocator.free(buf);
        try self.append_record_line(buf);
    }

    fn append_record_line(self: *Self, buf: []const u8) !void {
        var file = std.fs.openFileAbsolute(self.path, .{ .mode = .read_write }) catch |err| blk: {
            if (err != error.FileNotFound) {
                return err;
            }

            var file = try std.fs.createFileAbsolute(self.path, .{});
            break :blk file;
        };
        defer file.close();

        try file.seekFromEnd(0);
        try file.writer().writeAll(buf);
    }

    fn prune_database(self: *Self) void {
        _ = self;
        std.debug.panic("not implemented!", .{});
    }
};
