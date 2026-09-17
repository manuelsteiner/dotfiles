from pathlib import Path
import re
import shutil

from beets.plugins import BeetsPlugin


DISC_DIR_RE = re.compile(r"^Disc \d+$")


class AlbumRootArtPlugin(BeetsPlugin):
    def __init__(self):
        super().__init__()
        self.register_listener("art_set", self.art_set)

    def art_set(self, album):
        if not album.artpath:
            return

        artpath = Path(album.artpath.decode() if isinstance(album.artpath, bytes) else album.artpath)
        artdir = artpath.parent

        # Single-disc album, or art already lives at album level.
        if not DISC_DIR_RE.fullmatch(artdir.name):
            return

        albumdir = artdir.parent
        target = albumdir / artpath.name

        if target == artpath:
            return

        # Replace an older album-level cover if necessary.
        if target.exists():
            target.unlink()

        shutil.move(str(artpath), str(target))

        # Keep beets' database in sync with the file we just moved.
        album.artpath = str(target).encode()
        album.store(fields=["artpath"], inherit=False)

        self._log.info(
            "moved multi-disc artwork to album root: {0}",
            target,
        )
