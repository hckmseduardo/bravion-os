import importlib.util
from pathlib import Path
import unittest
class BookExtraction(unittest.TestCase):
    def test_extracts_commands_not_screen_output(self):
        path=Path(__file__).parents[1]/'build'/'book.py'
        self.assertTrue(path.exists(), 'book extractor must exist')
        spec=importlib.util.spec_from_file_location('book',path)
        module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        html='<pre class="screen">do not run</pre><pre class="userinput"><kbd class="command">make &amp;&amp; make install</kbd></pre>'
        self.assertEqual(module.commands(html), ['make && make install'])
    def test_package_links_can_wrap_across_lines(self):
        path=Path(__file__).parents[1]/'build'/'book.py'
        spec=importlib.util.spec_from_file_location('book',path)
        module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        self.assertEqual(module.book_links('<a href=\n "chapter08/libpipeline.html">Library</a>'), ['chapter08/libpipeline.html'])
    def test_does_not_execute_test_commands(self):
        path=Path(__file__).parents[1]/'build'/'book.py'
        self.assertTrue(path.exists(), 'book extractor must exist')
        spec=importlib.util.spec_from_file_location('book',path)
        module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        self.assertFalse(module.initial_build_command('make -k check'))
        self.assertFalse(module.initial_build_command('LC_ALL=C.UTF-8 make test'))
        self.assertTrue(module.initial_build_command('make install'))
        self.assertTrue(module.initial_build_command('mkdir build\npushd build\nmake\npopd'))
if __name__=='__main__': unittest.main()
