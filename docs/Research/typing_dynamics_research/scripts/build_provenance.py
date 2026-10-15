"""Write explicit evidence, parameter, and artifact provenance (no inferred raw data)."""
from pathlib import Path
import json,shutil,hashlib,sys,platform,importlib.metadata
import pandas as pd
import yaml
ROOT=Path(__file__).resolve().parents[1]
REFS=[
('R01','Dhakal, Vivek; Feit, Anna; Kristensson, Per Ola; Oulasvirta, Antti',2018,'Observations on Typing from 136 Million Keystrokes','10.1145/3173574.3174220','https://userinterfaces.aalto.fi/136Mkeystrokes/','Full author PDF read; Table 3 visually checked on PDF page 5; Table 2 categories checked. Raw 1.4 GB archive not downloaded.','Empirical category-mean IKI constraints and key-hold inputs; WPM summaries constrain a separate whole-task boundary residual; error summaries are descriptive only.'),
('R02','Feit, Anna; Weir, Daryl; Oulasvirta, Antti',2016,'How We Type: Movement Strategies and Performance in Everyday Typing','','https://userinterfaces.aalto.fi/how-we-type/','Official research page/abstract checked.','Motivates explicit preparation, mapping consistency and overlapping finger actions; no numerical parameters fitted.'),
('R03','Pinet, Stéphanie et al.',2022,'Typing expertise in a large student population','10.1186/s41235-022-00424-3','https://link.springer.com/article/10.1186/s41235-022-00424-3','Publisher full text examined; 1301 students; French/AZERTY context.','Continuous expertise and paradigm dependence; not quantitative independent validation of English/QWERTY predictions.'),
('R04','Logan, Gordon D.',2018,'Automatic control: How experts act without thinking','10.1037/rev0000100','https://pubmed.ncbi.nlm.nih.gov/29952620/','Primary bibliographic record/abstract checked.','Hierarchical control motivation, not calibration of recognition or attention constants.'),
('R05','Logan, Gordon D.; Crump, Matthew J. C.',2010,'Cognitive illusions of authorship reveal hierarchical error detection in skilled typists','','https://pubmed.ncbi.nlm.nih.gov/21030660/','Primary abstract checked.','Distinguishes motor/feedback error monitoring; our detection probability and latency remain priors.'),
('R06','Wolfe, Jeremy M.',2021,'Guided Search 6.0: An updated model of visual search','10.3758/s13423-020-01859-9','https://link.springer.com/article/10.3758/s13423-020-01859-9','Publisher/primary record consulted.','Mechanistic context for salience-weighted attention and serial selections; simplified implementation is not Guided Search 6 itself.'),
('R07','Bouma, Herman',1970,'Interaction effects in parafoveal letter recognition','10.1038/226177a0','https://pubmed.ncbi.nlm.nih.gov/5437004/','Primary record checked.','Eccentricity-linked interference motivates spatial kernel; 0.45 coefficient is an explicit word-task prior, not a universal empirical constant.'),
('R08','Gibaldi, Agostino; Sabatini, Silvio P.',2021,'The saccade main sequence revised: A fast and repeatable tool for oculomotor analysis','10.3758/s13428-020-01388-2','https://pmc.ncbi.nlm.nih.gov/articles/PMC7880984/','Primary full-text page consulted.','Amplitude-dependent saccade dynamics; numerical linear-duration coefficients here are priors.'),
('R09','de Xivry, Jean-Jacques Orban et al.',2009,'Smooth pursuit performance during target blanking does not influence the triggering of predictive saccades','','https://jov.arvojournals.org/article.aspx?articleid=2203981','Primary journal abstract and author-hosted record checked.','Predictive tracking and catch-up distinctions under blanking; not direct typing-task evidence.'),
('R10','Lencer, Rebekka et al.',2004,'Cortical mechanisms of smooth pursuit eye movements with target blanking. An fMRI study.','10.1111/j.1460-9568.2004.03229.x','https://pubmed.ncbi.nlm.nih.gov/15016102/','Primary journal bibliographic record consulted.','Motivates continued prediction during blanking; no numerical calibration.'),
('R11','Niehorster, Diederick C. et al.',2015,'Manual tracking enhances smooth pursuit eye movements','','https://jov.arvojournals.org/article.aspx?articleid=2474042','Primary journal abstract checked.','Eye-hand task interactions; moving a hand-held tracker is not a typing experiment.'),
('R12','Rayner, Keith et al.',2010,'Eye movements, the perceptual span, and reading speed','10.3758/PBR.17.6.834','https://pmc.ncbi.nlm.nih.gov/articles/PMC3075059/','Primary study consulted.','Preview/perceptual span motivation; reading ability is not assumed to equal typing expertise.'),
('R13','Fitts, Paul M.',1954,'The information capacity of the human motor system in controlling the amplitude of movement','10.1037/h0055392','https://doi.org/10.1037/h0055392','Original research identified; source task is aimed movement, not general typing.','Geometry-related lower constraint only, not an additive universal IKI law.'),
('R14','MacKenzie, I. Scott',1989,"A note on the information-theoretic basis for Fitts’ law",'10.1080/00222895.1989.10735486','https://www.yorku.ca/mack/JMB89.html','Full author-hosted text examined.','Source of Shannon-form log2(1+D/W); its use for finger travel here remains a model assumption.'),
('R15','TextBlob contributors; Norvig, Peter','n.d.','TextBlob 0.19.0 packaged English spelling count lexicon','','https://raw.githubusercontent.com/sloria/TextBlob/dev/src/textblob/en/en-spelling.txt','Local installed version copied, original header retained, SHA-256 recorded; upstream text checked online. Version year not a new study date.','Actual count lexicon, within-word n-gram frequencies and dictionary-neighbor preprocessing.'),
('R16','Norvig, Peter',2007,'How to Write a Spelling Corrector','','https://www.norvig.com/spell-correct.html','Author page checked.','Corpus provenance context; not a contemporary representative language frequency norm.'),
('R17','Balota, David A. et al.',2007,'The English Lexicon Project','10.3758/BF03193014','https://elexicon.wustl.edu/','Official project and dataset description located; trial-level data not downloaded.','Future lexical calibration candidate only; no ELP reaction times were used or fitted.')]

