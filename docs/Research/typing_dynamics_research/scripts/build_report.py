"""Assemble a Chinese report from retained data, then optionally compile with XeLaTeX."""
from pathlib import Path
import sys,json,argparse,subprocess,shutil
import numpy as np
import pandas as pd
import yaml
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'src'))
from typing_sim.config import GROUPS,GROUP_CN
A=ROOT/'results/analysis';R=ROOT/'report'

def table(rows,headers):
    return '| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+'\n'.join('| '+' | '.join(str(v).replace('|','/') for v in row)+' |' for row in rows)+'\n'
def fmt(x,d=1):return f'{float(x):.{d}f}'
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--pdf',action='store_true');args=ap.parse_args()
    b=pd.read_csv(A/'baseline_statistics.csv');no=pd.read_csv(A/'no_preview_statistics.csv')
    ct=pd.read_csv(A/'paired_task_contrasts.csv');ab=pd.read_csv(A/'ablation_contrasts.csv')
    sens=pd.read_csv(A/'sensitivity_statistics.csv');unc=pd.read_csv(A/'uncertainty_intervals.csv')
    ranks=pd.read_csv(A/'sensitivity_rank.csv');sur=pd.read_csv(A/'surrogate_parameters.csv')
    dt=pd.read_csv(A/'time_step_contrasts.csv');macro=pd.read_csv(A/'external_macro_comparison.csv')
    fits=pd.read_csv(ROOT/'results/validation/boundary_fit.csv');lex=json.loads((ROOT/'data/metadata/lexicon.json').read_text())
    digest=json.loads((A/'digest.json').read_text());pop=yaml.safe_load((ROOT/'configs/population.yaml').read_text())
    refs=json.loads((ROOT/'data/metadata/references.json').read_text());figs=json.loads((ROOT/'figures/manifest.json').read_text())
    pp=pd.read_csv(ROOT/'data/metadata/parameters.csv');raw=pd.read_csv(ROOT/'results/baseline/baseline_sessions.csv')
    def m(group,task,metric='wpm5',frame=b):return frame[(frame.group==group)&(frame.task==task)&(frame.metric==metric)].iloc[0]
    def image(i):
        z=next(z for z in figs if z['number']==i)
        return f'\n![图 {i}　{z["caption"]}](../figures/{z["stem"]}.png){{width=96%}}\n\n'
    def sline(g,task='D'):
        d=m(g,task);return f'{fmt(d["mean"])} WPM（条件均值区间 {fmt(d.ci_low)}–{fmt(d.ci_high)}）'
    parts=[]
    parts.append('''---
title: "动态随机英文单词打字"
subtitle: "视觉—认知—十指运动的耦合建模与仿真研究"
author: "可复现计算研究项目"
date: "2026年10月13日"
lang: zh-CN
toc-title: "目录"
---

# 1　摘要
''')
    parts.append(f'''本研究考察人类在二维屏幕中定位、识别并输入随机英文单词时，视觉与动作系统怎样共同限制速度。建立了连续目标运动和眼动、随机词汇证据积累、十指独立资源、按键顺序、词间衔接、工作记忆及实际纠错事件组成的混合模型。研究不是把若干固定延迟相加，也不直接给五类人指定固定WPM。

已执行 {digest['executed_sessions']:,} 场主实验、校准和扩展会话，累计模拟 {digest['simulated_hours']:.1f} 小时任务时间；另有连续眼动微实验和固定事件轨迹。核心比较包含 {digest['baseline_people']} 个合成个体、{digest['baseline_sessions']:,} 场一分钟测试、五类能力与四种任务。程序保存了逐词输出、参数、种子、作业清单和运行元数据。

在“下一词于当前词首次击键时出现”的主规则下，动态随机词条件D的平均标准WPM依次为：{ '、'.join(fmt(m(g,'D')['mean']) for g in GROUPS) }。对应每分钟完整正确词数为：{ '、'.join(fmt(m(g,'D','actual_wpm')['mean']) for g in GROUPS) }。这些数量属于定义明确的模型能力档，不是现实人口抽样均值；顶尖档尤其属于外推。

最稳健的结果不是“移动一律损失多少百分比”，而是任务的依赖关系：识别后可以把词交给记忆和运动程序，因而容易跟踪的缓慢运动不必持续占用视觉；能否提前看下一词，比低速位移更容易改变总吞吐率。另一个重要结果是计分与词库组成的交互：长词可能提高五字符WPM，同时降低完整词数/分钟。

实证约束来自公开论文的击键类别均值、按键保持时间及整体WPM，而非本次未获得的逐键原始日志。词内校准后整任务速度仍偏高，因此进一步估计独立的词间衔接残差，使微观与宏观汇总约束能够同时进入模型。该残差不被解释为已经测得的某一种纯认知时间。报告分别呈现蒙特卡洛精度、合成个体差异和参数先验传播，不将其混为现实预测置信度。
''')
    parts.append(r'''# 2　研究背景与核心问题

所研究的行为包含几种不同的“快”：手指按得快、词汇识别快、视觉从一个目标转向另一个目标快，以及把这些过程衔接得好。训练可能改善动作自动化和规划，但不意味着扫视潜伏期或追踪生理能力同步大幅提升。模型因而对基础眼动和识别生理参数使用共同分布，只对运动、自动化、看键盘、错误和预规划等能力维度分层。

研究围绕十个问题展开：不同能力档的有效输入速度；连贯文本与独立随机词的差别；空间随机化与移动的额外影响；低速移动是否必须受罚；视觉、识别与动作瓶颈如何转移；记忆和预视怎样改变依赖关系；动作继续加快时是否饱和；遮挡、相似词和密度的交互；合理的条件预测范围；以及下一轮人类实验最有价值的测量对象。

这是一项机制候选模型的计算研究。模型复杂度服务于可解释和可检验性，而不是把所有心理过程都赋予一个新参数。对无法从汇总观测识别的机制，采用明确的先验或残差，并记录替代解释。

# 3　文献检索、实证数据与证据边界

检索覆盖打字运动、层级控制、视觉搜索、拥挤、阅读预视、扫视及追踪遮挡。优先使用作者页面、原始论文和公开项目。完整核验范围逐条记录在 `data/sources.md`；本次属于有目标的跨领域检索，不宣称穷尽检索或完成形式化系统综述。

Dhakal等的研究公开了大规模自愿在线句子转录数据与代码，论文表3提供不同速度组的击键统计。本项目逐项核对作者PDF后转录12个类别均值，另使用按键保持时间及WPM汇总约束。整体组、最快十分位和最慢十分位的WPM均值分别是51.56、89.56与20.91。源研究采用首键到末键的计时，不能无条件等同本研究从刺激出现算起的墙钟计时；在线自选样本也不能当成人口代表性样本。[R01]

关于日常打字策略、能力连续分布与层级自动化的研究，支持把手指准备、词层控制与实际击键分开，而不是仅按“是否专业”二分。法国大学生数据的语言、键盘布局和试次规则不同，本次不据此声称完成英语QWERTY的独立定量验证。[R02–R05]

视觉搜索、偏心度干扰、主序列眼动和追踪遮挡研究提供了机制约束；它们没有直接给出“移动随机词打字”的全部系数。本项目的显著性权重、追踪控制常数和词框拥挤核均明确标为先验。[R06–R12]

Fitts原始工作研究瞄准运动。模型使用的对数几何项采用后来的Shannon形式，只作为手指定位的可用性下界，与经验按键间隔取最大值；不把该项再加到已包含运动时间的经验IKI之上。[R13–R14]

真实词汇计数取自TextBlob 0.19.0附带的英文计数文件，保留原始文件头、许可说明和SHA-256。其来源是混合历史文本和词频资料，不等于现代口语规范词频。ELP被定位为未来识别校准的候选资料，但本次没有下载、拟合或引用其中某个反应时作为实测参数。[R15–R17]

完整原始击键压缩包未在当前容器中下载。交付包包含已核验的汇总CSV及可联网环境使用的获取脚本，不能将二者称作“已拟合原始逐键数据”。
''')
    parts.append('# 4　任务环境与实验范式\n\n')
    parts.append(table([['A','自写连贯句子的词序','固定双槽位','静止'],['B','词池独立随机抽样','固定双槽位','静止'],['C','同一随机词流','随机二维位置','静止'],['D','同一随机词流','随机二维位置','缓慢移动']],['条件','词汇来源','空间','运动']))
    parts.append(f'''主任务的词池为 {lex['main_pool_size']:,} 个仅含小写英文字母、长度3–8、语料原始计数不少于10的词。B/C/D均匀独立抽样；不附加首字母不同条件。A按50条自写句子的词序产生刺激，这些句子是实验材料，不是假装收集到的外部观测。A与B的词长和词频分布不同，必须用控制实验区分“词库变化”和“上下文变化”。

显示器名义尺寸1920×1080像素、宽53.1厘米、观看距离60厘米。目标中心主范围28×15度，字形高度0.38度，按该换算约为14.4像素。A/B固定位置交替位于横向±1.6度。主条件没有干扰词或外部遮挡；扩展实验另行添加。

下一词在当前词第一次字母击键时出现，至多预视一词；目标由显著性线索区分。未提交当前词时，不能输出下一词的字符。当前词正确编码后可移开视线，通过空格提交，默认在词尾修正，不能主动跳过。目标内容不因移动而改变，轨迹与用户输入独立。

每场持续60秒，时间包含定位、识别、词间衔接、输入及修复；截至60秒尚未提交的词不计入正确字符。若6秒内无法识别必须输入的词，会话停止产生后续字符，但仍按完整测试时间计分并记录失败，而不是偷偷跳词。

无预视实验使用相同任务定义，但只有提交后才出现下一词。其主比较个体另抽取，故不能直接把两批均值当配对效应；图27使用同一批个体改变预视出现时机，提供配对政策比较。
''')
    parts.append(image(27))
    parts.append('# 5　人群能力分层与个体差异\n\n')
    parts.append(table([[GROUP_CN[g],fmt(pop[g]['alt_s']*1000,1),fmt(pop[g]['planning_s']*1000,1),pop[g]['lookahead'],fmt(pop[g]['motor_attention'],2),fmt(pop[g]['boundary_delay_s'],3)] for g in GROUPS],['能力档','跨手尺度/ms','规划时间/ms','预规划键数','运动注意份额','词间残差/s']))
    parts.append(r'''跨手尺度不是最终平均IKI，更不是WPM。实际按键还受同手/同指、序列熟悉度、手指位置、释放时间、节奏、词边界和纠错影响。基础视觉识别个体对数标准差0.12，扫视准备尺度对数标准差0.12，各能力档相同；追踪增益也使用相同截断正态分布。

对个体运动尺度使用均值为1的对数正态变量：

$$
M_p=\\exp(-\\sigma_g^2/2+\\sigma_g Z_p),\qquad
\\sigma_g^2=\\log(1+CV_g^2),\quad Z_p\sim N(0,1).
$$

每个合成个体在不同任务、重复试次中保持同一能力参数。单次眼动、证据积累、击键节奏和错误使用独立子随机流，因此不把“这个人较慢”和“这次试验偶然较慢”混为一谈。

初学者、普通用户、高水平高手的运动锚点分别来自源研究的慢十分位、整体组、快十分位；这些只是本项目的命名映射，不意味着源数据把这些人实证分类成了对应身份。熟练者在锚点间插值；顶尖情景的运动尺度、预规划和衔接项为外推，不引用未经核验的竞赛纪录。
'''.replace('\\\\','\\'))
    parts.append('# 6　二维动态目标运动模型\n\n')
    parts.append(r'''将像素宽度$p$换算为视角时，使用显示宽度$W_{cm}$、水平分辨率$W_{px}$与观看距离$d$：

$$
\theta(p)=2\arctan\left(\frac{pW_{cm}}{2dW_{px}}\right)\frac{180}{\pi}.
$$

连续状态为位置、速度、有色加速度。主运动采用加速度均值回归噪声，并约束总加速度，而不只是裁剪噪声分量：

$$
 d\mathbf{x}=\mathbf{v}\,dt,\qquad
 d\mathbf{a}=-\lambda_a\mathbf{a}\,dt+\sigma_a\,d\mathbf{W},
$$
$$
 \dot{\mathbf{v}}=\operatorname{clip}_{a_{max}}
 \{\mathbf{a}-\kappa(\mathbf{v}-\boldsymbol\mu)\},\qquad
 \|\mathbf v\|\le1.8v_{nominal}.
$$

主值为标称3度/秒、最大内部加速度12度/秒²。可预测性参数控制噪声和回归强度，不声称其0.85等于人类对轨迹预测准确率85%。

实现匀速到边界停止、理想反弹、平滑周期、OU速度、OU有色加速度、周期与随机混合六类运动。白噪声驱动的OU速度不满足严格有限瞬时加速度，因而作为单独家族，不伪装成有界加速度运动。边界反弹是理想碰撞，速度瞬间翻转；加速度上限测试针对内部连续段，此处的边界例外明确保留。

轨迹在出现后独立推进；观察者晚些才看见目标时，模型先推进真实环境到当前时刻，再开始视觉处理。内部运动估计与真实轨迹分开保存，不允许眼睛无延迟读到未来位置。
''')
    parts.append(image(6))
    parts.append('# 7　眼动、视觉搜索与平滑追踪\n\n')
    parts.append(r'''状态机含注视、扫视准备、扫视、平滑追踪、重新捕获和看键盘。候选目标的选择基于真实位置、相对线索、空间距离、词汇相似度与已访问位置抑制，而非预置每词固定搜索延迟。被选到干扰词后存在识别其非目标身份并重新选择的时间。

扫视准备时间采用对数正态分布，名义均值180毫秒、变异系数0.22；扫视时长随幅度$A$变化：

$$D_s(A)=0.021+0.0022A\quad\text{秒}.$$

落点标准差为$0.10+0.025A$度。扫视路径采用最小加加速度型平滑多项式$10u^3-15u^4+6u^5$；扫视期间证据获取系数降为0.025。以上是可调整的机制先验，并非本次重新测量的眼动主序列。

追踪使用120毫秒的延迟观测、常速度状态估计和位置误差反馈：

$$
 \dot{\mathbf v}_e=
 \operatorname{clip}\left[
 \frac{g\widehat{\mathbf v}+k_x(\widehat{\mathbf x}_{pred}-\mathbf g)-\mathbf v_e}{\tau}
 \right],\qquad \dot{\mathbf g}=\mathbf v_e.
$$

追踪启动不是瞬时完成；误差过大时触发追赶扫视。关闭预测只去掉对延迟与遮挡的外推，不偷换成另一条真实轨迹；关闭追踪时仍允许离散扫视重捕获。

看键盘是另一类注视需求。其概率随运动自动化不同，但模型没有重建真实头部运动、瞳孔大小或眼睑状态。这一模块的有效性首先来自合法的时序和可检验的预测，而不是逼真的动画外观。
''')
    parts.append(image(7)+image(8)+image(9)+image(12))
    parts.append('# 8　拥挤、遮挡与目标重捕获\n\n')
    parts.append(r'''外部遮挡采用有开关状态的更新过程。给定平均遮挡时长$\bar d$和占空比$q$，未遮挡时的发生率为$q/[\bar d(1-q)]$；遮挡持续时间采用形状参数2的Gamma分布。完全和部分遮挡通过可见比例进入证据获取；词框交叉的局部遮挡另由几何面积计算。

拥挤核使用目标框与邻近框的边缘距离$d_i$以及目标偏心度$e$：

$$
 C(e)=\sum_i\exp\left[-\frac12\left(\frac{d_i}{0.12+0.45e}\right)^2\right].
$$

这是平滑的空间近似，不等于直接移植Bouma字母实验的普适定律。局部遮挡与拥挤分属“信息被盖住”和“可见信息互相干扰”，模型中分别处理；多个遮挡框的交叠面积目前采用求和后截断，可能对密集重叠略显保守。

位置预测用常速度Kalman形式维护协方差：

$$P^-_{t+\Delta t}=FP_tF^\top+Q(\Delta t),\qquad
K=P^-H^\top(HP^-H^\top+R)^{-1}.$$

遮挡时只进行预测，协方差增加；再次出现时恢复观察。重捕获依赖误差、状态不确定性和竞争目标，而不是对每次遮挡无差别加一个常数。

图10以“重新可见后误差小于0.8度且不处于扫视”为恢复标准。未在下一次遮挡或会话结束前恢复的事件被记为删失；绘制成功事件的均值时同时保留删失标记，避免零填补掩盖失败。
''')
    parts.append(image(10)+image(11))
    parts.append('# 9　真实词库、词汇竞争与工作记忆\n\n')
    parts.append(f'''原始词汇表含 {lex['types']:,} 个词形、合计 {lex['tokens']:,} 次语料计数。处理后保存词长、计数、对数频率、加权词内二元/三元字母组，以及有限字典中的单字母替换邻居。这里的对数频率定义为 $9+\\log_{{10}}(count/N)$，不是冒充其他数据库的Zipf分数。

词汇相似度组合归一化编辑距离、二元字母组Jaccard相似度、近形字母匹配与单字符邻居指标。请求的相似度只用于寻找相近候选；最终实际达到的相似度随每词记录，因此图15不把请求值当已实现值。
''')
    parts.append(r'''正确词和最强竞争词采用两个非负反射证据累积器。把注意力、可见性、偏心度、字体、滑移和拥挤合并成有效观察时间增量$d\tau$：

$$
 d\tau=dt\;R(t)\,V(t)\,A(e,L,s)\,S(s)\,H(v_{slip})\,
 \frac{\chi_{eye}(t)}{1+C(t)}.
$$
$$
 dE=\mu\,d\tau+\sigma\,dW_\tau,\qquad
 dF=\mu\rho(S_{word})\,d\tau+\sigma\,dB_\tau.
$$

基础漂移率由以下时间尺度确定，单位为秒：

$$
 \mu^{-1}=\lambda_p\left[0.175+0.018(5.5-f)_++0.009(L-5)_+\right].
$$

A条件额外乘$1+0.12$的漂移增益，以先验方式表征上下文帮助；不使用语义模型伪装成已拟合的人类上下文效应。竞争者漂移比例为$\rho=0.04+0.68S_{word}^4$。首先达到阈值1的累积器给出候选，6秒内未达到阈值则保持未识别。

有一个重要数学边界：当几何因素只是同时改变两个累积器的时钟时，它主要改变识别时长及截止前成功率，并不会自动改变无截止情况下的最终错误概率。若未来人类数据表现为拥挤显著改变错误概率，应进一步调整漂移与噪声的比率，而不只是统一减速。本次并未通过硬编码强迫所有干扰因素都提高错误率。

识别后将单词放入工作记忆，随后可提交给动作程序。记忆失败使用显式先验危险度：

$$
 P_{mem}=1-\exp\left[-0.006\left(\frac{t}{h}\right)^{1.3}
 \left(\frac L5\right)^2(1+0.02N_d)\right].
$$

$h$是保持尺度，虽配置键名含half-life，但不是把该函数声称为已测量的指数半衰期。记忆失败会改变实际要输入的内容并进入修复流程。识别后隐藏目标，在成功保留记忆且无需持续追踪的分支中不额外花费视觉资源；这一不变性是模型结构推论，不是新的人类实验证据。
''')
    parts.append(image(13)+image(15))
    parts.append('# 10　十指运动、双手协调与词间衔接\n\n')
    parts.append(r'''ANSI QWERTY键位以键距为单位。模型保存十根手指的位置、可用时刻及按键保持状态，字母按标准指法分配，空格可交替使用拇指；另支持双食指字母映射。主刺激仅为小写，虽然几何表包含Shift位置，但本次没有实现或校准大小写组合键。

经验序列间隔由类别、词内字母组熟悉度、节奏自相关和个体运动尺度共同决定。序列噪声在对数域遵循AR(1)：

$$
 z_i=0.35z_{i-1}+\sqrt{1-0.35^2}\,\epsilon_i,
 \qquad \epsilon_i\sim N(0,0.18^2).
$$

手指几何定位采用下界候选$T_{move}=[0.028+0.040\log_2(1+D/W)]\sqrt{M_p}$。准备、定位和最终字符顺序分开约束：

$$
 t_i^{move}=\max(t_i^{plan,end},t_{f_i}^{available}),
$$
$$
 t_i^{press}=\max\{t_i^{move}+T_i^{move},\;t_{i-1}^{press}+I_i\},
 \qquad t_{f_i}^{available}=t_i^{press}+T_i^{hold}.
$$

该“最大值”结构保证几何定位与经验IKI不会重复计时。不同手指可以提前准备和定位，但所有按键仍按目标串顺序输出。保持键未释放时，其他手指可以按下下一键；同一手指则受释放约束。

词内击键间隔不能独自确定整段打字速度。模型额外设置每词动作衔接事件，在当前词已编码且上一词已提交之后发生，并占用中央规划资源。其平均残差$\delta_g$由整体WPM汇总约束推导：

$$
 B_{p,n}=\delta_g\sqrt{M_p}\,F_p(t)
 \exp(-0.25^2/2+0.25Z_n).
$$

该项可能合并运动块承诺、词边界停顿、源任务未匹配的格式/输入衔接等因素，不能给它唯一的生理归因。它每词只计一次，不与每键规划或视觉潜伏期重复相加。

运动错误包括相邻键、遗漏、重复、颠倒、同手协调和规划错误。识别错误则可能产生整个错误词。模型实际维护输入缓冲区：检测后删除到最长正确前缀，再输入缺失字符；Backspace和重打都是正常按键事件。修复阶段暂设为不再发生二次错误，使流程有限且可终止；高错误场景下可能低估重复修复成本。
''')
    parts.append(image(16)+image(17)+image(18)+image(31))
    parts.append('# 11　视觉—认知—运动耦合与关键路径\n\n')
    parts.append(r'''视觉搜索、识别和中央动作规划消耗有限资源；动作执行使用能力档特定的注意力份额。对眼动积分而言，已有规划与执行事件形成时变资源可用率：

$$R(t)=\max\left(0,1-\min\left(1,\sum_jr_j(t)\right)\right).$$

中央规划片段不可相互重叠；手指运动本身可以重叠。下一词的视觉处理在规则允许的出现时刻启动，可以与当前词的后半段输入并行。全局调度是按依赖关系求解的离散事件与连续积分混合系统，而不是把每个词机械拆成四段相加。

设$R_n$为识别完成时刻、$F_{n-1}$为上词提交时刻，则词间衔接可最早在$\max(R_n,F_{n-1})$开始。对总吞吐率真正产生额外等待的是不能被前一词动作覆盖的视觉服务：

$$V_{stall,n}=\max(0,R_n-F_{n-1}).$$

报告把该项与其后直到提交的临界动作/衔接服务作时间分区，余量是末端删失尾部。另输出的注意力失去机会时间是重叠资源量，不能再与这些分区相加，更不能直接叫作独立“注意力瓶颈占比”。

对理想化、服务相互独立的两级流水线，$\max(V,M)$可作直觉近似；随机服务满足$E\max(V,M)=[EV+EM+E|V-M|]/2$，因此仅用均值取最大仍会漏掉波动带来的等待。真实主模型的出现规则、词间衔接、注意力和反馈依赖更复杂，仿真才是最终计时依据。
''')
    parts.append(image(19))
    parts.append('# 12　数学模型、积分精度与随机数管理\n\n')
    parts.append(r'''完整状态可写作$S=(X,V,G,E,F,H,K,W,A)$，分别对应场景、速度、注视、证据、竞争证据、手指、输入缓冲、记忆和资源。连续状态由5毫秒步长推进；规划、按键、释放、识别完成、提交和错误检测保持实际事件时刻，输出顺序不被限制成一帧一次按键。

证据跨阈值时对最后一步做线性时间插值，不声称精确求出布朗桥首次穿越时刻。轨迹与眼动也存在离散积分偏差，所以另在1、2、5和10毫秒步长上做分布级检查。

随机流使用NumPy SeedSequence，把主种子、个体、重复、词序和模块作为派生键。词汇抽样、初始几何、轨迹、眼动噪声、证据噪声、运动、记忆与遮挡彼此分流。C/D保留同一词流与个体，使任务比较尽量配对。增加一个实验或改变进程调度不会重排其他会话的种子。

不同步长使用相同派生流标识，但不会自动形成同一个布朗路径的精细/粗糙增量耦合。因此步长实验用于均值分布稳定性，而不是声称测得强收敛阶；配对区间只是固定个体/刺激下的差异区间。
''')
    parts.append(image(28))
    parts.append('# 13　参数来源、拟合与不确定性\n\n')
    parts.append(f'''参数清单目前含 {len(pp)} 行，覆盖实验设计、共同先验、各能力档参数及源代码中机制常数。每行记录含义、单位、数值、来源等级、适用条件和不确定性说明；完整表随包提供，不能把未被抽样的固定先验看作没有不确定性。

词内校准采用非线性最小二乘，对每个实证锚点同时拟合四类IKI均值。每档有四个自由经验间隔参数匹配四个均值，其他几何与噪声参数保持先验。因此近乎零的残差只表明数值校准闭合，既不说明模型结构唯一，也不代表独立验证。

词间残差在固定词内模型后，通过完整A条件的仿真网格与单调插值拟合。校准使用与主实验不重叠的合成个体ID；另外用一批新模拟个体检查结果稳定性。但目标WPM仍来自同一篇论文，不是新的人类验证数据。
''')
    parts.append(table([[GROUP_CN[r.group],fmt(r.target_wpm5,2),fmt(r.fitted_boundary_delay_s,3)] for r in fits.itertuples()],['锚点能力档','整体目标WPM','推导的词间残差均值/s']))
    parts.append(r'''个体噪声、群体差异和参数不确定性分别处理。参数传播采用128点拉丁超立方设计：识别基时0.14–0.23秒、扫视准备均值0.14–0.23秒、扩散强度0.25–0.50、运动注意力乘子0.6–1.4、追踪增益乘子0.92–1.06、记忆尺度3–15秒、运动时间乘子0.8–1.2（顶尖0.7–1.3）、词间残差乘子0.6–1.4、拥挤系数0.3–0.6、上下文增益0–0.25。它们是显式先验范围，不是从数据自动得到的后验可信区间。

每个设计点使用四个固定能力实例来降低个体差异与参数差异的混合；因此该分布与主实验的随机个体分布中心未必相同。有限样本、非线性参数平均和固定/随机能力设定都会影响中心位置，不能直接把两者的百分位互换。
''')
    parts.append(image(25)+image(24))
    parts.append('\\clearpage\n\n# 14　软件架构与实际执行\n\n')
    ledger=pd.read_csv(A/'execution_ledger.csv')
    parts.append(table([[r['name'],int(r['executed_sessions']),fmt(r['total_simulated_seconds']/3600,2),fmt(r['wall_seconds'],1),int(r['sessions_with_recognition_failure'])] for _,r in ledger.iterrows()],['批次','执行场次','模拟小时','运行秒','识别到限会话']))
    parts.append(r'''核心源码按配置、词库、轨迹、遮挡、视觉/眼动、记忆、键盘、手指运动、资源调度、计分和统计分离。连续内核由Numba加速，其余数据管理采用NumPy、SciPy和pandas。图形仅使用Matplotlib，每图独立生成；不依靠图像生成模型绘制研究结果。

每批保存完整作业配置的压缩JSONL、会话CSV与元数据；主实验另保存逐词压缩CSV。连续轨迹与每次按键的准备/移动/按下/释放时刻，在固定诊断会话中完整保留。并非给每个一分钟会话都保存连续眼动，以避免数十GB冗余数据。

`requirements.txt`锁定当前依赖，环境版本记录在`results/logs/environment.json`。README提供从离线词库预处理、两阶段校准、全部仿真到报告编译的顺序。执行台账中“模拟小时”是虚拟行为时长，不是计算实际耗时；“识别到限”是已计分的模型失败，不是程序崩溃或被剔除的样本。
''')
    parts.append('\\clearpage\n\n# 15　五类能力与四种基础任务结果\n\n')
    rows=[]
    for g in GROUPS:
        for task in 'ABCD':
            z=m(g,task)
            rows.append([GROUP_CN[g],task,fmt(z['mean']),f'{fmt(z.ci_low)}–{fmt(z.ci_high)}',fmt(m(g,task,'actual_wpm')['mean']),fmt(m(g,task,'lpm')['mean']),fmt(m(g,task,'cpm')['mean'])])
    parts.append(table(rows,['能力情景','条件','WPM₅','均值95%区间','完整词/分','字母/分','字符/分']))
    parts.append('以上区间由个体整体重抽样得到，保留两次重复之间的关联。它描述当前参数下模拟均值的计算精度，不是给真实玩家的95%保证区间。平均数、小数精度和组名不应掩盖参数与任务规则的不确定性。\n\n')
    parts.append(image(1)+image(2)+image(3)+image(4))
    parts.append('# 16　横向、纵向比较与计分解释\n\n')
    rows=[]
    for g in GROUPS:
        q=ct[(ct.group==g)&(ct.policy=='preview')]
        def c(x,y):return q[(q['first']==x)&(q['second']==y)].iloc[0]
        rows.append([GROUP_CN[g],fmt(c('A','B').relative_percent,2),fmt(c('B','C').relative_percent,2),fmt(c('C','D').relative_percent,2)])
    parts.append(table(rows,['能力情景','A→B变化/%','B→C变化/%','C→D变化/%']))
    parts.append(r'''空间随机化增加定位需求，但只要该需求仍能被前一词运动覆盖，就不必以同等幅度减少吞吐。容易跟踪的缓慢移动，在这些条件下常只产生千分级或百分之一级变化。极小正差异也会出现：可能来自时序、落点与纠错的交互；若效应小于积分与结构不确定性，不据此宣布“移动帮助人类打字”。

A→B并非纯上下文干预。一个简化、非流水线的例子足以说明计分反转：若每词固定衔接成本为$h$、每字母时间为$a$，则

$$WPM_{actual}=\frac{60}{h+aL},\qquad
WPM_5=\frac{12(L+1)}{h+aL}.$$
$$\frac{dWPM_5}{dL}=\frac{12(h-a)}{(h+aL)^2}.$$

当$h>a$，词长增加可以让五字符WPM上升，同时完整词/分钟下降。这不是人类更擅长无上下文随机词，而是较长词摊薄每词成本。主模型实际使用事件并行，上式仅用于解释方向。

控制实验将随机词的边际分布匹配到A刺激词元，并比较去掉上下文漂移增益的A。其结果用于检查语料与上下文先验的相对作用，而不是用一个A/B差值替代全部机制分析。
''')
    parts.append(image(30)+image(14))
    parts.append('无预视的D条件如下。与主实验不同，它更接近“打完当前词才出现下一个目标”的游戏规则；直接应用主表中的预视速度会高估这种界面的吞吐率。\n\n')
    parts.append(table([[GROUP_CN[g],fmt(m(g,'D',frame=no)['mean']),fmt(m(g,'D','actual_wpm',no)['mean']),fmt(m(g,'D','lpm',no)['mean']),fmt(m(g,'D','cpm',no)['mean'])] for g in GROUPS],['能力情景','WPM₅','完整词/分','字母/分','字符/分']))
    parts.append('# 17　移动、遮挡、密度与词汇相似性\n\n')
    parts.append(r'''速度扫描覆盖0、1、3、6、10度/秒，并在固定人群与词流下调整可预测性。比较轨迹家族时保留“相同标称速度不等于相同真实速度分布”的限制；周期运动的实际均方速度和加速度不同，所以家族间差值不是仅由可预测性造成。

外部遮挡扫描包含占空比、平均持续时间和编码前后时机。编码前信息不足会阻碍识别；编码后是否有影响，取决于是否需要持续追踪、记忆是否保留，以及下一词是否已经可以搜索。强制追踪条件同时改变预视机会，应将其解释为任务政策差异，而不是孤立眼肌追踪成本。

干扰词密度影响初始候选选择、局部空间拥挤、相互穿越和重新捕获。目标提示越强，搜索越接近直接定位；不能把显著提示下结果推广为无提示、必须阅读所有候选才能选择目标的搜索。

相似词还通过竞争累积器改变错误候选的到达概率。当前先验使该错误相对少见，消融效应可能接近零；这既不是程序失败，也不证明人类不受相似词干扰，而是指出现有竞争参数难以仅凭速度结果辨识。
''')
    parts.append(image(21))
    parts.append('# 18　参数敏感性、交互与疲劳\n\n')
    r=ranks[ranks.group=='expert'].copy();r['abs']=r.spearman_rho.abs();r=r.sort_values('abs',ascending=False)
    parts.append(table([[z.parameter,fmt(z.spearman_rho,3)] for z in r.head(6).itertuples()],['高水平组关键参数','与WPM的Spearman相关']))
    parts.append(r'''该排序只描述给定先验范围内的单调关联。范围选得更宽的参数有更大机会影响输出；相关系数不是方差份额，也不是已经证明的因果贡献。D条件不启用上下文增益，因此其理论直接作用为零，有限LHS设计仍可能出现小的偶然相关。

单变量实验同时覆盖字号、词长、词频、预视开放时机、预规划长度、纠错策略和记忆尺度。每一因素的原始值、实际相似度、均值和区间均在CSV中给出。交互热力图额外检查速度和干扰词密度，不能只靠单变量扫描推断所有组合。

疲劳项允许个体斜率为负或正，并加入热身及缓慢波动：

$$F_p(t)=\exp\{b_p(t_{min}-8)_+-w_p(1-e^{-t_{min}/0.7})
+0.009\sin(2.1t_{min}+\phi_p)\}.$$

最长任务30分钟；图29是整场平均速度，不能误读成第30分钟的瞬时速度。此类长期参数尚无本次直接拟合，因此长时曲线适用于机制探索，不是对所有人规定统一疲劳时刻。
''')
    parts.append(image(20)+image(29))
    parts.append('# 19　机制消融实验\n\n')
    rows=[]
    for z in ab[ab.group=='expert'].sort_values('relative_percent').itertuples():rows.append([z.case,fmt(z.relative_percent,2),f'{fmt(z.relative_ci_low,2)}–{fmt(z.relative_ci_high,2)}'])
    parts.append(table(rows,['关闭/替换机制','WPM变化/%','配对95%区间/%']))
    parts.append(r'''挑战条件包含12个干扰词、6度/秒运动、20%外部遮挡及较相似的词。基线与每种消融共享个体和词流，避免把个体差异误算作机制效果。

关闭记忆不仅取消整词保持，还要求逐字视觉刷新并关闭跨词预视，因此是复合政策干预。其大幅减速不能直接解释为纯记忆的生理贡献。关闭词间衔接对应结构诊断，反映该残差在已校准模型中的作用，不说明其所合并的过程已经被拆分识别。

关闭双手预备并行的效应可能较小，因为经验IKI约束已经包含训练后的协调收益，关闭显式定位重叠不会同步抹掉经验统计中隐含的协调。这个结果揭示参数可辨识性边界；不能用它得出“双手协调无用”。关闭注意力竞争也只改变模型明确占用的资源，不移除所有心理层面的注意。

不纠错时原始按键吞吐可能提高，但净计分按最小编辑对齐得到正确字母，错误单词的提交空格不计为正确空格。报告的净收益没有把错误输入全部当成完成量。
''')
    parts.append(image(22)+image(5))
    parts.append('# 20　函数图像与吞吐率饱和解释\n\n')
    parts.append(r'''为便于任务设计复用，对完整仿真的运动时间乘子扫描拟合一个低阶近似函数：

$$
 \widehat W_5(s)=\frac{60\bar c}{5\left[b_g\sqrt{s}+\left(v^q+(ms)^q\right)^{1/q}\right]},
 \qquad 1\le q\le16.
$$

$s$越小表示动作尺度越快，$v$为任务下的有效速度下界时间，$m$为尺度1的动作服务项，$\bar c$为正确完成词的平均字符数。其中$b_g$固定为该档的词间残差均值，与主模型中的平方根运动尺度一致。该函数只拟合仿真，不替代主模型中的眼动和十指事件；两档网格点不参加拟合，用来检查对未拟合仿真点的插值。
''')
    parts.append(table([[GROUP_CN[z.group],fmt(z.visual_floor_s,3),fmt(z.motor_scale1_s,3),fmt(z.softmax_q,2),fmt(z.rmse_heldout_sim_grid,2),fmt(z.fitted_asymptote_wpm5,1)] for z in sur.itertuples()],['能力情景','v/s','m/s','q','留出网格RMSE','拟合渐近WPM']))
    parts.append(r'''渐近值是给定显示、词库、预视、衔接和噪声假设下的模型量，不是人体最大速度。改变字体、出现规则或词间残差即可改变它。对实际应用更有意义的是边际收益：若把动作再加快一倍只带来很少吞吐提升，继续优化输入动作已不是最有效的设计方向，应检查视觉服务或出现规则。

完整项目生成31张互不依赖子图布局的图，每张保存PNG、SVG、PDF与数据来源清单。轨迹、眼动、手指甘特图和资源时间线均来自保留的实际模拟事件；统计图来自执行CSV；函数曲线注明是机制函数、校准曲线还是低阶拟合。
''')
    parts.append(image(26))
    parts.append('# 21　程序验证、校准检查与误差分析\n\n')
    parts.append(r'''自动化测试覆盖六类轨迹边界、内部加速度上限、遮挡几何、词汇与相似度、十指几何、资源互斥、输出顺序、跨指重叠、释放约束、实际修复、计分与末尾删失、眼动状态合法性，以及固定种子复现。另在新解释器重放每个能力档与任务的一场保留作业，对照关键指标。其执行记录随包保存。

自动化测试30项全部通过；在新解释器中复算20个代表会话，所检查的速度、字符和事件计数全部一致。该复算发生于本地环境，不是跨设备或第三方复现。

程序正确与行为拟合分开验收。词内校准用过的数据不再冒充留出观测；词间校准使用论文WPM，因而主A条件接近该均值也只是校准检查。新模拟个体是计算随机性的留出，不是独立的人类验证。
''')
    parts.append(table([[GROUP_CN[z.group],fmt(z.source_wpm5,2),fmt(z.model_A_wpm5,2),fmt(z.relative_discrepancy_percent,2)] for z in macro.itertuples()],['锚点能力档','源WPM约束','主A模拟均值','差异/%']))
    parts.append('未加入词间衔接时的A整体偏差也保存在独立结构诊断中，避免仅报告能够拟合的指标。最终闭合均值仍不解决源任务计时、大小写、标点、文本展示方式和样本选择的差异；这些都是迁移误差来源。\n\n')
    q=dt[dt.dt_s==.005]
    parts.append(table([[GROUP_CN[z.group],fmt(z.relative_percent,3),f'{fmt(z.relative_ci_low,3)}–{fmt(z.relative_ci_high,3)}'] for z in q.itertuples()],['能力情景','5ms相对1ms变化/%','配对区间/%']))
    parts.append('步长误差没有自动被当成零。千分级的C/D效应不适合仅凭统计显著性解释为心理学发现；数值偏差与结构不确定性的量级同样需要比较。\n\n')
    parts.append(image(23))
    parts.append('# 22　预测范围、适用条件与潜在瓶颈\n\n')
    rows=[]
    for g in GROUPS:
        z=m(g,'D');u=unc[unc.group==g]
        prior='未单独传播' if u.empty else f'{fmt(u.iloc[0].p025)}–{fmt(u.iloc[0].p975)}'
        rows.append([GROUP_CN[g],fmt(z['mean']),f'{fmt(z.p05)}–{fmt(z.p95)}',prior,fmt(m(g,'D','visual_bottleneck_fraction')['mean']*100,1)])
    parts.append(table(rows,['能力情景','动态WPM均值','合成个体P05–P95','参数先验P2.5–P97.5','视觉等待占时/%']))
    parts.append(r'''合成个体区间描述固定参数体系下两次一分钟测试均值的分布；参数先验区间描述不同参数设计点的条件平均输出。没有将两者简单相加，也没有称它们为现实个体已验证的95%预测区间。两类区间均不包含所有未实现的机制。

在低运动能力档，词间衔接与动作执行占用较长，眼睛通常有机会在后台处理下一词；视觉搜索变快未必明显提高总速。高能力档的动作服务较短，空间定位和识别更容易露出成为等待。所谓瓶颈转移，是依赖关系和相对服务时间变化，不意味着某个器官固定决定所有任务的上限。

使用结果时必须同时指定词库、长度、显著提示、屏幕范围、预视、提交与纠错规则。设计游戏生成速率时，完整正确词/分钟通常比五字符WPM更直接；输入带宽或字符计分则应使用LPM/CPM。不能把词数、标准词或原始按键数混为同一单位。
''')
    parts.append('# 23　模型边界与未来人类实验\n\n')
    parts.append(r'''仍需重点识别的不是“所有常数”，而是对任务迁移有决定作用的几类量：词间衔接残差在匹配规则下能否保留；识别后转移视线的时刻与眼—手跨度；看键盘导致的资源中断；给定字体、密度和运动下的有效识别漂移/噪声比；错认、动作错误与反馈修复的分离；以及顶尖档的真实逐键与停顿结构。

建议采用被试内交叉设计，先按独立基准转录速度连续分层，再进行A/B/C/D与预视有无条件，而不是仅按自报水平分组。匹配控制应把同一批词分别用于连贯序列与打乱序列，统一字形、长度、大小写和提交规则。核心移动比较先用可预测低速轨迹，再加入难度维度；遮挡前后应以实际识别/眼动状态触发，不能只按固定出现延迟粗略代替。

记录目标完整轨迹、显示刷新时刻、眼动、每次keydown/keyup、输入缓冲、错误提示与正确提交。所有设备时钟须对齐，键盘事件分辨率不等于物理开关闭合时间的准确度；浏览器/操作系统延迟应单独校正。眼动采样频率和显示刷新率应写入每份记录，而不隐藏在设备名称中。

首轮以小样本先导估计配对差异标准差，再按目标精度或统计功效确定人数。例如配对均值效应的近似规划式为$n\approx[(z_{1-\alpha/2}+z_{1-\beta})s_\Delta/\Delta]^2$；若真实移动效应仅千分级，需要的样本远大于检测预视政策的大效应。不能把模拟人数当作所需真实受试者人数。

拟合时按受试者划分训练/验证，整段保留同一个体的连续键序和眼动，避免随机拆分单个按键造成泄漏。先估计动作、词间、视觉子任务，再进行联合校准；采用参数可辨识性分析与后验预测检查，判断不同组合是否产生同样WPM。新增人类数据应替换现有对应先验，不必推翻可执行事件框架。

实现边界还包括：几何字框不是真实字形渲染；两累积器近似不是完整词汇网络；修复按键目前无二次错误；没有模拟大小写Shift和真实双眼/头动；词尾反馈检测没有逐字回读输入行；长期疲劳和记忆参数尚未直接拟合。源数据与当前任务的差异通过词间残差部分吸收，但不因此得到唯一正确的机制解释。
''')
    parts.append('# 24　结论\n\n')
    parts.append('动态随机词打字可以被建模为可执行的感知—动作耦合系统，而不是一个固定WPM乘若干难度系数。此次研究实际实现并执行了从二维动态目标、眼动、词汇证据、十指调度到错误修复的全过程，并用公开汇总观测同时约束词内与整体速度。\n\n')
    parts.append('对本任务，识别后的记忆和预视规则是解释低速移动影响的关键：移动不必持续消耗眼动资源，只有不能被并行过程覆盖的服务才真正限制吞吐。空间随机化、遮挡、搜索密度和动作加速的效果因此依能力和任务政策而变。\n\n')
    parts.append('标准WPM与完整英文词数必须分开。词库组成和词长会通过词边界成本改变指标方向，所以“随机词更快/更慢”不是脱离呈现与计分规则的普遍命题。现有数值可用于有条件的机制分析、难度探索和后续实验设计；将其迁移为现实人群或具体玩家的窄区间预测，需要匹配任务下的人类数据。\n\n')
    parts.append('# 25　参考文献与数据来源\n\n')
    for z in refs:
        title=z['title'];doi=f' DOI: {z["doi"]}.' if z['doi'] else ''
        parts.append(f'**[{z["id"]}]** {z["authors"]}. {title}. {z["year"]}.{doi} [来源]({z["url"]})。\n\n')
    parts.append('# 26　附录：指标、参数与复现索引\n\n')
    parts.append(r'''## 26.1　计分的精确定义

令$T$为分钟，$N_w$为截止前正确提交的完整词数，$N_l$为已提交内容中最小编辑对齐确定的正确字母数。只有完整词正确时，其提交空格才计入正确字符：

$$CPM=\frac{N_l+N_w}{T},\quad LPM=\frac{N_l}{T},\quad
WPM_5=\frac{CPM}{5},\quad WPM_{actual}=\frac{N_w}{T}.$$

因此恒有$CPM=5WPM_5=LPM+WPM_{actual}$。主任务修复后提交，未纠正错误为零是规则后果，不是模型声称所有人从不打错。`corrected_errors_per_char`在默认修复任务中表示每目标字符生成的已修复错误事件；在不修复消融中该历史字段名不能按字面解释，图表将它称为错误事件率。编辑错误率、错误事件率和退格键比例分别保存。

## 26.2　参数文件与结果索引

`configs/baseline.yaml`和`visual.yaml`定义任务与共同机制；`population.yaml`保存两阶段校准及插值/外推的能力档。`data/metadata/parameters.csv`逐行列出全部主要参数，`references.json`记录各来源的实际核验范围。`results/analysis/`保存统一统计表，`results/validation/`保存数值校准、结构诊断、步长检验与测试记录。

## 26.3　运行最小例子

```bash
python -m pip install -r requirements.txt
python -m pip install -e . --no-deps
python scripts/run_one.py --group expert --task D --seconds 60
python scripts/reproduce_check.py
python -m pytest -q
```

完整重建顺序见README。原始输入和最终交付文件提供SHA-256清单；代码修改后应重新运行有关实验，不要把旧CSV与新参数混用。PDF需要额外的Pandoc、XeLaTeX与系统中文字体，但仿真和Markdown报告不依赖PDF编译环境。

## 26.4　图表与原始数据对应

''')
    parts.append(table([[z['number'],z['stem'],z['sources'].split(';')[0]] for z in figs],['图号','文件基名','首要数据源']))
    text='\n'.join(parts)
    (R/'research_report.md').write_text(text)
    # Small, reproducible document styling. Font files remain system resources.
    header=r'''\usepackage{caption}
\usepackage{float}
\usepackage{placeins}
\usepackage{fancyhdr}
\usepackage{fvextra}
\captionsetup{labelformat=empty,font=small}
\floatplacement{figure}{H}
\setlength{\emergencystretch}{3em}
\setlength{\parskip}{0.55em}
\setlength{\headheight}{15pt}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small 动态随机词打字 · 计算研究}
\fancyhead[R]{\small 2026.10}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0.3pt}
\DefineVerbatimEnvironment{Highlighting}{Verbatim}{breaklines,commandchars=\\\{\}}
\AtBeginDocument{\renewcommand{\figurename}{图}\renewcommand{\tablename}{表}}
\renewcommand{\maketitle}{%
\begin{titlepage}\thispagestyle{empty}\centering
\vspace*{25mm}
{\small 计算行为科学研究\par}
\vspace{15mm}
{\huge\bfseries 动态随机英文单词打字\par}
\vspace{6mm}
{\Large 视觉—认知—十指运动的耦合建模与仿真\par}
\vspace{15mm}
\rule{0.68\textwidth}{0.4pt}\par
\vspace{7mm}
{\large 数学模型 · 公开证据 · 可复现计算\par}
\vfill
{\large 18,192场计算会话\quad 31张研究图\par}
\vspace{4mm}
{\normalsize 模型实现、数据与执行记录随项目交付\par}
\vspace{14mm}
{\normalsize 2026年10月13日\par}
\vspace*{16mm}
\end{titlepage}}
\let\originaltableofcontents\tableofcontents
\renewcommand{\tableofcontents}{\originaltableofcontents\clearpage}
'''
    (R/'header.tex').write_text(header)
    if args.pdf:
        for exe in ['pandoc','xelatex']:
            if not shutil.which(exe):raise RuntimeError(f'{exe} not installed; Markdown already generated')
        cmd=['pandoc','research_report.md','--from=markdown+tex_math_dollars','--standalone','--toc','--toc-depth=1',
             '--pdf-engine=xelatex','-H','header.tex','-V','documentclass=article','-V','papersize=a4','-V','fontsize=10pt',
             '-V','geometry:top=23mm,bottom=23mm,left=22mm,right=22mm','-V','mainfont=DejaVu Serif',
             '-V','sansfont=DejaVu Sans','-V','monofont=DejaVu Sans Mono','-V','CJKmainfont=Noto Serif CJK SC',
             '-V','linestretch=1.15','-o','research_report.pdf']
        proc=subprocess.run(cmd,cwd=R,capture_output=True,text=True)
        (ROOT/'results/logs/pdf_build.log').write_text(proc.stdout+'\n'+proc.stderr)
        if proc.returncode:raise RuntimeError(proc.stderr[-5000:])
    print('Report source written:',len(text),'characters; PDF:',args.pdf)
if __name__=='__main__':main()
