"""Extract literal installation blocks from the pinned LFS book."""
from html.parser import HTMLParser
import re
class Extractor(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True); self.blocks=[]; self.current=None
    def handle_starttag(self, tag, attrs):
        if tag=='pre' and 'userinput' in dict(attrs).get('class','').split(): self.current=[]
    def handle_data(self, data):
        if self.current is not None: self.current.append(data)
    def handle_endtag(self,tag):
        if tag=='pre' and self.current is not None:
            self.blocks.append(''.join(self.current)); self.current=None

def book_links(html):
    return list(dict.fromkeys(re.findall(r'href\s*=\s*"(chapter0[5-8]/[^" ]+\.html)"', html)))


def commands(html):
    parser=Extractor(); parser.feed(html); return parser.blocks

def initial_build_command(command):
    if re.search(r'\b(?:make|ninja|meson)\s+[^\n]*(?:\bcheck\b|\btest\b|\btests\b|test_harness)', command):
        return False
    return not bool(re.search(r'(^|\n)(?:make\s+[^\n]*(?:\bcheck\b|\btest\b|tests)|ninja\s+test|meson\s+test|ctest|su\s+tester|chown\s+-R\s+tester|expect\s+-c|python3?\s+-m\s+test|make\s+[^\n]*installcheck|test_summary)',command))

if __name__=='__main__':
    import pathlib, urllib.request, concurrent.futures, json
    base='https://www.linuxfromscratch.org/lfs/view/13.0-systemd/'
    output=pathlib.Path('/workspace/build/book'); output.mkdir(exist_ok=True)
    index=pathlib.Path('/workspace/research/lfs-index.html').read_text()
    links=book_links(index)
    def fetch(link):
        dest=output/(link.replace('/','-'))
        if not dest.exists(): dest.write_bytes(urllib.request.urlopen(base+link).read())
        return link, commands(dest.read_text())
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        pages=dict(pool.map(fetch,links))
    records=[]
    for link in links:
        blocks=pages[link]
        if not blocks: continue
        records.append({'page':link,'commands':blocks})
    (output/'commands.json').write_text(json.dumps(records,indent=2))
    print('Extracted',len(records),'pages')
