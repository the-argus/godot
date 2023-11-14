const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/object/";

const sources = &.{
    here ++ "callable_method_pointer.cpp",
    here ++ "class_db.cpp",
    here ++ "message_queue.cpp",
    here ++ "method_bind.cpp",
    here ++ "object.cpp",
    here ++ "ref_counted.cpp",
    here ++ "script_language.cpp",
    here ++ "script_language_extension.cpp",
    here ++ "undo_redo.cpp",
    here ++ "worker_thread_pool.cpp",
};

pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    _ = config;
    _ = b;
    state.executable.addCSourceFiles(sources, &.{});
}

fn generateVirtualsIncludeContents() ![]u8 {
    _ = proto;
}

const VirtualsVersionConfig = struct {
    argcout: u32,
    returns: bool,
    constant: bool,

    pub fn toString(self: @This(), ally: std.mem.Allocator) []u8 {
        var dynstring = std.ArrayList(u8).init(ally);
        defer dynstring.deinit();

        const argcount_string = self.argcountString(ally);
        defer ally.free(argcount_string);
        try dynstring.appendSlice(argcount_string);

        if (self.returns) try dynstring.append('R');
        if (self.constant) try dynstring.append('C');
        return dynstring.toOwnedSlice();
    }

    pub fn argcountString(self: @This(), ally: std.mem.Allocator) []u8 {
        return std.fmt.allocPrint(ally, "{any}", .{self.argcount}) catch @panic("OOM");
    }
};

