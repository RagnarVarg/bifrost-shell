import tempfile
import unittest
from pathlib import Path
from wallpapers import discover


class DiscoveryTests(unittest.TestCase):
    def test_locations_names_dedup_and_refresh(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            primary = home / 'Pictures/Wallpapers'
            primary.mkdir(parents=True)
            configured = home / 'Other'
            configured.mkdir()
            current = home / 'Current/active.png'
            current.parent.mkdir()
            current.touch()
            special = primary / 'space # % ü\nname.PNG'
            special.touch()
            nested = primary / 'nested'
            nested.mkdir()
            (nested / 'photo.webp').touch()
            (primary / 'ignore.txt').touch()
            (configured / 'alias.png').symlink_to(special)
            extra = configured / 'extra.jpg'
            extra.touch()
            result = discover(str(configured), str(current), home)
            self.assertEqual(result['errors'], [])
            self.assertEqual(result['images'], [str(special), str(nested / 'photo.webp'), str(extra), str(current)])
            special.unlink()
            self.assertNotIn(str(special), discover(str(configured), str(current), home)['images'])
            (primary / 'added.bmp').touch()
            self.assertIn(str(primary / 'added.bmp'), discover(home=home)['images'])

    def test_missing_and_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(discover(home=tmp), {'images': [], 'errors': []})


if __name__ == '__main__':
    unittest.main()
