const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/io/";

const sources = &.{
    here ++ "compression.cpp",
    here ++ "config_file.cpp",
    here ++ "dir_access.cpp",
    here ++ "dtls_server.cpp",
    here ++ "file_access.cpp",
    here ++ "file_access_compressed.cpp",
    here ++ "file_access_encrypted.cpp",
    here ++ "file_access_memory.cpp",
    here ++ "file_access_pack.cpp",
    here ++ "file_access_zip.cpp",
    here ++ "http_client.cpp",
    here ++ "http_client_tcp.cpp",
    here ++ "image.cpp",
    here ++ "image_loader.cpp",
    here ++ "ip.cpp",
    here ++ "ip_address.cpp",
    here ++ "json.cpp",
    here ++ "logger.cpp",
    here ++ "marshalls.cpp",
    here ++ "missing_resource.cpp",
    here ++ "net_socket.cpp",
    here ++ "packed_data_container.cpp",
    here ++ "packet_peer.cpp",
    here ++ "packet_peer_dtls.cpp",
    here ++ "packet_peer_udp.cpp",
    here ++ "pck_packer.cpp",
    here ++ "remote_filesystem_client.cpp",
    here ++ "resource.cpp",
    here ++ "resource_format_binary.cpp",
    here ++ "resource_importer.cpp",
    here ++ "resource_loader.cpp",
    here ++ "resource_saver.cpp",
    here ++ "resource_uid.cpp",
    here ++ "stream_peer.cpp",
    here ++ "stream_peer_gzip.cpp",
    here ++ "stream_peer_tcp.cpp",
    here ++ "stream_peer_tls.cpp",
    here ++ "tcp_server.cpp",
    here ++ "translation_loader_po.cpp",
    here ++ "udp_server.cpp",
    here ++ "xml_parser.cpp",
    here ++ "zip_io.cpp",
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