DESC={
'seed':'主随机种子','duration_s':'计分墙钟时长','dt_s':'连续积分步长','preview':'是否允许下一词预视','preview_reveal':'下一词出现触发事件','submit':'提交键','correction':'纠错策略','allow_skip':'主任务禁止主动跳词','memory':'完整单词工作记忆开关','force_tracking':'识别后持续追踪条件',
'font_height_deg':'字形高度视角','screen_width_px':'显示宽度像素','screen_height_px':'显示高度像素','screen_width_cm':'显示物理宽度','viewing_distance_cm':'观看距离','field_width_deg':'词中心出现范围宽度','field_height_deg':'词中心出现范围高度','fixed_slot_x_deg':'固定槽位横坐标绝对值','sampling':'词库抽样分布','min_length':'最短词长','max_length':'最长词长','minimum_corpus_count':'词库最低原始计数','cue_strength':'目标线索相对显著性','distractors':'干扰词数量','speed_deg_s':'初始/标称移动速度','trajectory':'轨迹家族','max_accel_deg_s2':'有界加速度家族上限','predictability':'速度回归/加速度噪声控制量，不是已标定心理量','occlusion_duty':'外部遮挡目标占空比','occlusion_duration_s':'遮挡平均持续时间','occlusion_depth':'外部遮挡不透明度','occlusion_phase':'遮挡发生在编码前/后','max_recognition_s':'最大单词识别等待','similarity':'请求的干扰词相似度，实际值另记','fatigue':'疲劳与热身开关','fatigue_start_min':'疲劳项开始时间','fatigue_slope':'默认疲劳斜率（真实个体值另在Person中抽样）','warmup_gain':'默认热身幅度（个体值另抽样）','speed_policy':'速度—准确率策略','memory_half_life_s':'记忆保持时间尺度（不是指数半衰期公式的实测半衰期）','attention':'注意力竞争开关','pursuit':'平滑追踪开关','prediction':'运动预测开关','crowding':'视觉拥挤开关','competition':'识别竞争开关','parallel':'不同手指预备并行开关','sequence':'序列熟悉度开关','fixed_eye':'固定延迟替代眼动的消融开关','errors':'运动错误生成开关',
'saccade_latency_s':'扫视准备时间的均值','saccade_latency_cv':'扫视准备时间变异系数','saccade_duration_intercept_s':'扫视时长截距','saccade_duration_s_per_deg':'扫视时长幅度斜率','saccade_endpoint_sd_deg':'扫视落点标准差截距','saccade_endpoint_sd_per_deg':'扫视落点标准差幅度斜率','pursuit_latency_s':'延迟观察与追踪启动尺度','pursuit_gain':'名义追踪增益（实际使用Person抽样值）','pursuit_tau_s':'眼速度一阶控制时间常数','pursuit_position_gain_s_inv':'眼位置误差反馈系数','catchup_threshold_deg':'追赶扫视误差阈值','bouma_factor':'拥挤临界间距的偏心度系数','sensory_observation_sd_deg':'位置感知噪声标准差','position_process_noise':'位置状态估计过程噪声强度','recognition_base_s':'词汇证据积累的基础时间尺度','recognition_frequency_s':'低频惩罚系数','recognition_length_s':'长词惩罚系数','recognition_diffusion':'证据扩散强度','recognition_threshold':'识别阈值','context_drift_gain':'连贯条件漂移率增益先验',
'boundary_delay_s':'词间动作衔接残差均值；整任务汇总数据推导','alt_s':'跨手基础间隔尺度','left_ratio':'左手相邻动作间隔比','right_ratio':'右手相邻动作间隔比','repeat_s':'同键重复间隔尺度','between_motor_cv':'个体间运动尺度变异系数','planning_s':'单次中央动作规划时间','planning_gap_s':'词内计划生成间距','lookahead':'可预规划按键数','motor_attention':'运动期间注意力需求份额','error_p':'单动作错误基础概率','detection_p':'词内检测概率','keyboard_look_p':'每词看键盘概率','key_hold_s':'平均按键保持时间'}

