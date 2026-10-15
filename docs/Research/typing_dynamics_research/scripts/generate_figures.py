"""Generate independent, data-backed matplotlib figures. No subplots or seaborn."""
from pathlib import Path
import sys,json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Rectangle
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import GROUPS,GROUP_CN
from typing_sim.keyboard import KEYS
OUT=ROOT/'figures';OUT.mkdir(exist_ok=True)
A=ROOT/'results/analysis';T=ROOT/'results/traces'
FOUND={f.name for f in font_manager.fontManager.ttflist}
for name in ['Noto Sans CJK JP','Noto Sans CJK SC','Microsoft YaHei','SimHei','Arial Unicode MS']:
    if name in FOUND:plt.rcParams['font.family']=[name];break
plt.rcParams['axes.unicode_minus']=False
plt.rcParams['font.size']=10
plt.rcParams['figure.dpi']=120
MANIFEST=[]

def read(folder,name):return pd.read_csv(ROOT/'results'/folder/name)
def data(name):return pd.read_csv(A/(name+'.csv'))
def fig(title,xlabel='',ylabel='',wide=False):
    f=plt.figure(figsize=(9.6,5.6) if wide else (8.6,5.3));ax=f.add_subplot(111)
    ax.set_title(title,pad=14,fontweight='bold');ax.set_xlabel(xlabel);ax.set_ylabel(ylabel)
    ax.spines[['top','right']].set_visible(False);ax.grid(axis='y',alpha=.18)
    return f,ax

def save(f,num,name,caption,sources):
    f.tight_layout(pad=1.5);stem=f'{num:02d}_{name}'
    for ext in ['png','svg','pdf']:f.savefig(OUT/(stem+'.'+ext),dpi=180,bbox_inches='tight')
    plt.close(f);MANIFEST.append(dict(number=num,stem=stem,caption=caption,sources=sources,script='scripts/generate_figures.py'))

def errline(ax,d,xcol='level',label=None):
    d=d.copy();d[xcol]=pd.to_numeric(d[xcol]);d=d.sort_values(xcol)
    ax.errorbar(d[xcol],d['mean'],yerr=[d['mean']-d.ci_low,d.ci_high-d['mean']],fmt='o-',capsize=3,label=label)

