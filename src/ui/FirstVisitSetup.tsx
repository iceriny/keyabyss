import { useEffect, useRef, useState } from "react";
import type { Settings } from "../contracts/game.ts";
import { SettingsPanel } from "./Panels";
import { Button } from "./components";

/** A bounded preview workload; RAF sampling stops when hidden or unmounted. */
export function FirstVisitSetup({ settings, onChange, onFull, onDone }: {
  settings: Settings; onChange: (value: Settings) => void; onFull: () => void; onDone: () => void;
}) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const [fps, setFps] = useState<number | null>(null);
  useEffect(() => {
    const c = canvas.current!.getContext("2d")!;
    let raf = 0, last = 0, frames = 0, start = 0;
    const reduced = settings.reduceMotion || matchMedia("(prefers-reduced-motion: reduce)").matches;
    setFps(null);
    const draw = (now: number) => {
      raf = requestAnimationFrame(draw);
      if (document.hidden) { start = 0; frames = 0; return; }
      if (!start) { start = now; frames = -1; }
      frames++;
      if (now - start >= 500) { setFps(Math.round(frames * 1000 / (now - start))); frames = 0; start = now; }
      if (reduced && last) return;
      last = now;
      const t = reduced ? 0 : now / 1000, w = c.canvas.width, h = c.canvas.height;
      c.clearRect(0, 0, w, h);
      c.save(); c.translate(w / 2, h / 2); c.globalCompositeOperation = "lighter";
      const glow = c.createRadialGradient(0,0,10,0,0,240);
      glow.addColorStop(0,"#a49ce536"); glow.addColorStop(.5,"#7060c418"); glow.addColorStop(1,"#7060c400");
      c.fillStyle = glow; c.fillRect(-w/2,-h/2,w,h);
      const rings = settings.fx > .9 ? 7 : settings.fx > .5 ? 4 : 2;
      for (let r = 0; r < rings; r++) {
        c.save(); c.rotate(t * (r % 2 ? -.09 : .07) + r);
        c.strokeStyle = r % 2 ? "#ac9cef80" : "#e1c18570"; c.lineWidth = 1;
        const radius = 52 + r * 23;
        c.beginPath(); c.arc(0,0,radius,0,Math.PI*2); c.stroke();
        for(let n=0;n<12;n++) { c.rotate(Math.PI/6); c.strokeRect(radius-5,-3,10,6); }
        c.beginPath(); for(let n=0;n<=6;n++){const a=n*Math.PI*2/3; c.lineTo(Math.cos(a)*radius,Math.sin(a)*radius);} c.stroke();
        c.restore();
      }
      if (!reduced) for(let i=0;i<Math.round(320*settings.fx);i++) {
        const a=i*2.399+t*(.08+(i%7)*.02), radius=35+((i*37+t*24)%240);
        const x=Math.cos(a)*radius, y=Math.sin(a)*radius*.8;
        c.globalAlpha=(1-radius/290)*(.4+.6*Math.sin(i+t)**2);
        c.fillStyle=i%3 ? "#b8a5ef" : "#ffe0a6";
        c.shadowColor=c.fillStyle; c.shadowBlur=settings.fx>.5 ? 10 : 0;
        c.beginPath();c.arc(x,y,1+(i%3)*.5,0,Math.PI*2);c.fill();
      }
      c.shadowBlur=0; c.globalAlpha=1;
      if(!reduced) for(let i=0;i<3;i++) { const phase=(t*.3+i/3)%1; c.strokeStyle=`rgba(210,185,255,${(1-phase)*.5})`; c.lineWidth=2; c.beginPath();c.ellipse(0,0,20+phase*260,10+phase*130,0,0,Math.PI*2);c.stroke(); }
      c.restore();
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [settings.fx, settings.reduceMotion]);
  return <div className="first-visit-setup">
    <section className="calibration-scene">
      <canvas ref={canvas} width={620} height={520} aria-label="法阵、粒子与冲击波特效预览" />
      <div className="calibration-reading"><strong data-plain-text>{fps ?? "—"}</strong><span>FPS · 实时预览帧率</span></div>
      <p>观察法阵与粒子是否流畅，再选择适合的特效等级。</p>
      <small>这是预览场景帧率，实际战斗会随敌人和特效数量变化。设置随时可调整。</small>
    </section>
    <section className="calibration-settings"><SettingsPanel settings={settings} onChange={onChange} onFull={onFull} showAbout={false} />
      <Button word="ready" variant="primary" onClick={onDone}>保存并进入书库 →</Button>
    </section>
  </div>;
}
