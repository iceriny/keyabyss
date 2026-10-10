import type { BookId } from '../../contracts/content-ids.ts';

export interface BuildConcept {
  readonly id: string;
  readonly aliases: readonly string[];
  readonly books: Readonly<Record<BookId, number>>;
}
const concept = (id: string, aliases: readonly string[], flame: number, storm: number, frost: number, spirit: number): BuildConcept =>
  Object.freeze({ id, aliases: Object.freeze([...aliases]), books: Object.freeze({ flame, storm, frost, spirit }) });

/** Design metadata for search/layout; these concepts grant no combat resources or permissions. */
export const BUILD_CONCEPT_VERSION = 1;
export const BUILD_CONCEPTS: readonly BuildConcept[] = Object.freeze([
  concept('base', ['主术', '命中', '数值', '全图基础连接', '目标'], .25, .25, .25, .25),
  concept('cold', ['寒气'], 0, 0, .85, .15),
  concept('heat', ['热性', '受热', '热加工'], .70, .10, .20, 0),
  concept('structure', ['结构', '碎裂'], .20, .10, .60, .10),
  concept('storage', ['保存', '空间', '时间'], .10, .10, .40, .40),
  concept('recovery', ['回收', '储备', '跨房'], .40, .15, .20, .25),
  concept('routing', ['电性', '路径', '距离', '转交'], .10, .60, .15, .15),
  concept('replication', ['复制', '继承'], .05, .15, .25, .55),
  concept('shaping', ['分配', '集中', '形状', '聚合'], .15, .30, .35, .20),
  concept('literacy', ['词形', '输入', '准确', '辅助', '延续', '节律'], .15, .20, .10, .55),
  concept('protection', ['防御', '弹反', '生命'], .15, .25, .25, .35),
  concept('risk', ['风险'], .50, .10, .10, .30),
  concept('transport', ['运输', '纸灵'], .05, .20, .10, .65),
  concept('field', ['区域', '位置', '移动'], .25, .30, .25, .20),
  concept('supply', ['供给', '材料', '加工', '转换'], .25, .25, .25, .25),
  concept('study', ['专精', '兼修', '终式', '共鸣', '成长', '机会'], .25, .25, .25, .25),
  concept('duration', ['持续', '持续伤害'], .70, .10, .15, .05),
  concept('release', ['释放'], .40, .10, .20, .30),
]);
