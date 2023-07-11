const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// A dynamic string that can be mutated at run-time.
pub const String = struct {
    allocator: Allocator,
    buf: ?[]u8,
    len: usize,

    const Self = @This();

    /// Creates a String backed by a specific allocator.
    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator, .buf = null, .len = 0 };
    }

    pub fn deinit(self: *Self) void {
        if (self.buf) |b| {
            self.allocator.free(b);
            self.buf = null;
            self.len = 0;
        }
    }

    /// Appends a slice of string to this string.
    ///
    /// Performance:
    /// Calling this function will not pre-allocate the space
    /// for further appending operations.
    pub fn append(self: *Self, str: []const u8) !void {
        const old_len = self.len;
        const new_len = old_len + str.len;
        var buf = try self.reserve(new_len);

        std.mem.copy(u8, buf[old_len..], str);
        self.len = new_len;
    }

    /// Returns the length of this string.
    pub inline fn len(self: *const Self) usize {
        return self.len;
    }

    /// Returns a read-only slice of this string.
    pub fn get(self: *const Self) ?[]const u8 {
        if (self.buf) |b| {
            return b[0..(self.len)];
        }
        return null;
    }

    fn reserve(self: *Self, n: usize) ![]u8 {
        if (self.buf) |b| {
            assert(n >= b.len);

            // First try reallocating the buffer.
            var new_buf = self.allocator.realloc(b, n) catch null;
            if (new_buf) |nb| {
                self.buf = nb;
                return nb;
            }

            // Cannot realloc in-place, alloc a new buffer,
            // and copy the original contents back.
            var new_buf2 = try self.allocator.alloc(u8, n);
            std.mem.copy(u8, new_buf2, b);
            self.allocator.free(b);
            self.buf = new_buf2;
            return new_buf2;
        } else {
            var new_buf = try self.allocator.alloc(u8, n);
            self.buf = new_buf;
            return new_buf;
        }
    }
};