def unit(k):
    if k.endswith('_cm'):return 'cm'
    if k.endswith('_px'):return 'px'
    if k=='speed_deg_s':return 'deg/s'
    if k.endswith('deg_s2'):return 'deg/s^2'
    if k.endswith('_deg'):return 'deg'
    if k.endswith('_s'):return 's'
    if k.endswith('_min'):return 'min'
    if k=='position_process_noise':return 'deg^2/s^3'
    if k=='recognition_diffusion':return 'evidence/sqrt(s)'
    if k=='saccade_duration_s_per_deg':return 's/deg'
    if k=='pursuit_position_gain_s_inv':return '1/s'
    return 'dimensionless / categorical'

def main():
    refs=[]
    for id,author,year,title,doi,url,access,use in REFS:
        refs.append(dict(id=id,authors=author,year=year,title=title,doi=doi,url=url,verification=access,use=use,accessed='2026-10-13'))
    (ROOT/'data/metadata/references.json').write_text(json.dumps(refs,indent=2,ensure_ascii=False))
    bib=[]
    for r in refs:
        fields=[f'  author = {{{r["authors"]}}}',f'  title = {{{r["title"]}}}',f'  year = {{{r["year"]}}}',f'  url = {{{r["url"]}}}']
        if r['doi']:fields.append(f'  doi = {{{r["doi"]}}}')
        bib.append('@misc{'+r['id']+',\n'+',\n'.join(fields)+'\n}')
    (ROOT/'report/references.bib').write_text('\n\n'.join(bib))
    lines=['# 数据与文献溯源','',
       '本次使用的是已核验论文中的汇总表及真实公开词汇计数，不是自行招募的人类实验。没有取得原始逐键日志；没有拟合 ELP 反应时。所有仿真 CSV 均明确位于 results，与外部观测 data/raw/typing_summary_observations.csv 分开。','',
       '检索于 2026-10-13 进行，覆盖打字、视觉搜索、追踪/遮挡、拥挤、阅读预视及运动控制。属于有目标的跨领域检索，不宣称穷尽所有论文或完成 PRISMA 系统综述。','',
       '检索词组包含：136 million keystrokes typing; How We Type movement strategies; typing expertise random words preview; typing hierarchical error detection; Guided Search 6; pursuit target blanking; saccade main sequence; Bouma crowding; English Lexicon Project; corpus English word frequency.','',
       '主数据：en-spelling.txt 直接复制自已安装 TextBlob 0.19.0，保留文件头并记录哈希。该计数表来自混合历史语料，不等于现代口语词频。自写 sentences.txt 是50条实验用连贯句子，不是外部人类试次记录。','',
       '容器联网下载失败：网络/DNS受限；浏览器工具能够读取网页及作者PDF。未将未下载的完整Aalto数据列入交付包。download_data.py提供可联网环境的获取方法，默认不下载1.4GB原始日志。','']
    for r in refs:
        lines.extend([f'## {r["id"]} · {r["title"]}',f'{r["authors"]}，{r["year"]}。 DOI：{r["doi"] or "未在本项目中核实/不适用"}。',f'来源：{r["url"]}',f'核验范围：{r["verification"]}',f'本项目用途：{r["use"]}',''])
    (ROOT/'data/sources.md').write_text('\n\n'.join(lines))
    rows=[]
    baseline=yaml.safe_load((ROOT/'configs/baseline.yaml').read_text());visual=yaml.safe_load((ROOT/'configs/visual.yaml').read_text())
    design={'seed','duration_s','dt_s','preview','preview_reveal','submit','correction','allow_skip','memory','force_tracking','font_height_deg','screen_width_px','screen_height_px','screen_width_cm','viewing_distance_cm','field_width_deg','field_height_deg','fixed_slot_x_deg','sampling','min_length','max_length','minimum_corpus_count','distractors','speed_deg_s','trajectory','occlusion_duty','occlusion_duration_s','occlusion_depth','occlusion_phase','max_recognition_s','fatigue','attention','pursuit','prediction','crowding','competition','parallel','sequence','fixed_eye','errors'}
    bounds={'recognition_base_s':'.14–.23','saccade_latency_s':'.14–.23','recognition_diffusion':'.25–.50','context_drift_gain':'0–.25','bouma_factor':'.30–.60','memory_half_life_s':'3–15 in LHS; .5–30 in single factor','speed_deg_s':'0–10','font_height_deg':'.22–.55','occlusion_duty':'0–.4','occlusion_duration_s':'.08–1.2','distractors':'0–24','predictability':'.2–1','field_width_deg':'6–40'}
    for k,v in {**baseline,**visual}.items():
        source='实验设计' if k in design else 'R06–R14 机制约束；数值为显式先验'
        rows.append(dict(parameter=k,group='shared',meaning=DESC.get(k,k),unit=unit(k),value=str(v),status='design' if k in design else 'prior',source=source,
            uncertainty=bounds.get(k,'固定设计值' if k in design else '未被本次LHS完整覆盖；见单变量/结构消融'),applicability='本项目任务，不是通用人体常数'))
    population=yaml.safe_load((ROOT/'configs/population.yaml').read_text())
    for group,d in population.items():
        for k,v in d.items():
            if k=='evidence':continue
            fit=k in ('alt_s','left_ratio','right_ratio','repeat_s','boundary_delay_s') and group in ('beginner','ordinary','expert')
            observed=k=='key_hold_s' and group in ('beginner','ordinary','expert')
            status='aggregate_fit' if fit else 'observed_input' if observed else 'interpolation' if group=='skilled' and k in ('alt_s','left_ratio','right_ratio','repeat_s','boundary_delay_s') else 'prior'
            rows.append(dict(parameter=k,group=group,meaning=DESC.get(k,k),unit=unit(k),value=str(v),status=status,
                source='R01 Table 3' if fit or observed else d['evidence'],uncertainty='个体运动对数正态变异+LHS乘子；不能由汇总拟合识别所有参数',applicability='合成能力档；非人口分层估计'))
    extra=[
('boundary_delay_multiplier','Uniform(0.6,1.4)','1','词间衔接残差的参数先验乘子'),('boundary_trial_log_sd','0.25','1','每词衔接残差的对数波动'),('acuity_e0_deg','.85','deg','字母偏心度尺度截距'),('acuity_font_multiplier','2.2','1','字体对可辨范围系数'),('acuity_power','1.45','1','偏心度衰减指数'),('font_width_ratio','.56','1','字形横向宽高比'),('motion_slip_scale','14','deg/s','视网膜滑移质量损失尺度'),('crowding_edge_intercept','.12','deg','拥挤核基础尺度'),('competitor_floor','.04','1','竞争者漂移率底值'),('competitor_gain','.68','1','竞争者相似性漂移率增益'),('competitor_power','4','1','竞争相似度指数'),('motor_travel_a','.028','s','手指几何定位时间截距'),('motor_travel_b','.040','s/bit','手指几何定位难度系数'),('same_finger_multiplier','1.16','1','同指异键额外序列约束'),('sequence_gain','.038','1/logcount','n-gram熟悉度效应'),('sequence_center','4.2','logcount','序列熟悉度参考点'),('rhythm_ar','.35','1','逐键节奏自相关'),('rhythm_log_sd','.18','1','逐键对数噪声标准差'),('error_detection_median','.14','s','纠错检测时间中位数'),('error_detection_log_sd','.2','1','纠错检测对数波动'),('error_type_probs','.40,.15,.13,.13,.10,.09','probability','相邻误触/遗漏/重复/颠倒/同手/规划错误类型比例'),('memory_hazard_base','.006','1','记忆失败概率的危险度系数'),('memory_age_power','1.3','1','记忆保留时间指数'),('memory_length_power','2','1','词长对记忆失败的影响'),('eye_accel_clip','300','deg/s^2','追踪眼速度变化上限'),('eye_speed_clip','35','deg/s','眼追踪速度截断'),('gaze_keyboard_duration','.24','s','每词看键盘的时间片'),('gaze_keyboard_move','.050','s','向键盘转移的平滑路径时长'),('saccade_sensitivity','.025','1','扫视期证据获取系数'),('return_inhibition','.12 for .7 s','1,s','访问过干扰目标的抑制'),('motion_speed_cap','1.8 × nominal','deg/s','速度截断'),('motion_accel_mean_reversion','2','1/s','有色加速度均值回归'),('motion_velocity_mean_reversion','.20','1/s','有界加速度轨迹的漂移回归'),('fatigue_person_slope','clipped N(.008,.007),[-.008,.032]','1/min','个体疲劳斜率'),('warmup_person_gain','clipped N(.015,.015),[-.03,.06]','1','个体热身效应'),('lexical_person_log_sd','.12','1','词识别个体变异，各组相同'),('saccade_person_log_sd','.12','1','扫视准备个体变异，各组相同'),('pursuit_person_gain','clipped N(.93,.035),[.78,1.02]','1','追踪增益个体变异，各组相同')]
    for k,v,u,meaning in extra:rows.append(dict(parameter=k,group='shared',meaning=meaning,unit=u,value=v,status='prior',source='机制候选函数；无对应的本次原始数据拟合',uncertainty='部分受结构消融检查；并非所有常数均已传播不确定性',applicability='需在目标任务中识别/标定'))
    pd.DataFrame(rows).to_csv(ROOT/'data/metadata/parameters.csv',index=False)
    packages=['numpy','scipy','pandas','matplotlib','numba','llvmlite','PyYAML','pytest','textblob','cmudict']
    env={}
    for package in packages:
        try:
            env[package]=importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            if package in packages[:8]:
                raise
            env[package]='not installed (optional source acquisition package)'
    env['python']=sys.version;env['platform']=platform.platform()
    (ROOT/'results/logs/environment.json').write_text(json.dumps(env,indent=2))
    (ROOT/'requirements.txt').write_text('\n'.join(f'{p}=={env[p]}' for p in packages[:8])+'\n')
    lic=Path('/opt/pyvenv/lib/python3.13/site-packages/textblob-0.19.0.dist-info/LICENSE')
    if lic.exists():shutil.copy(lic,ROOT/'data/raw/TEXTBLOB_LICENSE.txt')
    (ROOT/'data/metadata/raw_manifest.json').write_text(json.dumps({str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'data/raw').glob('*') if p.is_file()},indent=2))
    print('references',len(refs),'parameters',len(rows))
if __name__=='__main__':main()
