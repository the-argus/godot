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

    const RET = if (config.returns) "m_ret, " else "";
    _ = RET;
    // If required, may lead to uninitialized errors
    const RVOID = if (config.returns) "(void)r_ret;" else "";
    _ = RVOID;
    const CALLPTRRETDEF = if (config.returns) "PtrToArg<m_ret>::EncodeT ret;" else "";
    _ = CALLPTRRETDEF;

    if (config.returns) {
        try method_info.appendSlice(
            \\	method_info.return_val = GetTypeInfo<m_ret>::get_class_info();
            \\	method_info.return_val_metadata = GetTypeInfo<m_ret>::METADATA;
        );
    }

    const CONST = if (config.constant) "const" else "";
    _ = CONST;

    if (config.constant)
        try method_info.appendSlice(
            \\	method_info.flags|=METHOD_FLAG_CONST;
        );

    const VER = try config.toString(ally);
    _ = VER;

    var argtext = std.ArrayList(u8).init(ally);
    var callargtext = std.ArrayList(u8).init(ally);
    var callsiargs = std.ArrayList(u8).init(ally);
    var callsiargptrs = std.ArrayList(u8).init(ally);
    var callptrargsptr = std.ArrayList(u8).init(ally);
    var callptrargs = std.ArrayList(u8).init(ally);

    const argcount_string = config.argcountString(ally);
    defer ally.free(argcount_string);

    defer {
        argtext.deinit();
        callargtext.deinit();
        callsiargs.deinit();
        callsiargptrs.deinit();
        callptrargsptr.deinit();
        callptrargs.deinit();
    }

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

        try argtext.appendSlice("");
    }

    // for i in range(argcount):
    //     if i > 0:
    //         argtext += ", "
    //         callargtext += ", "
    //         callsiargs += ", "
    //         callsiargptrs += ", "
    //         callptrargs += "\t\t"
    //         callptrargsptr += ", "
    //     argtext += "m_type" + str(i + 1)
    //     callargtext += "m_type" + str(i + 1) + " arg" + str(i + 1)
    //     callsiargs += "Variant(arg" + str(i + 1) + ")"
    //     callsiargptrs += "&vargs[" + str(i) + "]"
    //     callptrargs += (
    //         "PtrToArg<m_type" + str(i + 1) + ">::EncodeT argval" + str(i + 1) + " = arg" + str(i + 1) + ";\\\n"
    //     )
    //     callptrargsptr += "&argval" + str(i + 1)
    //     method_info += "\tmethod_info.arguments.push_back(GetTypeInfo<m_type" + str(i + 1) + ">::get_class_info());\\\n"
    //     method_info += (
    //         "\tmethod_info.arguments_metadata.push_back(GetTypeInfo<m_type" + str(i + 1) + ">::METADATA);\\\n"
    //     )

    // if argcount:
    //     callsiargs += "};\\\n"
    //     callsiargptrs += "};\\\n"
    //     s = s.replace("$CALLSIARGS", callsiargs + callsiargptrs)
    //     s = s.replace("$CALLSIARGPASS", "(const Variant **)vargptrs," + str(argcount))
    //     callptrargsptr += "};\\\n"
    //     s = s.replace("$CALLPTRARGS", callptrargs + callptrargsptr)
    //     s = s.replace("$CALLPTRARGPASS", "reinterpret_cast<GDExtensionConstTypePtr*>(argptrs)")
    // else:
    //     s = s.replace("$CALLSIARGS", "")
    //     s = s.replace("$CALLSIARGPASS", "nullptr, 0")
    //     s = s.replace("$CALLPTRARGS", "")
    //     s = s.replace("$CALLPTRARGPASS", "nullptr")

    // if returns:
    //     if argcount > 0:
    //         callargtext += ","
    //     callargtext += " m_ret& r_ret"
    //     s = s.replace("$CALLSIBEGIN", "Variant ret = ")
    //     s = s.replace("$CALLSIRET", "r_ret = VariantCaster<m_ret>::cast(ret);")
    //     s = s.replace("$CALLPTRRETPASS", "&ret")
    //     s = s.replace("$CALLPTRRET", "r_ret = (m_ret)ret;")
    // else:
    //     s = s.replace("$CALLSIBEGIN", "")
    //     s = s.replace("$CALLSIRET", "")
    //     s = s.replace("$CALLPTRRETPASS", "nullptr")
    //     s = s.replace("$CALLPTRRET", "")

    // s = s.replace("$ARG", argtext)
    // s = s.replace("$CALLARGS", callargtext)
    // s = s.replace("$FILL_METHOD_INFO", method_info)

    // return s
}

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
