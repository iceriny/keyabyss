# 数据与文献溯源



本次使用的是已核验论文中的汇总表及真实公开词汇计数，不是自行招募的人类实验。没有取得原始逐键日志；没有拟合 ELP 反应时。所有仿真 CSV 均明确位于 results，与外部观测 data/raw/typing_summary_observations.csv 分开。



检索于 2026-10-13 进行，覆盖打字、视觉搜索、追踪/遮挡、拥挤、阅读预视及运动控制。属于有目标的跨领域检索，不宣称穷尽所有论文或完成 PRISMA 系统综述。



检索词组包含：136 million keystrokes typing; How We Type movement strategies; typing expertise random words preview; typing hierarchical error detection; Guided Search 6; pursuit target blanking; saccade main sequence; Bouma crowding; English Lexicon Project; corpus English word frequency.



主数据：en-spelling.txt 直接复制自已安装 TextBlob 0.19.0，保留文件头并记录哈希。该计数表来自混合历史语料，不等于现代口语词频。自写 sentences.txt 是50条实验用连贯句子，不是外部人类试次记录。



容器联网下载失败：网络/DNS受限；浏览器工具能够读取网页及作者PDF。未将未下载的完整Aalto数据列入交付包。download_data.py提供可联网环境的获取方法，默认不下载1.4GB原始日志。



## R01 · Observations on Typing from 136 Million Keystrokes

Dhakal, Vivek; Feit, Anna; Kristensson, Per Ola; Oulasvirta, Antti，2018。 DOI：10.1145/3173574.3174220。

来源：https://userinterfaces.aalto.fi/136Mkeystrokes/

核验范围：Full author PDF read; Table 3 visually checked on PDF page 5; Table 2 categories checked. Raw 1.4 GB archive not downloaded.

本项目用途：Empirical category-mean IKI constraints and key-hold inputs; WPM summaries constrain a separate whole-task boundary residual; error summaries are descriptive only.



## R02 · How We Type: Movement Strategies and Performance in Everyday Typing

Feit, Anna; Weir, Daryl; Oulasvirta, Antti，2016。 DOI：未在本项目中核实/不适用。

来源：https://userinterfaces.aalto.fi/how-we-type/

核验范围：Official research page/abstract checked.

本项目用途：Motivates explicit preparation, mapping consistency and overlapping finger actions; no numerical parameters fitted.



## R03 · Typing expertise in a large student population

Pinet, Stéphanie et al.，2022。 DOI：10.1186/s41235-022-00424-3。

来源：https://link.springer.com/article/10.1186/s41235-022-00424-3

核验范围：Publisher full text examined; 1301 students; French/AZERTY context.

本项目用途：Continuous expertise and paradigm dependence; not quantitative independent validation of English/QWERTY predictions.



## R04 · Automatic control: How experts act without thinking

Logan, Gordon D.，2018。 DOI：10.1037/rev0000100。

来源：https://pubmed.ncbi.nlm.nih.gov/29952620/

核验范围：Primary bibliographic record/abstract checked.

本项目用途：Hierarchical control motivation, not calibration of recognition or attention constants.



## R05 · Cognitive illusions of authorship reveal hierarchical error detection in skilled typists

Logan, Gordon D.; Crump, Matthew J. C.，2010。 DOI：未在本项目中核实/不适用。

来源：https://pubmed.ncbi.nlm.nih.gov/21030660/

核验范围：Primary abstract checked.

本项目用途：Distinguishes motor/feedback error monitoring; our detection probability and latency remain priors.



## R06 · Guided Search 6.0: An updated model of visual search

Wolfe, Jeremy M.，2021。 DOI：10.3758/s13423-020-01859-9。

来源：https://link.springer.com/article/10.3758/s13423-020-01859-9

核验范围：Publisher/primary record consulted.

本项目用途：Mechanistic context for salience-weighted attention and serial selections; simplified implementation is not Guided Search 6 itself.



## R07 · Interaction effects in parafoveal letter recognition

Bouma, Herman，1970。 DOI：10.1038/226177a0。

来源：https://pubmed.ncbi.nlm.nih.gov/5437004/

