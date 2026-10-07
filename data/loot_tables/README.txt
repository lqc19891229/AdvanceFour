data/loot_tables

职责：
- 保存战斗模块掉落表 Resource。
- BattleDefinition 通过 loot_table 引用具体掉落表。

v0.41 规则：
- LootTableDefinition.drop_count：本场生成的模块战利品件数。
- LootTableDefinition.allow_duplicates：是否允许同一模块重复抽中。
- LootTableEntry.module_id：候选模块。
- LootTableEntry.weight：相对掉落权重，必须大于 0。
- LootTableEntry.min_count / max_count：单次抽中数量范围。

当前：
- stage_001_loot.tres：抽 3 件，不重复。
- stage_002_loot.tres：抽 3 件，不重复。
- 实际战斗使用随机种子；自动回归可传固定 seed 验证可复现结果。

边界：
- weight 只表示掉落概率权重，不代表模块品质。
- 当前不设计稀有度、随机词条或模块实例品质。
- 暂未实现按敌舰独立掉落、幸运值、保底、精英/Boss 专属池。