fn generateVersionOfVirtuals(ally: std.mem.Allocator, config: VirtualsVersionConfig) ![]u8 {
    var method_info = std.ArrayList(u8).init(ally);
    defer method_info.deinit();

    var replacements: ProtoReplacementFields = .{};

    replacements.ret = if (config.returns) "m_ret, " else "";
    // If required, may lead to uninitialized errors
    replacements.rvoid = if (config.returns) "(void)r_ret;" else "";
    replacements.callptrretdef = if (config.returns) "PtrToArg<m_ret>::EncodeT ret;" else "";

    if (config.returns) {
        try method_info.appendSlice(
            \\	method_info.return_val = GetTypeInfo<m_ret>::get_class_info();
            \\	method_info.return_val_metadata = GetTypeInfo<m_ret>::METADATA;
        );
    }

    replacements.@"const" = if (config.constant) "const" else "";

    if (config.constant)
        try method_info.appendSlice(
            \\	method_info.flags|=METHOD_FLAG_CONST;
        );

    replacements.ver = try config.toString(ally);

    var argtext = std.ArrayList(u8).init(ally);
    var callargtext = std.ArrayList(u8).init(ally);
    var callsiargs = std.ArrayList(u8).init(ally);
    var callsiargptrs = std.ArrayList(u8).init(ally);
    var callptrargsptr = std.ArrayList(u8).init(ally);
    var callptrargs = std.ArrayList(u8).init(ally);

    defer {
        argtext.deinit();
        callargtext.deinit();
        callsiargs.deinit();
        callsiargptrs.deinit();
        callptrargsptr.deinit();
        callptrargs.deinit();
    }

    const argcount_string = config.argcountString(ally);
    defer ally.free(argcount_string);

    // zig really needs a string type in the stdlib
    if (config.argcount > 0) {
        try argtext.appendSlice(", ");
        const appended_text = try std.fmt.allocPrint(ally, "Variant vargs[{s}]={", .{argcount_string});
        const appended_text_1 = try std.fmt.allocPrint(ally, "\t\tconst Variant *vargptrs[{s}]={", .{argcount_string});
        const appended_text_2 = try std.fmt.allocPrint(ally, "\t\tGDExtensionConstTypePtr argptrs[{s}]={", .{argcount_string});
        defer ally.free(appended_text);
        try callsiargs.appendSlice(appended_text);
        try callsiargptrs.appendSlice(appended_text_1);
        try callptrargsptr.appendSlice(appended_text_2);
    }

    for (0..config.argcount) |index| {
        if (index > 0) {
            for (&.{ argtext, callargtext, callsiargs, callsiargptrs, callptrargsptr }) |string| {
                try string.appendSlice(", ");
            }
            try callptrargs.appendSlice("\t\t");
        }

        const iplusone = try std.fmt.allocPrint(ally, "{any}", .{index + 1});
        defer ally.free(iplusone);
        const index_string = try std.fmt.allocPrint(ally, "{any}", .{index});
        defer ally.free(index_string);

        const formatted_text_1 = try std.fmt.allocPrint(ally, "m_type{s}", .{iplusone});
        defer ally.free(formatted_text_1);
        const formatted_text_2 = try std.fmt.allocPrint(ally, "m_type{s} arg{s}", .{ iplusone, iplusone });
        defer ally.free(formatted_text_2);
        const formatted_text_3 = try std.fmt.allocPrint(ally, "Variant(arg{s})", .{iplusone});
        defer ally.free(formatted_text_3);
        const formatted_text_4 = try std.fmt.allocPrint(ally, "&vargs[{s}]", .{index_string});
        defer ally.free(formatted_text_4);
        const formatted_text_5 = try std.fmt.allocPrint(ally, "PtrToArg<m_type{s}>::EncodeT argval{s} = arg{s};\n", .{ iplusone, iplusone, iplusone });
        defer ally.free(formatted_text_5);
        const formatted_text_6 = try std.fmt.allocPrint(ally, "&argval{s}", .{iplusone});
        defer ally.free(formatted_text_6);

        const formatted_text_method_info = try std.fmt.allocPrint(ally,
            \\	method_info.arguments.push_back(GetTypeInfo<m_type{s}>::get_class_info());
            \\	method_info.arguments_metadata.push_back(GetTypeInfo<m_type{s}>::METADATA);
            \\
        , .{ iplusone, iplusone });
        defer ally.free(formatted_text_method_info);

        try argtext.appendSlice(formatted_text_1);
        try callargtext.appendSlice(formatted_text_2);
        try callsiargs.appendSlice(formatted_text_3);
        try callsiargptrs.appendSlice(formatted_text_4);
        try callptrargs.appendSlice(formatted_text_5);
        try callptrargsptr.appendSlice(formatted_text_6);

        try method_info.appendSlice(formatted_text_method_info);
    }

    if (config.argcount > 0) {
        for (&.{ callsiargs, callsiargptrs, callptrargsptr }) |string| {
            try string.appendSlice("};\n");
        }

        try callsiargs.appendSlice(callsiargptrs.items);
        try callptrargs.appendSlice(callptrargsptr.items);
    }

    replacements.callsiargs = if (config.argcout > 0) callsiargs.items else "";
    const maybe_callsiargpass = try std.fmt.allocPrint(ally, "(const Variant **)vargptrs,{s}", .{argcount_string});
    defer ally.free(maybe_callsiargpass);
    replacements.callsiargpass = if (config.argcout > 0) maybe_callsiargpass else "nullptr, 0";
    replacements.callptrargs = if (config.argcout > 0) callptrargs.items else "";
    replacements.callptrargpass = if (config.argcout > 0) "reinterpret_cast<GDExtensionConstTypePtr*>(argptrs)" else "nullptr";

    if (config.returns) {
        if (config.argcount > 0) try callargtext.appendSlice(",");
        try callargtext.appendSlice(" m_ret& r_ret");
    }
    replacements.callsibegin = if (config.returns) "Variant ret = " else "";
    replacements.callsiret = if (config.returns) "r_ret = VariantCaster<m_ret>::cast(ret);" else "";
    replacements.callptrretpass = if (config.returns) "&ret" else "nullptr";
    replacements.callptrret = if (config.returns) "r_ret = (m_ret)ret;" else "";

    replacements.arg = argtext.items;
    replacements.callargs = callargtext.items;
    replacements.fill_method_info = method_info.items;

    var string_buffer_ping: [256]u8 = undefined;
    var string_buffer_pong: [256]u8 = undefined;
    var buffer = ally.alloc(u8, proto.len);
    @memcpy(buffer, proto);

    for (@typeInfo(@TypeOf(replacements)).Struct.fields) |field| {
        const uppercase = std.ascii.upperString(string_buffer_ping, field.name);
        const iden = std.fmt.bufPrint(string_buffer_pong, "${s}", .{uppercase}) catch @panic("unable to do string formatting with buffer allocation");
        const space_needed = std.mem.replacementSize(u8, proto, iden, @field(replacements, field.name));
        try ally.realloc(buffer, space_needed);
        std.mem.replace(u8, buffer, iden, @field(replacements, field.name), buffer);
    }

    return buffer;
}