核验范围：Primary record checked.

本项目用途：Eccentricity-linked interference motivates spatial kernel; 0.45 coefficient is an explicit word-task prior, not a universal empirical constant.



## R08 · The saccade main sequence revised: A fast and repeatable tool for oculomotor analysis

Gibaldi, Agostino; Sabatini, Silvio P.，2021。 DOI：10.3758/s13428-020-01388-2。

来源：https://pmc.ncbi.nlm.nih.gov/articles/PMC7880984/

核验范围：Primary full-text page consulted.

本项目用途：Amplitude-dependent saccade dynamics; numerical linear-duration coefficients here are priors.



## R09 · Smooth pursuit performance during target blanking does not influence the triggering of predictive saccades

de Xivry, Jean-Jacques Orban et al.，2009。 DOI：未在本项目中核实/不适用。

来源：https://jov.arvojournals.org/article.aspx?articleid=2203981

核验范围：Primary journal abstract and author-hosted record checked.

本项目用途：Predictive tracking and catch-up distinctions under blanking; not direct typing-task evidence.



## R10 · Cortical mechanisms of smooth pursuit eye movements with target blanking. An fMRI study.

Lencer, Rebekka et al.，2004。 DOI：10.1111/j.1460-9568.2004.03229.x。

来源：https://pubmed.ncbi.nlm.nih.gov/15016102/

核验范围：Primary journal bibliographic record consulted.

本项目用途：Motivates continued prediction during blanking; no numerical calibration.



## R11 · Manual tracking enhances smooth pursuit eye movements

Niehorster, Diederick C. et al.，2015。 DOI：未在本项目中核实/不适用。

来源：https://jov.arvojournals.org/article.aspx?articleid=2474042

核验范围：Primary journal abstract checked.

本项目用途：Eye-hand task interactions; moving a hand-held tracker is not a typing experiment.



## R12 · Eye movements, the perceptual span, and reading speed

Rayner, Keith et al.，2010。 DOI：10.3758/PBR.17.6.834。

来源：https://pmc.ncbi.nlm.nih.gov/articles/PMC3075059/

核验范围：Primary study consulted.

本项目用途：Preview/perceptual span motivation; reading ability is not assumed to equal typing expertise.



## R13 · The information capacity of the human motor system in controlling the amplitude of movement

Fitts, Paul M.，1954。 DOI：10.1037/h0055392。

来源：https://doi.org/10.1037/h0055392

核验范围：Original research identified; source task is aimed movement, not general typing.

本项目用途：Geometry-related lower constraint only, not an additive universal IKI law.



## R14 · A note on the information-theoretic basis for Fitts’ law

MacKenzie, I. Scott，1989。 DOI：10.1080/00222895.1989.10735486。

来源：https://www.yorku.ca/mack/JMB89.html

核验范围：Full author-hosted text examined.

本项目用途：Source of Shannon-form log2(1+D/W); its use for finger travel here remains a model assumption.



## R15 · TextBlob 0.19.0 packaged English spelling count lexicon

TextBlob contributors; Norvig, Peter，n.d.。 DOI：未在本项目中核实/不适用。

来源：https://raw.githubusercontent.com/sloria/TextBlob/dev/src/textblob/en/en-spelling.txt

核验范围：Local installed version copied, original header retained, SHA-256 recorded; upstream text checked online. Version year not a new study date.

本项目用途：Actual count lexicon, within-word n-gram frequencies and dictionary-neighbor preprocessing.



## R16 · How to Write a Spelling Corrector

Norvig, Peter，2007。 DOI：未在本项目中核实/不适用。

来源：https://www.norvig.com/spell-correct.html

核验范围：Author page checked.

本项目用途：Corpus provenance context; not a contemporary representative language frequency norm.



## R17 · The English Lexicon Project

Balota, David A. et al.，2007。 DOI：10.3758/BF03193014。

来源：https://elexicon.wustl.edu/

核验范围：Official project and dataset description located; trial-level data not downloaded.

本项目用途：Future lexical calibration candidate only; no ELP reaction times were used or fitted.

