const std = @import("std");
const expect = std.testing.expect;

/// Tokenizer is a type for reading string by tokens.
pub const Tokenizer = struct {
    cursor: []const u8,

    const Self = @This();

    /// Creates a Tokenizer to read the specific string.
    pub fn init(str: []const u8) Self {
        return .{ .cursor = str };
    }

    /// Reads string until the specific token.
    pub fn readUntil(self: *Self, tok: u8) ?[]const u8 {
        if (self.getAdvanceTo(tok)) |adv| {
            var slice = self.cursor[0..adv];
            // Also skip the target token.
            self.cursor = self.cursor[(adv + 1)..];
            return slice;
        }
        return null;
    }

    /// Reads string until the specific token without advance
    /// the reader cursor.
    pub fn peekUntil(self: *const Self, tok: u8) ?[]const u8 {
        if (self.getAdvanceTo(tok)) |adv| {
            return self.cursor[0..adv];
        }
        return null;
    }

    /// Consumes and returns the remaining unread string.
    pub fn readRemains(self: *Self) []const u8 {
        var cur = self.cursor;
        defer self.cursor = cur[cur.len..];
        return cur;
    }

    /// Returns the remaining unread string.
    pub fn peekRemains(self: *const Self) []const u8 {
        return self.cursor;
    }

    /// Returns a boolean value indicating whether the tokenizer
    /// is exhausted.
    pub inline fn isEof(self: *const Self) bool {
        return self.cursor.len == 0;
    }

    fn getAdvanceTo(self: *const Self, tok: u8) ?usize {
        for (self.cursor) |cur, i| {
            if (cur == tok) {
                return i;
            }
        }
        return null;
    }
};

const test_helpers = b: {
    if (!@import("builtin").is_test)
        @compileError("Cannot use test helpers outside of test block");

    break :b struct {
        fn mustRead(t: *Tokenizer, exp: []const u8) !void {
            var s = t.readUntil(' ') orelse return error.ExpectToken;
            try expect(std.mem.eql(u8, s, exp));
        }

        fn expectStrEq(a: []const u8, b: []const u8) !void {
            try expect(std.mem.eql(u8, a, b));
        }
    };
};

test "read tokens delimited by whitespace" {
    const input = "this is a simple string";
    var tokenizer = Tokenizer.init(input);

    try test_helpers.mustRead(&tokenizer, "this");
    try test_helpers.mustRead(&tokenizer, "is");
    try test_helpers.mustRead(&tokenizer, "a");
    try test_helpers.mustRead(&tokenizer, "simple");
    try test_helpers.expectStrEq(tokenizer.readRemains(), "string");
}

test "peek tokens" {
    const input = "ls -a others";
    var tokenizer = Tokenizer.init(input);

    try test_helpers.mustRead(&tokenizer, "ls");
    var maybe_flag = tokenizer.peekUntil(' ') orelse return error.ExpectToken;
    try test_helpers.expectStrEq(maybe_flag, "-a");
    _ = tokenizer.readUntil(' ');
    try test_helpers.expectStrEq(tokenizer.readRemains(), "others");
}
