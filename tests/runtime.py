"""Exercise installed plugins and media probing through the real daemon API."""

import itertools
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

from PIL import Image
from websockets.sync.client import connect

import control_pb2 as pb


EXPECTED_PLUGINS = {
    "org.waywallen.image",
    "org.waywallen.video",
    "org.waywallen.wallhaven",
    "org.waywallen.open-wallpaper-engine",
}
EXPECTED_RENDERERS = {
    "waywallen-image",
    "waywallen-video",
    "wescene-renderer",
    "weweb-renderer",
}


def wait_for(description, check):
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError(f"Timed out waiting for {description}")


def check_daemon(package, home, images, video, env):
    log_path = home / "daemon.log"
    with log_path.open("w") as log:
        daemon = subprocess.Popen(
            [package / "bin/waywallen", "--no-ui", "--no-display", "--no-restore"],
            env=env,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        try:
            def listening_port():
                assert daemon.poll() is None, "Daemon exited during startup"
                match = re.search(r"ws port: (\d+)", log_path.read_text())
                return int(match[1]) if match else None

            port = wait_for("daemon startup", listening_port)
            request_ids = itertools.count(1)
            with connect(f"ws://127.0.0.1:{port}", proxy=None) as ws:
                def request(field, payload):
                    message = pb.Request(request_id=next(request_ids))
                    getattr(message, field).CopyFrom(payload)
                    ws.send(message.SerializeToString())
                    while True:
                        frame = pb.ServerFrame.FromString(ws.recv(timeout=10))
                        if frame.HasField("response") and frame.response.request_id == message.request_id:
                            response = frame.response
                            assert response.error_code == pb.ERROR_CODE_OK, response
                            return getattr(response, field)

                plugins = request("plugin_list", pb.PluginListRequest())
                assert {plugin.id for plugin in plugins.plugins} == EXPECTED_PLUGINS, plugins
                assert not plugins.inactive_system, plugins

                # Wallhaven is discover-only; the other three plugins expose local sources.
                # Querying both views proves that the Lua imports succeeded.
                wait_for(
                    "all Lua sources",
                    lambda: {
                        source.plugin_id
                        for source in request("source_list", pb.SourceListRequest()).sources
                    } == EXPECTED_PLUGINS - {"org.waywallen.wallhaven"},
                )
                remote = request("remote_availability", pb.RemoteAvailabilityRequest())
                assert {source.owner_plugin_id for source in remote.sources} == {
                    "org.waywallen.wallhaven", "org.waywallen.open-wallpaper-engine",
                }, remote
                translations = request("plugin_translation_list", pb.PluginTranslationListRequest())
                assert {doc.plugin_id for doc in translations.documents if doc.po} == EXPECTED_PLUGINS
                renderers = request("renderer_plugin_list", pb.RendererPluginListRequest())
                assert {renderer.name for renderer in renderers.renderers} == EXPECTED_RENDERERS
                for renderer in renderers.renderers:
                    assert os.access(renderer.bin, os.X_OK), renderer.bin

                # Adding real libraries triggers scanning and the daemon's dlopen-based probe.
                # Check each scan before adding another library to avoid coalescing scan tasks.
                for kind, directory, dimensions in (
                    ("image", images, {"sample.png": (17, 13), "sample.webp": (17, 13), "sample.tiff": (17, 13)}),
                    ("video", video, {"sample.mkv": (32, 24)}),
                ):
                    request("library_add", pb.LibraryAddRequest(path=str(directory), plugin_name=kind))

                    def has_dimensions():
                        entries = request("wallpaper_list", pb.WallpaperListRequest(wp_type=kind))
                        actual = {
                            Path(entry.resource).name: (entry.width, entry.height)
                            for entry in entries.wallpapers
                        }
                        return all(actual.get(name) == size for name, size in dimensions.items())

                    wait_for(f"{kind} dimensions from FFmpeg", has_dimensions)

            # The tray derives this path from current_exe(), not from the outer wrapper.
            executable = Path(f"/proc/{daemon.pid}/exe").resolve()
            icon = executable.parent.parent / "share/icons/hicolor/scalable/apps/org.waywallen.waywallen.svg"
            assert icon.is_file(), f"Missing daemon-relative tray icon: {icon}"
        except BaseException:
            print(log_path.read_text(), file=sys.stderr)
            raise
        finally:
            daemon.terminate()
            try:
                daemon.wait(timeout=10)
            except subprocess.TimeoutExpired:
                daemon.kill()
                daemon.wait()


def main():
    package, image_probe, image_plugins, ui_probe = map(Path, sys.argv[1:])
    with tempfile.TemporaryDirectory(prefix="waywallen-check-") as temp:
        home = Path(temp)
        env = os.environ.copy()
        for key in (
            "LD_LIBRARY_PATH", "QT_PLUGIN_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH",
            "NIXPKGS_QT6_QML_IMPORT_PATH", "DISPLAY", "WAYLAND_DISPLAY",
            "WAYWALLEN_PLUGIN_DIR", "XDG_PICTURES_DIR",
        ):
            env.pop(key, None)
        env.update(HOME=str(home), XDG_DATA_DIRS=str(home / "data"), NO_COLOR="1", RUST_LOG="info")
        for name in ("CONFIG_HOME", "DATA_HOME", "STATE_HOME", "CACHE_HOME", "RUNTIME_DIR"):
            directory = home / name.lower()
            directory.mkdir(mode=0o700)
            env[f"XDG_{name}"] = str(directory)

        images, video = home / "images", home / "video"
        images.mkdir()
        video.mkdir()
        image = Image.new("RGB", (17, 13), "red")
        for extension in ("png", "webp", "tiff"):
            image.save(images / f"sample.{extension}")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=s=32x24:r=1:d=1",
             "-c:v", "ffv1", str(video / "sample.mkv")],
            env=env, check=True, timeout=30,
        )

        check_daemon(package, home, images, video, env)
        print("Plugin registration, translations, Lua sources, media probing and tray icon: OK")

        # makeBinaryWrapper embeds its environment settings in the installed wrapper.
        # Check the UI's actual wrapper so a test-only Qt dependency cannot hide a regression.
        ui = package / "bin/waywallen-ui"
        assert os.fsencode(image_plugins) in ui.read_bytes(), "UI wrapper is missing qtimageformats"
        qt_env = env | {"QT_QPA_PLATFORM": "offscreen", "QT_PLUGIN_PATH": str(image_plugins)}
        subprocess.run([image_probe, images / "sample.webp", images / "sample.tiff"],
                       env=qt_env, check=True, timeout=30)
        ui_result = subprocess.run(
            [ui, "--ws-port", "1"],
            env=env | {"QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                       "LD_PRELOAD": str(ui_probe)},
            capture_output=True, text=True, timeout=30,
        )
        assert ui_result.returncode == 0, (ui_result.returncode, ui_result.stdout, ui_result.stderr)
        assert "UI fonts and Adwaita decoration: OK" in ui_result.stderr, ui_result.stderr
        print("Qt WebP/TIFF decoding, embedded icon fonts and Adwaita decoration: OK")


if __name__ == "__main__":
    main()
