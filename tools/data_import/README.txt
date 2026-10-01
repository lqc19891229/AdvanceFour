《前进四》数据导入系统

目录职责：
集中管理所有“策划数据 -> Godot 运行数据”的导入内容。

目录结构：
- source/game_data.xlsx
  策划数据唯一真源。模块数据维护在六个 Sheet：
  Energy / Propulsion / Weapon / Defense / Function / Core。

- import_excel.py
  读取 Excel、校验字段、根据 Sheet 判断模块类型，并生成 JSON cache；所有模块基础字段都包含 hp，要求 hp > 0。

- cache/modules.json
  Excel 解析后的中间数据，仅用于导入流程。
  可以删除，重新导入时会再次生成。

使用流程：
1. 修改 source/game_data.xlsx。
2. 在 Godot 顶部菜单执行“前进四：验证模块数据”。
3. 验证通过后执行“前进四：导入模块数据”。
4. 插件读取 cache/modules.json；验证通过后清理 res://data/generated/modules/ 六类目录中的旧 .tres，再生成当前 Excel 对应的 .tres。

规则：
- 不要手动修改 cache/modules.json。
- 不要把运行时 .tres 放在本目录。
- 重新导入时，Excel 中已经删除或改名的模块，其旧 .tres 会自动清理；README.txt 等非 .tres 文件不会被删除。
- 新的数据导入脚本、源表和缓存文件统一放在这里管理。
- hp 属于六类模块共同基础字段；运行时模块最大 HP 直接来自导入后的 definition.hp。

Weapon 专属字段（当前机炮）：
- firepower：每发伤害，5，必须 > 0。
- attack_range：攻击范围 / 弹丸最大距离，500 px，必须 > 0。
- fire_interval：射击间隔，0.5 秒，必须 > 0；射速 = 1 / fire_interval。
- turn_speed_degrees：炮塔转速，180 度/秒，必须 >= 0。
- fire_angle_tolerance_degrees：瞄准容差，6 度，范围 0~180。
- projectile_speed：弹丸速度，700 px/s，必须 > 0。
五个新增字段必填，拒绝非数字、无穷值和 NaN；其他类型 Sheet 不要求武器字段。
弹丸寿命不作为独立字段，继续按攻击范围退场。

自动验证：
- python3 -B tools/data_import/test_import_excel.py 检查缺列、空值、非法值与数值边界。
- python3 tools/verify_project.py --godot /path/to/godot 同时检查源表 / 缓存、生成武器参数与实际炮塔 / 弹丸行为。
