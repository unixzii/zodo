const std = @import("std");
const Mutex = std.Thread.Mutex;

var mutex = Mutex{};
var cached_value: ?[]u8 = null;

fn getHomeDirInnerLocked(allocator: std.mem.Allocator) ![]u8 {
    var envs = try std.process.getEnvMap(allocator);
    defer envs.deinit();

    // TODO we may need to use an alternative way to retrieve the
    // home path on Windows.
    var home_val = envs.get("HOME") orelse return error.NoEnvVar;
    return allocator.dupe(u8, home_val);
}

/// Returns a slice representing the home path of the
/// current user. Caller doesn't own the slice and must
/// not free it. This function is thread-safe.
pub fn getHomeDir() ![]const u8 {
    mutex.lock();
    defer mutex.unlock();

    if (cached_value) |v| {
        return v;
    }

    var v = try getHomeDirInnerLocked(std.heap.c_allocator);
    cached_value = v;
    return v;
}
