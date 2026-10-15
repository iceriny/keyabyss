"""Optional acquisition of original public sources. Offline bundled data are default.
Large raw keystroke archive is downloaded only with --aalto-raw. It is restricted
to attributed research/non-commercial use by the source; check its readme.
"""
from pathlib import Path
from html.parser import HTMLParser
from urllib.request import urlopen,Request
from urllib.parse import urljoin
import argparse,hashlib,sys
ROOT=Path(__file__).resolve().parents[1]
LANDING='https://userinterfaces.aalto.fi/136Mkeystrokes/'
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[]
    def handle_starttag(self,tag,attrs):
        if tag=='a':
            href=dict(attrs).get('href')
            if href:self.links.append(href)
def get(url,dest):
    dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_suffix(dest.suffix+'.part')
    try:
        with urlopen(Request(url,headers={'User-Agent':'TypingDynamicsResearch/1.0'}),timeout=60) as src,open(tmp,'wb') as out:
            while True:
                block=src.read(1024*1024)
                if not block:break
                out.write(block)
        tmp.replace(dest)
    except Exception:
        tmp.unlink(missing_ok=True);raise
    print(dest,hashlib.sha256(dest.read_bytes()).hexdigest())
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--aalto-raw',action='store_true');ap.add_argument('--paper',action='store_true');ap.add_argument('--refresh-lexicon',action='store_true');a=ap.parse_args()
    if not any([a.aalto_raw,a.paper,a.refresh_lexicon]):
        p=ROOT/'data/raw/en-spelling.txt'
        print('Bundled offline lexicon:',p,'exists=',p.exists());print('No network download requested.');return
    try:
        if a.refresh_lexicon:
            # Save separately: never silently overwrite the versioned research input.
            get('https://raw.githubusercontent.com/sloria/TextBlob/dev/src/textblob/en/en-spelling.txt',ROOT/'data/raw/en-spelling-upstream.txt')
        if a.aalto_raw or a.paper:
            text=urlopen(Request(LANDING,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read().decode();parser=Links();parser.feed(text)
            if a.paper:
                urls=[urljoin(LANDING,u) for u in parser.links if '.pdf' in u.lower()]
                if not urls:raise RuntimeError('No PDF link found on the official page')
                get(urls[0],ROOT/'data/external/chi18_typing.pdf')
            if a.aalto_raw:
                urls=[urljoin(LANDING,u) for u in parser.links if '.zip' in u.lower() and 'code' not in u.lower()]
                if not urls:raise RuntimeError('No raw-data ZIP link found; review the official landing page')
                get(urls[0],ROOT/'data/external/aalto_keystrokes.zip')
    except Exception as exc:
        print(f'Download failed: {exc}. Bundled scientific inputs were not modified.',file=sys.stderr);return 1
    return 0
if __name__=='__main__':raise SystemExit(main())