const ProtoReplacementFields = struct {
    fill_method_info: ?[]u8,
    callargs: ?[]u8,
    arg: ?[]u8,
    callptrret: ?[]u8,
    callptrretpass: ?[]u8,
    callsiret: ?[]u8,
    callsibegin: ?[]u8,
    callptrargpass: ?[]u8,
    callptrargs: ?[]u8,
    callsiargpass: ?[]u8,
    callsiargs: ?[]u8,
    ver: ?[]u8,
    @"const": ?[]u8,
    rvoid: ?[]u8,
    ret: ?[]u8,
    callptrretdef: ?[]u8,
};

const proto =
    \\ #define GDVIRTUAL$VER($RET m_name $ARG)
    \\ StringName _gdvirtual_##m_name##_sn = #m_name;
    \\ mutable bool _gdvirtual_##m_name##_initialized = false;
    \\ mutable GDExtensionClassCallVirtual _gdvirtual_##m_name = nullptr;
    \\ template<bool required>
    \\ _FORCE_INLINE_ bool _gdvirtual_##m_name##_call($CALLARGS) $CONST {
    \\	ScriptInstance *_script_instance = ((Object*)(this))->get_script_instance();
    \\	if (_script_instance) {
    \\		Callable::CallError ce;
    \\		$CALLSIARGS
    \\		$CALLSIBEGIN_script_instance->callp(_gdvirtual_##m_name##_sn, $CALLSIARGPASS, ce);
    \\		if (ce.error == Callable::CallError::CALL_OK) {
    \\			$CALLSIRET
    \\			return true;
    \\		}
    \\	}
    \\   if (unlikely(_get_extension() && !_gdvirtual_##m_name##_initialized)) {
    \\        /* TODO: C-style cast because GDExtensionStringNamePtr's const qualifier is broken (see https://github.com/godotengine/godot/pull/67751) */
    \\        _gdvirtual_##m_name = (_get_extension() && _get_extension()->get_virtual) ? _get_extension()->get_virtual(_get_extension()->class_userdata, (GDExtensionStringNamePtr)&_gdvirtual_##m_name##_sn) : (GDExtensionClassCallVirtual) nullptr;
    \\        _gdvirtual_##m_name##_initialized = true;
    \\    }
    \\	if (_gdvirtual_##m_name) {
    \\		$CALLPTRARGS
    \\		$CALLPTRRETDEF
    \\		_gdvirtual_##m_name(_get_extension_instance(),$CALLPTRARGPASS,$CALLPTRRETPASS);
    \\		$CALLPTRRET
    \\		return true;
    \\	}
    \\
    \\	if (required) {
    \\	        ERR_PRINT_ONCE("Required virtual method " + get_class() + "::" + #m_name + " must be overridden before calling.");
    \\	        $RVOID
    \\   }
    \\
    \\    return false;
    \\}
    \\_FORCE_INLINE_ bool _gdvirtual_##m_name##_overridden() const {
    \\	ScriptInstance *_script_instance = ((Object*)(this))->get_script_instance();
    \\	if (_script_instance) {
    \\	    return _script_instance->has_method(_gdvirtual_##m_name##_sn);
    \\	}
    \\   if (unlikely(_get_extension() && !_gdvirtual_##m_name##_initialized)) {
    \\        /* TODO: C-style cast because GDExtensionStringNamePtr's const qualifier is broken (see https://github.com/godotengine/godot/pull/67751) */
    \\        _gdvirtual_##m_name = (_get_extension() && _get_extension()->get_virtual) ? _get_extension()->get_virtual(_get_extension()->class_userdata, (GDExtensionStringNamePtr)&_gdvirtual_##m_name##_sn) : (GDExtensionClassCallVirtual) nullptr;
    \\ _gdvirtual_##m_name##_initialized = true;
    \\    }
    \\	if (_gdvirtual_##m_name) {
    \\	    return true;
    \\	}
    \\	return false;
    \\}
    \\
    \\_FORCE_INLINE_ static MethodInfo _gdvirtual_##m_name##_get_method_info() {
    \\    MethodInfo method_info;
    \\    method_info.name = #m_name;
    \\    method_info.flags = METHOD_FLAG_VIRTUAL;
    \\    $FILL_METHOD_INFO
    \\    return method_info;
    \\}
    \\
;