def main():
    b=data('baseline_statistics');no=data('no_preview_statistics')
    raw=read('baseline','baseline_sessions.csv');sens=data('sensitivity_statistics')
    select=lambda frame,metric:frame[frame.metric==metric]
    f,ax=fig('四种任务下的标准打字速度','能力情景','标准 WPM（5字符/词）')
    xx=np.arange(5);width=.19
    for j,task in enumerate('ABCD'):
        d=b[(b.metric=='wpm5')&(b.task==task)].set_index('group').loc[list(GROUPS)]
        ax.bar(xx+(j-1.5)*width,d['mean'],width,label=task,yerr=[d['mean']-d.ci_low,d.ci_high-d['mean']],capsize=2)
    ax.set_xticks(xx,[GROUP_CN[g] for g in GROUPS]);ax.legend(ncol=4)
    save(f,1,'baseline_wpm','均值及以个体为单位重抽样的95%蒙特卡洛区间；A连贯固定，B随机词固定，C随机位置静止，D随机位置缓慢移动。','results/analysis/baseline_statistics.csv')
    f,ax=fig('高水平高手：四种条件的个体分布','任务','两次测试平均 WPM')
    arrays=[raw[(raw.group=='expert')&(raw.task==t)].groupby('person_id').wpm5.mean().to_numpy() for t in 'ABCD']
    ax.violinplot(arrays,showmeans=True,showmedians=True,showextrema=True);ax.set_xticks(range(1,5),list('ABCD'))
    save(f,2,'wpm_distributions','小提琴图呈现合成个体的两次会话均值分布，不是现实人群采样分布。','results/baseline/baseline_sessions.csv')
    f,ax=fig('从连贯固定文本到动态随机单词','任务','标准 WPM')
    for g in GROUPS:
        d=b[(b.metric=='wpm5')&(b.group==g)].set_index('task').loc[list('ABCD')]
        ax.plot(list('ABCD'),d['mean'],'o-',label=GROUP_CN[g])
    ax.legend(ncol=2);save(f,3,'task_transition','A到B同时改变上下文、词频和词长分布；不能解释为孤立的语义随机化效应。','results/analysis/baseline_statistics.csv')
    f,ax=fig('动态任务：字母与含空格字符吞吐量','能力情景','正确单位数/分钟')
    for j,m in enumerate(['lpm','cpm']):
        d=b[(b.metric==m)&(b.task=='D')].set_index('group').loc[list(GROUPS)]
        ax.bar(xx+(j-.5)*.34,d['mean'],.34,label='正确字母 LPM' if m=='lpm' else '含空格字符 CPM')
    ax.set_xticks(xx,[GROUP_CN[g] for g in GROUPS]);ax.legend();save(f,4,'letter_character_rates','CPM=LPM+正确完整词数/分钟；每个正确提交的空格计1字符。','results/analysis/baseline_statistics.csv')
    f,ax=fig('速度与输入错误事件','标准 WPM','每100个目标字符的错误事件')
    for g in GROUPS:
        d=raw[(raw.group==g)&(raw.task=='D')].groupby('person_id')[['wpm5','corrected_errors_per_char']].mean()
        ax.scatter(d.wpm5,100*d.corrected_errors_per_char,s=15,alpha=.45,label=GROUP_CN[g])
    ax.legend(ncol=2);save(f,5,'speed_error','这里计数生成的错误事件，而非每次编辑距离；默认最终修复，因此不能把它称作未纠正错误率。','results/baseline/baseline_sessions.csv')
    curves=pd.read_csv(T/'trajectory_families.csv.gz')
    f,ax=fig('六类二维运动轨迹','横向视角（度）','纵向视角（度）')
    for family,d in curves.groupby('family'):ax.plot(d.x,d.y,label=family,linewidth=1.4)
    ax.set_aspect('equal',adjustable='datalim');ax.legend(ncol=2)
    save(f,6,'trajectories','6秒轨迹；标称3度/秒。周期轨迹的实际均方速度与其他家族并未强制匹配，边界反弹是理想反射。','results/traces/trajectory_families.csv.gz')
    eyes=pd.read_csv(T/'session_eyes.csv.gz');keys=pd.read_csv(T/'session_keys.csv');words=pd.read_csv(T/'session_words.csv')
    sample=eyes[eyes.word_index==0]
    f,ax=fig('一次动态单词识别中的目标与注视点','横向视角（度）','纵向视角（度）')
    ax.plot(sample.target_x,sample.target_y,label='目标真实位置');ax.plot(sample.gaze_x,sample.gaze_y,label='注视位置')
    ax.scatter([sample.target_x.iloc[0]],[sample.target_y.iloc[0]],marker='x',label='目标起点')
    ax.set_aspect('equal',adjustable='datalim');ax.legend()
    save(f,7,'target_gaze','固定诊断个体与种子的一次原始连续轨迹；没有为图形效果筛选受试者。','results/traces/session_eyes.csv.gz')
    f,ax=fig('眼动状态随时间切换','会话时间（秒）','眼动状态')
    for wi,d in eyes.groupby('word_index'):ax.step(d.time,d.state,where='post',linewidth=1.1)
    ax.set_yticks(range(6),['注视','扫视准备','扫视','平滑追踪','重新捕获','看键盘']);ax.set_xlim(0,10)
    save(f,8,'eye_states','各词的眼动服务区间；空白时间表示模型允许依据已编码的内容继续输入，并非缺测的人类眼动。','results/traces/session_eyes.csv.gz')
    p=pd.read_csv(T/'pursuit_speed.csv');d=p.groupby('speed_deg_s').rms_deg.agg(['mean','sem']).reset_index()
    f,ax=fig('运动速度与追踪位置误差','标称运动速度（度/秒）','均方根误差（度）')
    ax.errorbar(d.speed_deg_s,d['mean'],yerr=1.96*d['sem'],fmt='o-',capsize=4)
    save(f,9,'pursuit_error','排除首1秒和扫视，只统计可见目标的平滑追踪状态；0速度点改用注视状态。不是获取阶段的全程偏心度。','results/traces/pursuit_speed.csv')
    oc=pd.read_csv(T/'occlusion_reacquisition.csv')
    f,ax=fig('遮挡后恢复有效注视的时间','外部遮挡平均持续时间（秒）','重捕获延迟（秒）')
    for enabled,d in oc.groupby('prediction'):
        d=d.groupby('mean_occlusion_s').reacquisition_s.agg(['mean','sem']).reset_index()
        ax.errorbar(d.mean_occlusion_s,d['mean'],yerr=1.96*d['sem'],fmt='o-',capsize=3,label='启用预测' if enabled else '关闭预测')
    ax.legend();save(f,10,'occlusion_reacquisition','目标重新可见后首次误差小于0.8度且不在扫视中的时间。图示成功恢复事件均值；未及时恢复的删失事件比例另见CSV，不能把该均值当无条件期望。','results/traces/occlusion_reacquisition.csv')
    crowd=pd.read_csv(T/'crowding_brief_exposure.csv')
    f,ax=fig('固定注视、短暂呈现下的空间拥挤','词框边缘间距（度）','0.65秒内正确识别比例')
    for enabled,d in crowd.groupby('crowding_enabled'):
        d=d.groupby('edge_gap_deg').correct.agg(['mean','count']).reset_index();n=d['count'];ph=d['mean'];z=1.96
        center=(ph+z*z/(2*n))/(1+z*z/n);half=z*np.sqrt(ph*(1-ph)/n+z*z/(4*n*n))/(1+z*z/n)
        ax.errorbar(d.edge_gap_deg,ph,yerr=[np.maximum(0,ph-(center-half)),np.maximum(0,(center+half)-ph)],fmt='o-',capsize=3,label='空间拥挤开启' if enabled else '空间拥挤关闭')
    ax.set_ylim(-.03,1.03);ax.legend();save(f,11,'crowding_recognition','固定注视的受控微实验：目标偏心度1.5度，两个侧方词，不发生字框遮挡；误差条为二项Wilson区间。','results/traces/crowding_brief_exposure.csv')
    f,ax=fig('目标分布范围与初次视觉定位','目标中心横向分布范围（度）','平均定位时间（秒）')
    for g in ['ordinary','expert','elite']:
        d=sens[(sens.factor=='field_width')&(sens.group==g)&(sens.metric=='mean_acquisition_s')]
        errline(ax,d,label=GROUP_CN[g])
    ax.legend();save(f,12,'search_field','定位时间由眼动状态、目标位置及注视落点产生，并非固定搜索延迟。','results/analysis/sensitivity_statistics.csv')
    fq=pd.read_csv(T/'lexical_frequency.csv')
    f,ax=fig('固定词长下的频率与词汇识别','语料对数频率 log10(每十亿词计数)','识别完成时间（秒）')
    ax.scatter(fq.corpus_logfreq,fq.recognition_s,s=12,alpha=.30)
    d=fq.groupby('frequency_bin').agg(x=('corpus_logfreq','mean'),y=('recognition_s','mean'));ax.plot(d.x,d.y,'o-')
    save(f,13,'frequency_recognition','真实词库中长度5的词，中央注视、无干扰；频率作用函数是先验，点云是实际积分输出，不是ELP观测。','results/traces/lexical_frequency.csv')
    wl=pd.read_csv(T/'word_length_trials.csv.gz');wl['latency']=wl.submit_time-wl.reveal_time
    f,ax=fig('词长与单词的完成延迟','目标词长（字母）','从出现到正确提交（秒）')
    d=wl.groupby(['person_id','length']).latency.mean().reset_index().groupby('length').latency.agg(['mean','sem']).reset_index()
    ax.errorbar(d.length,d['mean'],yerr=1.96*d['sem'],fmt='o-',capsize=4)
    save(f,14,'length_completion','高水平高手；完成延迟包含等待输出顺序的时间，不能把它的倒数直接当流水线吞吐率。各词长库的词频尚有残余差异。','results/traces/word_length_trials.csv.gz')
    sr=read('sensitivity','sensitivity_sessions.csv');sr=sr[sr.factor=='similarity']
    f,ax=fig('相似干扰词与识别错误','实际平均词汇相似度','已提交词的错误识别比例')
    for g,d in sr.groupby('group'):
        q=d.groupby('level').agg(x=('mean_actual_similarity','mean'),y=('recognition_error_rate','mean'));ax.plot(q.x,q.y,'o-',label=GROUP_CN[g])
    ax.legend();save(f,15,'similarity_errors','横轴使用采样后实际相似度而不是请求值。本参数区间下竞争错误很少；接近零不能证明不存在词汇干扰。','results/sensitivity/sensitivity_sessions.csv')
    k=keys[keys['key'].fillna('')!=''];one=k[k.word_index==0]
    f,ax=fig('QWERTY键盘上的一次真实仿真按键序列','键位横坐标（键距）','键位纵坐标（键距）',True)
    for letter,key in KEYS.items():
        if letter not in 'abcdefghijklmnopqrstuvwxyz':continue
        ax.add_patch(Rectangle((key.x-.43,key.y-.40),.86,.8,fill=False,linewidth=.5))
        ax.text(key.x,key.y,letter,ha='center',va='center',fontsize=9)
    ax.plot(one.x,one.y,'o-',linewidth=1,markersize=3,label='第一词按键顺序');ax.invert_yaxis();ax.set_aspect('equal');ax.legend()
    save(f,16,'keyboard_path','该连线表示按键发生顺序，不是声称同一根手指在所有键之间移动。按各自手指保存位置与释放时间。','results/traces/session_keys.csv')
    f,ax=fig('十根手指的准备、定位与击键','会话时间（秒）','手指编号',True)
    sel=k[k.time<3.]
    for _,r in sel.iterrows():
        ax.broken_barh([(r.move_start,r.arrival-r.move_start)],(r.finger-.28,.56),alpha=.55)
        ax.plot([r.time,r.release],[r.finger,r.finger],linewidth=3)
    ax.set_yticks(range(10),['左小','左无名','左中','左食','左拇','右拇','右食','右中','右无名','右小']);ax.set_xlim(0,3)
    save(f,17,'finger_gantt','浅色条为手指定位，粗线为键按下到释放；不同手指可以重叠，按键输出顺序保持不变。','results/traces/session_keys.csv')
    k=k.sort_values('time').copy();k['iki_ms']=k.time.diff()*1000
    cats=['alternation','left','right','same_finger','repeat'];arrays=[];labels=[]
    for cat in cats:
        x=k[k.transition==cat].iki_ms.dropna().to_numpy()
        if len(x)>1:arrays.append(x);labels.append(cat)
    f,ax=fig('键间转换的实际间隔分布','转换类型','按下到下一次按下（毫秒）')
    ax.boxplot(arrays,tick_labels=labels,showfliers=True);ax.tick_params(axis='x',rotation=12)
    save(f,18,'transition_intervals','短诊断会话中的实际按键分布，含词边界暂停，样本量小；论文类别均值的校准结果另见图25。','results/traces/session_keys.csv')
    f,ax=fig('视觉、中央规划与运动的时间重叠','会话时间（秒）','资源层',True)
    for _,r in words.iterrows():
        if r.search_start<3:ax.broken_barh([(r.search_start,r.recognized_time-r.search_start)],(2.7,.5),alpha=.65)
    for _,r in keys[keys.time<3].iterrows():
        if pd.notna(r.get('plan_start')):ax.broken_barh([(r.plan_start,r.plan_end-r.plan_start)],(1.7,.5),alpha=.6)
        if pd.notna(r.get('move_start')):ax.broken_barh([(r.move_start,r.release-r.move_start)],(.7,.5),alpha=.35)
    ax.set_yticks([.95,1.95,2.95],['手指执行与保持','中央规划/词间衔接','视觉定位与识别']);ax.set_xlim(0,3)
    save(f,19,'resource_timeline','实际事件时刻。重叠占用不能简单相加为总用时；视觉与手指运动通过资源份额和提交顺序耦合。','results/traces/session_keys.csv;results/traces/session_words.csv')
    rank=data('sensitivity_rank');d=rank[rank.group=='expert'].copy();d['absolute']=d.spearman_rho.abs();d=d.sort_values('absolute')
    f,ax=fig('参数不确定性：高水平组的敏感度排序','Spearman秩相关','参数',True)
    ax.barh(d.parameter,d.spearman_rho);ax.axvline(0,linewidth=.8);ax.set_xlim(-1,1)
    save(f,20,'parameter_sensitivity','128组拉丁超立方先验设计的单调关联；不是Sobol方差贡献，参数间交互不会完整体现在此图。','results/analysis/sensitivity_rank.csv')
    inter=data('interaction_statistics');q=inter[inter.metric=='wpm5'].pivot(index='distractor_level',columns='speed_level',values='mean')
    f,ax=fig('速度与干扰词数量的交互','标称速度（度/秒）','干扰词数量')
    image=ax.imshow(q,aspect='auto',origin='lower');ax.set_xticks(range(len(q.columns)),q.columns);ax.set_yticks(range(len(q.index)),q.index)
    f.colorbar(image,ax=ax,label='标准 WPM')
    # Numeric cell values are retained in the CSV; no low-contrast overlaid labels.
    save(f,21,'interaction_heatmap','高水平高手；20个配对合成个体/单元，35秒，无外部遮挡。','results/analysis/interaction_statistics.csv')
    ab=data('ablation_contrasts');d=ab[ab.group=='expert'].sort_values('relative_percent')
    f,ax=fig('机制消融：对动态挑战任务吞吐率的影响','相对完整模型变化（%）','消融项',True)
    ax.barh(d['case'],d.relative_percent,xerr=[d.relative_percent-d.relative_ci_low,d.relative_ci_high-d.relative_percent],capsize=2);ax.axvline(0,linewidth=.8)
    save(f,22,'ablation','高水平组配对差异与个体Bootstrap区间。移除记忆还会移除预视，因此不是纯工作记忆效应；关闭纠错保留严格净字符计分。','results/analysis/ablation_contrasts.csv')
    f,ax=fig('模拟人数与动态任务均值的稳定性','累计合成个体数','累计平均标准 WPM')
    for g in GROUPS:
        x=raw[(raw.group==g)&(raw.task=='D')].groupby('person_id').wpm5.mean().to_numpy();n=np.arange(1,len(x)+1)
        ax.plot(n,np.cumsum(x)/n,label=GROUP_CN[g])
    ax.set_xlim(left=5);ax.legend(ncol=2);save(f,23,'population_convergence','按固定个体ID顺序的累计均值；样本数由独立先导方差决定，图线平稳不代表模型结构误差消失。','results/baseline/baseline_sessions.csv')
    u=data('uncertainty_draw_means');f,ax=fig('参数先验传播后的动态任务速度','标准 WPM','先验设计中的频数')
    for g,d in u.groupby('group'):ax.hist(d.wpm5,bins=16,histtype='step',linewidth=1.5,label=GROUP_CN[g])
    ax.legend();save(f,24,'parameter_uncertainty','每个参数设计点平均4个固定能力个体的输出；不是现实个体预测分布，未覆盖的结构不确定性也不在其中。','results/analysis/uncertainty_draw_means.csv')
    cal=read('validation','motor_calibration.csv');f,ax=fig('论文汇总击键间隔与数值校准','论文类别均值（毫秒）','校准模型均值（毫秒）')
    for g,d in cal.groupby('group'):ax.scatter(d.observed_ms,d.model_ms,label=GROUP_CN[g],s=45)
    lo=cal.observed_ms.min()*.8;hi=cal.observed_ms.max()*1.1;ax.plot([lo,hi],[lo,hi],'--',linewidth=1);ax.legend()
    save(f,25,'empirical_calibration','3个锚点档 × 4个类别；每档4个自由参数匹配4个均值。吻合是数值校准，不是独立的人类行为验证。','data/raw/typing_summary_observations.csv;results/validation/motor_calibration.csv')
    ml=data('motor_limit_statistics');curves=data('surrogate_curves');f,ax=fig('手指继续加速后的吞吐率饱和','运动时间尺度乘子（越小越快）','标准 WPM')
    for g in GROUPS:
        d=ml[(ml.group==g)&(ml.metric=='wpm5')];ax.plot(d.motor_scale,d['mean'],'o-',label=GROUP_CN[g])
    ax.legend(ncol=2);save(f,26,'motor_limit','点及连接线来自完整模型仿真；对应低阶拟合函数及留出误差见报告参数表。渐近值只属于给定任务/残差假设，不是人类生理极限。','results/analysis/motor_limit_statistics.csv;results/analysis/surrogate_curves.csv')
    f,ax=fig('预视开放的时间：同一批个体配对比较','当前词已输入比例（1=提交后）','动态任务标准 WPM')
    for g in ['ordinary','expert','elite']:errline(ax,sens[(sens.factor=='preview_fraction')&(sens.metric=='wpm5')&(sens.group==g)],label=GROUP_CN[g])
    ax.legend();save(f,27,'preview_policy','各点使用相同合成个体ID和随机词流，直接检验预视时机，不与另一批无预视主实验个体混作配对。','results/analysis/sensitivity_statistics.csv')
    dt=data('time_step_statistics');f,ax=fig('连续积分步长的分布级检查','步长（毫秒）','标准 WPM')
    for g in ['ordinary','expert','elite']:
        d=dt[(dt.group==g)&(dt.metric=='wpm5')].copy();d['milliseconds']=d.dt_level*1000;errline(ax,d,'milliseconds',GROUP_CN[g])
    ax.legend();save(f,28,'time_step','同个体/词流但不同步长的布朗增量并非同路径耦合；这是弱收敛诊断，不是强收敛阶的测量。','results/analysis/time_step_statistics.csv')
    fat=data('fatigue_statistics');f,ax=fig('测试时长、热身与疲劳','测试时长（分钟）','整场平均标准 WPM')
    for g in ['ordinary','expert']:
        for on in [False,True]:
            d=fat[(fat.group==g)&(fat.metric=='wpm5')&(fat.fatigue_enabled==on)].copy();d['minutes']=d.test_duration/60
            errline(ax,d,'minutes',GROUP_CN[g]+('：热身/疲劳开启' if on else '：关闭'))
    ax.legend();save(f,29,'fatigue','最长30分钟；曲线为整场平均，不是末段瞬时速度。疲劳与热身参数为先验，个体允许非单调变化。','results/analysis/fatigue_statistics.csv')
    lc=data('lexical_control_statistics');f,ax=fig('隔离语料组成与上下文先验','控制条件','标准 WPM')
    labels=['coherent','random_matched','coherent_no_context','random_uniform']
    for j,g in enumerate(['ordinary','expert']):
        d=lc[(lc.group==g)&(lc.metric=='wpm5')].set_index('control').loc[labels]
        ax.bar(np.arange(4)+(j-.5)*.35,d['mean'],.35,label=GROUP_CN[g])
    ax.set_xticks(range(4),['连贯句词序','匹配词频的乱序','连贯但无上下文增益','独立词库均匀抽样']);ax.tick_params(axis='x',rotation=8);ax.legend()
    save(f,30,'lexical_controls','前两项匹配边际词汇分布但序列不同。上下文效应强度仍由模型先验指定，不能据此反推真实因果效应。','results/analysis/lexical_control_statistics.csv')
    bc=read('validation','boundary_calibration_grid.csv');bf=read('validation','boundary_fit.csv')
    f,ax=fig('词间衔接残差的整任务汇总校准','词间衔接残差均值（秒）','A条件平均标准 WPM')
    for g,d in bc.groupby('group'):
        ax.plot(d.boundary_delay,d.wpm5,'o-',label=GROUP_CN[g]);z=bf[bf.group==g].iloc[0];ax.scatter([z.fitted_boundary_delay_s],[z.target_wpm5],marker='x',s=70)
    ax.legend();save(f,31,'boundary_calibration','曲线为完整仿真网格，叉号为论文WPM均值约束的位置。残差可能合并多种未分辨的词间/任务差异，不应赋予单一生理解释。','results/validation/boundary_calibration_grid.csv;results/validation/boundary_fit.csv')
    (OUT/'manifest.json').write_text(json.dumps(MANIFEST,indent=2,ensure_ascii=False));print(f'Generated {len(MANIFEST)} independent figures × PNG/SVG/PDF')
if __name__=='__main__':main()
