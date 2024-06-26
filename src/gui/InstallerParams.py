from dataclasses import dataclass
from typing import TextIO


@dataclass
class InstallerParams:
    skip_bsas: bool = False
    skip_meshes: bool = False
    skip_optimize: bool = False
    skip_data: bool = False
    skip_plugin_convert: bool = False
    skip_plugin_move: bool = False
    ignore_existing_files: bool = False
    debug: bool = False
    skip_lod_settings: bool = False
    log_file: TextIO = None
    all_objects_cast_shadows: bool = True
    skip_ba2_creation: bool = False
