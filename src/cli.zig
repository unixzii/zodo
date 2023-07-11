const std = @import("std");
const String = @import("./utils/string.zig").String;
const Tokenizer = @import("./utils/tokenizer.zig").Tokenizer;
const Allocator = std.mem.Allocator;

pub const CommandType = union(enum) {
    add: AddCommand,
    remove: RemoveCommand,
    list: ListCommand,
};

pub const AddCommand = struct {
    contents: []const u8,

    pub const name = "add";

    fn parse(tokenizer: *Tokenizer) !AddCommand {
        var contents = tokenizer.readRemains();
        if (contents.len == 0) {
            return error.ContentIsEmpty;
        }
        return .{ .contents = contents };
    }
};

pub const RemoveCommand = struct {
    index: u32,

    pub const name = "rm";

    fn parse(tokenizer: *Tokenizer) !RemoveCommand {
        const index_str = tokenizer.readRemains();
        const index = try std.fmt.parseInt(u32, index_str, 10);
        return .{ .index = index };
    }
};

pub const ListCommand = struct {
    pub const name = "ls";

    fn parse(tokenizer: *Tokenizer) !ListCommand {
        _ = tokenizer;
        return .{};
    }
};

fn Parser(comptime T: type) type {
    return struct {
        str: String,
        result: ?CommandType,

        const Self = @This();

        fn init(str: String) Self {
            return .{
                .str = str,
                .result = null,
            };
        }

        pub fn deinit(self: *Self) void {
            self.result = null;
            self.str.deinit();
        }

        fn parse(self: *Self) !void {
            const ti = @typeInfo(T);
            if (ti != .Union) {
                @compileError("expected union argument, found " ++ @typeName(T));
            }

            var s = self.str.get() orelse return;
            var tokenizer = Tokenizer.init(s);
            const cmd_str = tokenizer.readUntil(' ') orelse tokenizer.readRemains();

            const fields = ti.Union.fields;
            inline for (fields) |field| {
                const CmdType = field.field_type;
                if (std.mem.eql(u8, cmd_str, CmdType.name)) {
                    const cmd = try CmdType.parse(&tokenizer);
                    self.result = @unionInit(T, field.name, cmd);
                    return;
                }
            }
        }
    };
}

pub const CommandParser = Parser(CommandType);

fn parseCliInner(str: String) !CommandParser {
    var parser = CommandParser.init(str);
    errdefer parser.deinit();
    try parser.parse();

    return parser;
}

pub fn parseCli(allocator: Allocator) !CommandParser {
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Concat all args as one string.
    const args_str = buildStr: {
        var args_str = String.init(allocator);
        errdefer args_str.deinit();

        for (args) |arg, i| {
            if (i == 0) {
                // Ignore the first arg (executable name).
                continue;
            }
            if (i > 1) {
                try args_str.append(" ");
            }
            try args_str.append(arg[0..arg.len]);
        }

        break :buildStr args_str;
    };

    return try parseCliInner(args_str);
}
