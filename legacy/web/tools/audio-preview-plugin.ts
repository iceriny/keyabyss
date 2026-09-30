import type { Plugin } from 'vite';
import fs from 'node:fs/promises';
import path from 'node:path';
import { validateRegions, previewAudio } from './audio.ts';
/** Dev-only editor endpoint; never part of the release. */
export function audioPreview(): Plugin {
  return { name:'audio-preview', apply:'serve', configureServer(server) {
    const previews = new Map<string, Promise<Buffer>>();
    server.middlewares.use('/__audio/preview', async (req,res) => {
      try {
        const file = new URL(req.url!, 'http://localhost').searchParams.get('file');
        if (!file) throw Error('Missing file');
        let pending = previews.get(file);
        if (!pending) {
          if (previews.size >= 3) previews.delete(previews.keys().next().value!);
          pending = previewAudio(file).catch(e=>{previews.delete(file);throw e;}); previews.set(file,pending);
        }
        const data = await pending;
        res.setHeader('Content-Type','audio/flac');res.setHeader('Accept-Ranges','bytes');
        const range = req.headers.range?.match(/^bytes=(\d+)-(\d*)$/);
        const start = range ? Number(range[1]) : 0, end = range && range[2] ? Math.min(data.length-1,Number(range[2])) : data.length-1;
        if (start>end || start>=data.length) {res.statusCode=416;res.setHeader('Content-Range',`bytes */${data.length}`);res.end();return;}
        if(range){res.statusCode=206;res.setHeader('Content-Range',`bytes ${start}-${end}/${data.length}`);}
        res.setHeader('Content-Length',end-start+1);res.end(req.method==='HEAD'?undefined:data.subarray(start,end+1));
      }catch(e){res.statusCode=400;res.end(String(e));}
    });
    server.middlewares.use('/__audio/overrides', async (req,res) => {
      if(req.method!=='POST') {res.statusCode=405;res.end();return;}
      if(req.headers.origin && new URL(req.headers.origin).host!==req.headers.host) {res.statusCode=403;res.end();return;}
      try {
        let body='';for await(const chunk of req){body+=chunk;if(body.length>32768)throw Error('Too many regions');}
        const {file,regions}=JSON.parse(body);
        const catalog=JSON.parse(await fs.readFile(path.join(server.config.root,'data/audio-catalog.json'),'utf8'));
        const source=catalog.sources.find((s:{file:string})=>s.file===file);
        if(!source||!Array.isArray(regions))throw Error('Unknown source or invalid regions');
        validateRegions(regions,source.duration);
        const target=path.join(server.config.root,'data/audio-overrides.json');
        const edits=JSON.parse(await fs.readFile(target,'utf8'));edits[file]=regions.map((r:{start:number;end:number})=>({start:r.start,end:r.end}));
        await fs.writeFile(target,JSON.stringify(edits,null,2)+'\n');res.setHeader('Content-Type','application/json');res.end('{"saved":true}');
      }catch(e){res.statusCode=400;res.end(String(e));}
    });
  }};
}
