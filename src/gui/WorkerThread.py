import os
import shutil
import subprocess
import time
from pathlib import Path
import sys
from dataclasses import dataclass
import json
import select
import queue
import threading
from typing import Callable
import hashlib

import PySide6.QtCore as QtCore

from InstallerParams import InstallerParams
from ProcessingDialog import ProcessingDialog
from DeletePathThread import DeletePathThread
from gui_exceptions import InterruptException
from PluginData import PluginData

# Create a STARTUPINFO object
STARTUPINFO_NO_CONSOLE = subprocess.STARTUPINFO()
STARTUPINFO_NO_CONSOLE.dwFlags |= subprocess.STARTF_USESHOWWINDOW
STARTUPINFO_NO_CONSOLE.wShowWindow = subprocess.SW_HIDE

LOOSE_FILES_PLUGIN_NAME = "Loose Files"


@dataclass
class ArchiveSettings:
    compression: str
    maxSizeMB: int
    _format: str
    name: str
    dir_names: list[str]


class WorkerThread(QtCore.QThread):
    output_received = QtCore.Signal(str)
    exception_occurred = QtCore.Signal(Exception, type, object)
    task_done = QtCore.Signal()

    def __init__(
            self,
            fnv_path: Path,
            fo4_path: Path,
            extracted_path: Path,
            temp_path: Path,
            output_path: Path,
            resources: list[PluginData],
            installer_params: InstallerParams,
    ):
        super().__init__()

        # self.archives = [
        #     resource for resource in resources if resource.suffix == ".bsa"]
        # self.plugins = [
        #     resource for resource in resources
        #     if resource.suffix in {".esp", ".esm"}
        # ]
        self.plugins = resources

        self.cwd = Path(os.getcwd())
        self.output_path = output_path
        self.extracted_path = extracted_path
        self.temp_path = temp_path
        self.mutex = QtCore.QMutex()
        self.failed = False
        self.interrupted = False
        self._stop_flag = False
        self.installer_params = installer_params
        self.fnv_path = fnv_path
        self.fo4_path = fo4_path

        self.x_edit_converter_path = self.cwd / "build\\xedit_converter"
        self.x_edit_data_path = self.x_edit_converter_path / "data"
        self.x_edit_exe_path = self.x_edit_converter_path / "xEdit.exe"
        self.x_convert_exe_path = self.x_edit_converter_path / "xConvert.exe"

    def run(self):
        try:
            for plugin in self.plugins:
                if (self.fo4_path / "data" / plugin.name).exists():
                    continue

                if not self.installer_params.skip_bsas:
                    bsas = []
                    loose_files = []

                    for path in plugin.resources:
                        if path.suffix == ".bsa":
                            bsas.append(path)
                        else:
                            loose_files.append(path)

                    self.extract_bsas(bsas)

                    self.extract_loose_files(loose_files)

                self.remove_crash_causing_files()

                if (self.extracted_path / "meshes").exists():
                    if not self.installer_params.skip_lod_settings:
                        self.copy_lod_settings()

                    if not self.installer_params.skip_meshes:
                        self.convert_meshes()

                    if self.installer_params.all_objects_cast_shadows:
                        self.set_cast_shadows()

                    if not self.installer_params.skip_optimize:
                        self.optimize_meshes()

                    self.move_materials()

                    self.replace_data_files(plugin)

                if plugin.name != LOOSE_FILES_PLUGIN_NAME:
                    # TODO: If loose files are used create a dummy esp so the
                    #  resources get loaded.
                    if not self.installer_params.skip_ba2_creation:
                        self.create_archive(name=plugin.path.stem)

                    self.clear_temp_and_extracted()

                    # if not self.installer_params.skip_data:
                    #     self.copy_data_files()

                    if not self.installer_params.skip_plugin_convert:
                        self.convert_plugin_data(plugin)

            if (not self.installer_params.skip_plugin_move and
                    not self.installer_params.skip_plugin_convert):
                for plugin in self.plugins:
                    if plugin.name == LOOSE_FILES_PLUGIN_NAME:
                        continue

                    self.move_plugin_to_output(plugin)
        except InterruptException:
            self.interrupted = True
        except Exception as e:
            self.failed = True

            exc_type, exc_value, tb = sys.exc_info()
            self.exception_occurred.emit(e, exc_type, tb)

            if self.installer_params.debug:
                raise

        self.task_done.emit()

    def stop(self):
        self.mutex.lock()
        self._stop_flag = True
        self.mutex.unlock()

    def stop_requested(self):
        self.mutex.lock()

        if self._stop_flag:
            self.mutex.unlock()

            return True

        self.mutex.unlock()

        return False

    def stop_if_requested(self):
        if self.stop_requested():
            raise InterruptException()

    def set_cast_shadows(self):
        self.output_received.emit("Making all objects cast shadows...\n")

        path = self.temp_path / "materials"

        if not path.exists():
            self.output_received.emit(
                "Making all objects cast shadows... [SKIPPED (no materials to process)]\n"
            )

            return

        for root, dirs, files in os.walk(path):
            for file in files:
                self.stop_if_requested()

                with open(os.path.join(root, file), "r") as f:
                    try:
                        _dict = json.load(f)
                    except json.JSONDecodeError:
                        continue

                _dict["bCastShadows"] = True

                with open(os.path.join(root, file), "w") as f:
                    json.dump(_dict, f, indent=4)

        self.output_received.emit("Making all objects cast shadows... [DONE]\n")

    def create_archive(self, name: str):
        self.output_received.emit("Creating archives...\n")

        archive2_path = self.fo4_path / "Tools" / "Archive2" / "Archive2.exe"

        # TODO: Create ba2 archives.
        # Change cwd to output directory when running.
        # & "C:\Program Files (x86)\Steam\steamapps\common\Fallout 4\Tools\Archive2\Archive2.exe" "C:\Users\TheHa\projects\fallout-related\FNV_to_FO4\output\meshes" -create="FalloutNV.ba2" -root="C:\Users\TheHa\projects\fallout-related\FNV_to_FO4\output" -format=General -compression=Default -maxSizeMB=1500 -tempFiles

        for archive_settings in [
            ArchiveSettings(
                name="Main",
                compression="Default",
                maxSizeMB=4095,
                _format="General",
                dir_names=["meshes", "materials"],
            ),
            ArchiveSettings(
                name="Textures",
                compression="Default",
                maxSizeMB=4095,
                _format="DDS",
                dir_names=["textures"],
            ),
        ]:
            file_name = f"{name} - {archive_settings.name}.ba2"

            folder_paths_str = ",".join([
                f"\"{str(self.output_path / dir_name)}\"" for dir_name in
                archive_settings.dir_names
            ])

            cmd = (
                f"\"{str(archive2_path)}\" "
                f"{folder_paths_str} "
                f"-create=\"{file_name}\" "
                f"-root=\"{str(self.output_path)}\" "
                f"-format={archive_settings._format} "
                f"-compression={archive_settings.compression} "
                f"-maxSizeMB={archive_settings.maxSizeMB} "
                "-tempFiles "
            )

            self.run_frequent_output_task(cmd=cmd, cwd=self.output_path)

        self.output_received.emit("Creating archives... [DONE]\n")

    def delete_all_in_directory(self, root_dir):
        if not Path(root_dir).is_dir():
            return

        # List all files and directories in the current directory
        for item in os.listdir(root_dir):
            self.stop_if_requested()

            item_path = os.path.join(root_dir, item)

            # If it's a directory, recursively delete its contents
            if os.path.isdir(item_path):
                self.delete_all_in_directory(item_path)

                os.rmdir(item_path)
            else:
                os.remove(item_path)

    def remove_paths(self, paths):
        for path in paths:
            self.stop_if_requested()

            self.output_received.emit(f"Deleting \"{path}\"...\n")

            if path.is_file():
                path.unlink()

            self.delete_all_in_directory(path)

            if path.exists():
                # noinspection PyBroadException
                path.rmdir()


    def clear_temp_and_extracted(self):
        self.output_received.emit("Clearing temp directories...\n")

        paths_to_remove = [
            self.temp_path,
            self.extracted_path,
        ]

        if not self.installer_params.skip_ba2_creation:
            paths_to_remove.extend([
                self.output_path / "textures",
                self.output_path / "Materials",
                self.output_path / "meshes",
                self.output_path / "Music",
                self.output_path / "Sound",
            ])

        self.remove_paths(paths_to_remove)

        # Recreate the directories.
        self.temp_path.mkdir(exist_ok=True)
        self.extracted_path.mkdir(exist_ok=True)
        self.output_path.mkdir(exist_ok=True)

        # processing_dialog = ProcessingDialog(DeletePathThread([
        #     self.temp_path,
        #     self.extracted_path,
        #     self.output_path / "textures",
        #     self.output_path / "Materials",
        #     self.output_path / "meshes",
        #     self.output_path / "Music",
        #     self.output_path / "Sound",
        # ]))
        #
        # processing_dialog.exec()
        #
        # if processing_dialog.worker.interrupted:
        #     raise InterruptException
        #
        # if processing_dialog.worker.failed:
        #     self.output_received.emit("Failed to clear directories.\n")
        #
        #     raise InterruptException

        self.output_received.emit("Clearing temp directories... [DONE]\n")

    def run_frequent_output_task(self, cmd: list[str] | str, cwd: Path = None):
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            # text=True,
            shell=False,
            startupinfo=STARTUPINFO_NO_CONSOLE,
            cwd=cwd,
        )

        for line in process.stdout:
            try:
                s = line.decode("utf-8")
            except UnicodeDecodeError:
                s = line.decode("cp1252")

            self.output_received.emit(s)

            if self.stop_requested():
                process.kill()

                raise InterruptException

    def rename_textures(
            self, nested_textures_path: Path, output_path_textures: Path):
        n_tries = 100

        for i in range(n_tries):
            try:
                nested_textures_path.rename(output_path_textures / "new_vegas")
            except PermissionError:
                if i == n_tries - 1:
                    raise

                self.output_received.emit(
                    "WARNING: Failed to rename textures directory. "
                    "Retrying...\n")
            else:
                self.output_received.emit(
                    "Renamed textures directory to \"new_vegas\"\n")

                break

            time.sleep(1)

    def remove_fnv_path(self, sub_path: Path):
        base_path = self.fnv_path / "data"

        if not self.fnv_path / "data" in sub_path.parents:
            raise ValueError(
                f"Resource {sub_path} is not in the Fallout "
                f"New Vegas data directory")

        # Get the parts of both paths
        base_parts = base_path.parts
        sub_parts = sub_path.parts

        # Reconstruct the sub_path without the base_path
        relative_path = Path(*sub_parts[len(base_parts):])

        return relative_path

    def remove_crash_causing_files(self):
        crash_causing_files = [
            (
                self.output_path / r"textures\new_vegas\Clutter\junk\wooddetails_n.dds",
                '9c48e1658dc235dd8be8bf2b55b247cb98964e44759ba17632d43a33383fbf22'
            )
        ]

        for path, crash_digest in crash_causing_files:
            if not path.exists():
                continue

            with open(path, 'rb', buffering=0) as f:
                digest = hashlib.file_digest(f, 'sha256').hexdigest()

            if digest == crash_digest:
                os.remove(path)

    def extract_loose_files(self, loose_files: list[Path]):
        self.output_received.emit("Copying loose files...\n")

        for path in loose_files:
            relative_path = self.remove_fnv_path(path)

            root_dir = relative_path.parts[0].lower()

            if root_dir == "textures":
                path_dst = (self.output_path / "textures" / "new_vegas" /
                            Path(*relative_path.parts[1:]))
            elif root_dir == "meshes":
                path_dst = self.extracted_path / relative_path

                copy_file_or_dir(path, path_dst)
            # TODO:
            elif path.suffix.lower() == ".nam":
                continue
            else:
                raise NotImplementedError(
                    f"Resource {path} is not supported")

            copy_file_or_dir(path, path_dst)

        self.output_received.emit("Copying loose files... [DONE]\n")

    def extract_bsas(self, archives: list[Path]):
        if not archives:
            return

        path_bsab = self.cwd / "bin" / "bsab" / "bsab.exe"

        argument_list_meshes = [path_bsab, "-e", "-f", "meshes"]
        argument_list_textures = [path_bsab, "-e", "-f", "textures"]

        for archive in archives:
            if (str(archive)).lower().endswith(".nam"):
                continue

            argument_list_meshes.append(str(archive))
            argument_list_textures.append(str(archive))

        output_path_textures = self.output_path / "textures"

        output_path_textures.mkdir(parents=True, exist_ok=True)

        argument_list_meshes.append(str(self.extracted_path))
        argument_list_textures.append(str(output_path_textures))

        self.output_received.emit("Extracting meshes...\n")

        self.run_frequent_output_task(argument_list_meshes)

        self.output_received.emit("Extracting meshes... [DONE]\n")

        self.output_received.emit("Extracting textures...\n")

        self.run_frequent_output_task(argument_list_textures)

        self.output_received.emit("Extracting textures... [DONE]\n")

        try:
            subprocess.run(
                ["takeown", "/f", str(output_path_textures)],
                startupinfo=STARTUPINFO_NO_CONSOLE,
                check=True,
            )
        except subprocess.CalledProcessError:
            self.output_received.emit(
                "WARNING: Failed to take ownership of textures directory\n")

        nested_textures_path = output_path_textures / "textures"

        if nested_textures_path.exists():
            self.rename_textures(nested_textures_path, output_path_textures)

    def run_long_task(self, cmd: list[str] | str, cwd: Path = None,
                      shell=False):
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            shell=shell,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        while True:
            retcode = process.poll()

            # Process has finished.
            if retcode is not None:
                break

            if self.stop_requested():
                process.kill()

                raise InterruptException

            time.sleep(0.2)

    def run_long_task_with_output(
            self, cmd: list[str] | str, cwd: Path = None, shell=False,
            line_callback: Callable = None):
        # Start the subprocess
        process = subprocess.Popen(
            cmd,
            cwd=cwd,
            shell=shell,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            startupinfo=STARTUPINFO_NO_CONSOLE,
            text=True
        )

        # Create a queue to hold the output
        q = queue.Queue()

        def enqueue_output(out, queue):
            try:
                for line in iter(out.readline, ''):
                    queue.put(line)
            finally:
                out.close()

        # Start a thread to read the output
        t = threading.Thread(target=enqueue_output, args=(process.stdout, q))
        t.daemon = True
        t.start()

        # Read line without blocking
        while True:
            if process.poll() is not None:
                break

            if self.stop_requested():
                process.kill()
                t.join()

                raise InterruptException

            try:
                line = q.get(timeout=.2)
            except queue.Empty:
                pass
            else:
                if line_callback is not None:
                    try:
                        line_callback(line)
                    except InterruptException:
                        process.kill()
                        t.join()

                        raise InterruptException

                # Process the line
                self.output_received.emit(line)

    def convert_meshes(self):
        self.output_received.emit("Converting meshes...\n")

        path_nifskope = (
                self.cwd / "build\\nifskope_converter\\release\\NifSkope.exe")

        cmd = [
            path_nifskope,
            "--convert",
            str(self.temp_path),
            str(self.extracted_path),
            str(self.extracted_path),
        ]

        self.run_long_task(cmd)

        self.output_received.emit("Converting meshes... [DONE]\n")

    def optimize_meshes(self):
        self.output_received.emit("Optimizing meshes...\n")

        elric_path = self.fo4_path / "Tools" / "Elric" / "Elrich.exe"
        convert_target = self.temp_path / "meshes"
        elric_output_path = self.output_path / "meshes"

        # Remove meshes that are known to cause problems.
        for rel_path in [
            "Terrain\\nvdlc03bigmt\\nvdlc03bigmt.16.-32.-32.BTR",
        ]:
            path = self.temp_path / rel_path

            if path.exists():
                self.output_received.emit(f"Skipping {rel_path}\n")

                os.remove(path)

        for _ in range(100):
            failed = False

            self.stop_if_requested()

            command = [
                '"' + str(elric_path) + '"',
                ".\\Settings\\PCMeshes.esf",
                f"-ElricOptions.ConvertTarget=\"{str(convert_target)}\"",
                f"-ElricOptions.OutputDirectory=\"{str(elric_output_path)}\"",
            ]
            command = " ".join(command)

            self.run_long_task(
                command,
                cwd=self.cwd / "src\\models-and-animations\\elric\\",
            )

            source_files_path = os.path.join(str(self.temp_path), "meshes")
            source_files = [os.path.join(dp, f) for dp, dn, filenames in
                            os.walk(source_files_path) for f in filenames]
            existing_files = []

            for file in source_files:
                self.stop_if_requested()

                relative_path = file.removeprefix(str(self.temp_path) + "\\")
                dest_path = self.output_path / relative_path

                if not os.path.isfile(dest_path):
                    if not failed:
                        self.output_received.emit("[FAILED]\n")

                    self.output_received.emit(f"Failed: {relative_path}\n")

                    os.remove(file)
                    failed = True

                    break

                existing_files.append(file)

            for file in existing_files:
                self.stop_if_requested()

                os.remove(file)

            if not failed:
                break

        self.output_received.emit("Optimizing meshes... [DONE]\n")

    def move_materials(self):
        self.output_received.emit("Moving materials...\n")

        if not (self.temp_path / "materials").exists():
            print("No materials to move")

            self.output_received.emit("Moving materials... [DONE]\n")

            return

        shutil.move(
            src=str(self.temp_path / "materials"),
            dst=str(self.output_path / "materials"),
        )

        self.output_received.emit("Moving materials... [DONE]\n")

    def copy_data_files(self):
        self.output_received.emit("Copying data files...\n")

        data_files_dir = self.cwd / "src" / "data"

        # Iterate over the files and subdirectories in the source directory
        for item in data_files_dir.iterdir():
            source_item = os.path.join(data_files_dir, item)

            destination_item = self.output_path / item.name

            if os.path.isdir(source_item):
                shutil.copytree(
                    source_item, destination_item, dirs_exist_ok=True)
            else:
                shutil.copy(source_item, destination_item)

        self.output_received.emit("Copying data files... [DONE]\n")

    def copy_lod_settings(self):
        self.output_received.emit("Copying LOD settings...\n")

        lod_settings_path = Path("src\\data\\LODSettings\\WastelandNV.LOD")
        terrain_path = self.extracted_path / "meshes" / "landscape" / "lod"

        if terrain_path.exists():
            lod_settings_dir_new = self.output_path / "LODSettings"

            if not lod_settings_dir_new.exists():
                lod_settings_dir_new.mkdir()

            for path in terrain_path.iterdir():
                if not path.is_dir():
                    continue

                lod_settings_path_new = (
                        lod_settings_dir_new / f"{path.name}.LOD")

                shutil.copy(lod_settings_path, lod_settings_path_new)

        self.output_received.emit("Copying LOD settings... [DONE]\n")

    def extract_plugin_data(self, plugin: PluginData):
        self.output_received.emit("Clearing extracted plugin data...\n")

        self.remove_paths([self.x_edit_exe_path.parent / "data"])

        self.output_received.emit("Clearing extracted plugin data... [DONE]\n")

        self.output_received.emit("Extract plugin data...\n")

        if not self.plugins:
            self.output_received.emit("No plugins to convert\n")
            self.output_received.emit("Extract plugin data... [DONE]\n")

            return

        x_edit_mode = "-FNV"

        x_edit_plugin = plugin

        command = [
            self.x_edit_exe_path,
            x_edit_mode,
            "-hideForm",
            "-dontBackup",
            "-convert",
            "-script:Extract",
            "-nobuildrefs",
            "-autoload",
            "-autoexit",
            "-IKnowWhatImDoing",
            x_edit_plugin.name,
        ]

        working_directory = self.x_edit_converter_path

        if self.x_edit_data_path.exists():
            shutil.rmtree(self.x_edit_data_path)

        self.x_edit_data_path.mkdir(exist_ok=True)

        self.run_long_task_with_output(command, cwd=working_directory)

        self.output_received.emit("Extract plugin data... [DONE]\n")

    def get_plugin_masters(self, plugin: PluginData) -> list[str]:
        path = self.x_edit_exe_path.parent / "data" / f"{plugin.name}.json"

        with open(path) as file:
            data = json.load(file)

        result = []

        for master in data["masters"]:
            result.append(master["name"])

        return result

    def import_plugin_data(self, plugin: PluginData):
        self.output_received.emit("Import plugin data...\n")

        if not self.plugins:
            self.output_received.emit("No plugins to import\n")

            return

        x_edit_mode = "-FO4"

        command = [
            self.x_edit_exe_path,
            x_edit_mode,
            "-hideForm",
            "-dontBackup",
            "-convert",
            "-script:Import",
            "-nobuildrefs",
            "-autoload",
            "-autoexit",
            "-IKnowWhatImDoing",
            "Fallout4.esm",
        ] + self.get_plugin_masters(plugin) + [plugin.name]

        working_directory = self.x_edit_converter_path

        self.run_long_task_with_output(command, cwd=working_directory)

        self.output_received.emit("Import plugin data... [DONE]\n")

    def convert_plugin_data(self, plugin: PluginData):
        self.output_received.emit("Import plugin data...\n")

        if not self.plugins:
            self.output_received.emit("No plugins to import\n")

            return

        command = [
            self.x_convert_exe_path,
            plugin.name,
        ]

        working_directory = self.x_edit_converter_path

        self.run_long_task_with_output(command, cwd=working_directory)

        self.output_received.emit("Import plugin data... [DONE]\n")

    def move_plugin_to_output(self, plugin: PluginData):
        shutil.move(
            src=str(self.fo4_path / "Data" / plugin.name),
            dst=str(self.output_path / plugin.name),
        )

        self.output_received.emit(f"Moved {plugin.name} to output path\n")

    def replace_data_files(self, plugin: PluginData):
        data_files_dir = Path("src\\data")

        plugin_dir = data_files_dir / plugin.name

        if not plugin_dir.exists():
            return

        for source_item in plugin_dir.iterdir():
            destination_item = self.output_path / source_item.name

            if source_item.is_dir():
                shutil.copytree(
                    source_item, destination_item, dirs_exist_ok=True)
            else:
                shutil.copy(source_item, destination_item)


def copy_file_or_dir(path : Path, path_dst: Path):
    if path.is_file():
        path_dst.parent.mkdir(exist_ok=True, parents=True)

        shutil.copyfile(
            src=path,
            dst=path_dst,
        )
    else:
        path_dst.mkdir(exist_ok=True, parents=True)

        shutil.copytree(
            src=path,
            dst=path_dst,
            dirs_exist_ok=True,
        )
