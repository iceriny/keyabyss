"""Read the vendor workbook without Excel or optional Python packages (read only)."""
import json
import sys
from zipfile import ZipFile
from xml.etree import ElementTree as ET

ns = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
with ZipFile(sys.argv[1]) as archive:
    strings = [ ''.join(e.itertext()) for e in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('m:si', ns)] if 'xl/sharedStrings.xml' in archive.namelist() else []
    rows = []
    for row in ET.fromstring(archive.read('xl/worksheets/sheet1.xml')).findall('.//m:sheetData/m:row', ns):
        values = {}
        for cell in row.findall('m:c', ns):
            col = ''.join(c for c in cell.attrib['r'] if c.isalpha())
            value = cell.find('m:v', ns)
            text = value.text if value is not None else ''
            if cell.get('t') == 's': text = strings[int(text)]
            if cell.get('t') == 'inlineStr': text = ''.join(cell.find('m:is', ns).itertext())
            values[col] = text
        rows.append(values)
    headers = rows[0]
    result = {r['A']: {headers[k]: v for k,v in r.items() if k in headers} for r in rows[1:] if r.get('A', '').lower().endswith('.wav')}
sys.stdout.reconfigure(encoding='utf-8')
print(json.dumps(result, ensure_ascii=False))
