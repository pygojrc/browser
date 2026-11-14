// Copyright (C) 2026 pygojrc contributors
// SPDX-License-Identifier: AGPL-3.0-only

const std = @import("std");
const Config = @import("../Config.zig");
const Allocator = std.mem.Allocator;
const Brand = Config.HttpHeaders.Brand;

/// CDP UserAgentMetadata. Optional fields use the selected browser identity.
pub const Input = struct {
    brands: ?[]const Brand = null,
    fullVersionList: ?[]const Brand = null,
    fullVersion: ?[]const u8 = null,
    platform: []const u8,
    platformVersion: []const u8,
    architecture: []const u8,
    model: []const u8,
    mobile: bool,
    bitness: ?[]const u8 = null,
    wow64: ?bool = null,
    formFactors: ?[]const []const u8 = null,

    pub fn validate(self: Input) !void {
        inline for (.{ self.platform, self.platformVersion, self.architecture, self.model }) |value| {
            try Config.validateUserAgent(value);
        }
        if (self.fullVersion) |value| try Config.validateUserAgent(value);
        if (self.bitness) |value| try Config.validateUserAgent(value);
        if (self.formFactors) |values| {
            for (values) |value| try Config.validateUserAgent(value);
        }
        if (self.brands) |brands| try validateBrands(brands);
        if (self.fullVersionList) |brands| try validateBrands(brands);
    }
};

fn validateBrands(brands: []const Brand) !void {
    for (brands) |brand| {
        try Config.validateUserAgent(brand.brand);
        try Config.validateUserAgent(brand.version);
    }
}

/// Owns all data copied from the command arena until the override is cleared.
pub const Stored = struct {
    arena: std.heap.ArenaAllocator,
    brands: []const Brand,
    full_brands: []const Brand,
    full_version: []const u8,
    platform: []const u8,
    platform_version: []const u8,
    architecture: []const u8,
    model: []const u8,
    bitness: []const u8,
    mobile: bool,
    wow64: bool,
    form_factors: []const []const u8,
    brands_header: [:0]const u8,
    full_brands_header: [:0]const u8,
    platform_header: [:0]const u8,

    pub fn init(allocator: Allocator, input: Input, base: *const Config.HttpHeaders.Identity) !Stored {
        var arena = std.heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();
        const a = arena.allocator();
        const brands = try copyBrands(a, input.brands orelse base.brands);
        const full_brands = try copyBrands(a, input.fullVersionList orelse base.full_brands);
        const full_version = input.fullVersion orelse if (full_brands.len > 0) full_brands[0].version else "";
        const factors = input.formFactors orelse &[_][]const u8{"Desktop"};
        const form_factors = try a.alloc([]const u8, factors.len);
        for (factors, 0..) |factor, i| form_factors[i] = try a.dupe(u8, factor);
        const full_version_copy = try a.dupe(u8, full_version);
        const platform = try a.dupe(u8, input.platform);
        const platform_version = try a.dupe(u8, input.platformVersion);
        const architecture = try a.dupe(u8, input.architecture);
        const model = try a.dupe(u8, input.model);
        const bitness = try a.dupe(u8, input.bitness orelse "");
        const brands_header = try formatBrands(a, brands);
        const full_brands_header = try formatBrands(a, full_brands);
        const platform_header = try a.printSentinel("{f}", .{std.json.fmt(input.platform, .{})}, 0);
        return .{
            .arena = arena,
            .brands = brands,
            .full_brands = full_brands,
            .full_version = full_version_copy,
            .platform = platform,
            .platform_version = platform_version,
            .architecture = architecture,
            .model = model,
            .bitness = bitness,
            .mobile = input.mobile,
            .wow64 = input.wow64 orelse false,
            .form_factors = form_factors,
            .brands_header = brands_header,
            .full_brands_header = full_brands_header,
            .platform_header = platform_header,
        };
    }

    pub fn deinit(self: *Stored) void {
        self.arena.deinit();
    }
};

fn copyBrands(a: Allocator, source: []const Brand) ![]const Brand {
    const out = try a.alloc(Brand, source.len);
    for (source, 0..) |brand, i| {
        out[i] = .{ .brand = try a.dupe(u8, brand.brand), .version = try a.dupe(u8, brand.version) };
    }
    return out;
}

fn formatBrands(a: Allocator, brands: []const Brand) ![:0]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    defer out.deinit();
    for (brands, 0..) |brand, i| {
        if (i != 0) try out.writer.writeAll(", ");
        try out.writer.print("{f};v={f}", .{ std.json.fmt(brand.brand, .{}), std.json.fmt(brand.version, .{}) });
    }
    return try a.dupeSentinel(u8, out.written(), 0);
}

test "UserAgentMetadata: copies values and formats headers" {
    const input: Input = .{
        .brands = &.{.{ .brand = "Example", .version = "7" }},
        .fullVersionList = &.{.{ .brand = "Example", .version = "7.1.2.3" }},
        .platform = "ExampleOS",
        .platformVersion = "2.0",
        .architecture = "x86",
        .model = "",
        .mobile = true,
    };
    try input.validate();
    var stored = try Stored.init(std.testing.allocator, input, &Config.HttpHeaders.chrome_identity);
    defer stored.deinit();
    try std.testing.expectEqualStrings("\"Example\";v=\"7\"", stored.brands_header);
    try std.testing.expectEqualStrings("\"Example\";v=\"7.1.2.3\"", stored.full_brands_header);
    try std.testing.expectEqualStrings("\"ExampleOS\"", stored.platform_header);
    try std.testing.expectEqualStrings("7.1.2.3", stored.full_version);
    try std.testing.expect(stored.mobile);
}

test "UserAgentMetadata: rejects control characters" {
    const input: Input = .{
        .platform = "Bad\r\nHeader",
        .platformVersion = "",
        .architecture = "",
        .model = "",
        .mobile = false,
    };
    try std.testing.expectError(error.NonPrintable, input.validate());
}
