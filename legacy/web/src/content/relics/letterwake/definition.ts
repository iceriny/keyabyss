import type { Relic } from '../../../contracts/content.ts';
export default {
  id: 'letterwake', name: '散字余音', icon: 'letterwake', command: 'letterwake',
  max: 1, rarity: 'rare', tag: '字符 · 续写', grants: { letterScatter: 1 },
  desc: '正在输入的目标被友方击杀时，已输入字母飞向其他词条并点亮同字母。亲手输入每个亮字母，使该次主术伤害增加15%。残响仍可续写。',
} satisfies Relic;
