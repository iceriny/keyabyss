"""One-time candidate import. Generated .tres files become the native content source.

The importer deliberately marks unwired candidates as unsupported. Registration
alone is not evidence of a combat implementation. Run only when changing the
catalog mapping, then review Resource diffs and run the native coverage checks.
"""
from pathlib import Path
import re
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game/content/build"
Q = 1024
MANIFEST = []
FAMILIES = {
    "保存与结构": ("vault copy inherit base-copy copy-split copy-concentrate guard echo oldest newest closest-guard guard-spacing joint-guard merge short-storage stagger-release reserved-slot reseal continuation-slot thin-shell fracture late-shape", "assemble / _store / _close_shell / guard", "同一制作账户、保存空间、原剩余份额和一次出口", "test_m3_mechanisms.gd: storage, copy, ordinary_page, late_page"),
    "热加工": ("heat heat-open heat-hold heat-fracture insulate anneal heat-transfer", "_heat_contact", "真实热量；根来源与外壳配对一次领取", "test_m3_mechanisms.gd: thermal"),
    "持续与区域": ("dot heat-field cold-field field-relay field-recover field-split dot-transfer dot-shell advance-dot delay-dot dot-selective-recover", "contact / _start_ongoing / advance / _death", "未来份额、剩余作用次数；延后另付寒气", "test_m3_mechanisms.gd: status, thermal, frozen_recovery"),
    "储备与回收": ("reserve meter archive extract dot-recover charge-recover shell-recover miss-recover charge-priority burst-reserve clear-heal", "_recover / _apply_reserve / finish", "加权共享容量、回收损耗、每词投入上限与跨房损耗", "test_m3_mechanisms.gd: reserve, short_reserve, frozen_recovery"),
    "电性路径": ("conduct relay long-hop near-hop delayed-chain charge-mark charge-clear cargo-relay", "contact / _continue_arc / _arc_route", "伤害、电荷和落点次数分别消费；真实位置可达", "test_m3_mechanisms.gd: cross_book, long_chain"),
    "纸灵与运输": ("summon transport return return-target spirit-guard", "_fund_spirit / pickup / deliver / return_cargo", "共同制作收入、有限攻击队列；运输消耗一次攻击", "test_m3_mechanisms.gd: transport, spirit_guard"),
    "输入与词形": ("letters mark-store mark-spread letter-heavy letter-fixed letter-inherit continuation perfect assist input-slow local-slow rhythm long-word short-word", "observe_input / _distribute_letters / assemble / consume_assist", "人工位置和词会话版本、已赚机会、真实前缀收入", "test_m3_mechanisms.gd: scatter, continuation, assist; test_input_settings.gd"),
    "命中与形状": ("cold pierce concentrate split durable near blind new-target last-segment secondary focus secondary-target shared-work two-materials mastery fast-flight brittle execute pull push splash refract", "assemble / _configure_shape / contact / _apply_paid_modifiers", "原伤害或材料份额；不复制人工收入", "test_m3_core.gd; test_m3_mechanisms.gd: focused shapes, copy, calibration"),
    "防御与生命": ("parry counter-store graze graze-shield trail dodge-clear dodge-pull dodge-window input-clear perfect-clear input-shield perfect-shield empowered-shield ultimate-shield heal acquisition-heal revive armor glass low-health low-health-guard room-price work-convert", "counter / graze / on_dodge / assemble; BattleSession._apply_acquisition", "敌方攻击回执、储备或制作费用、稳定资产使用回执", "test_battle_session.gd; test_m3_mechanisms.gd: assets, dash_asset, followup"),
}
KEY_FAMILY = {"K01":"保存与结构", "K02":"命中与形状", "K03":"命中与形状", "K04":"热加工", "K05":"热加工", "K06":"储备与回收", "K07":"储备与回收", "K08":"电性路径", "K09":"电性路径", "K10":"保存与结构", "K11":"保存与结构", "K12":"纸灵与运输", "K13":"纸灵与运输", "K14":"输入与词形", "K15":"输入与词形", "K16":"防御与生命", "K17":"防御与生命", "K18":"储备与回收", "K19":"命中与形状", "K20":"命中与形状"}

# Named pools, integers in Q except slots, counts and milliseconds.
NUMBERS = [
    ("power_bonus_q", 26), ("cold_efficiency_q", 41), ("dot_retention_q", 41),
    ("charge_efficiency_q", 31), ("copy_retention_q", 31), ("storage_slots", 1),
    ("storage_lifetime_ms", 400), ("storage_wait_ms", -100), ("manufacture_discount_q", 31),
    ("split_retention_q", 31), ("hop_range_q", 51), ("chain_retention_q", 31),
    ("pierce_retention_q", 31), ("reserve_capacity_q", 51), ("recovery_q", 20),
    ("transport_retention_q", 31), ("merge_wait_ms", -100), ("heat_efficiency_q", 41),
    ("shell_durability_q", 31), ("guard_efficiency_q", 31), ("max_hp_bonus_q", 31),
    ("heal_efficiency_q", 31), ("perfect_bonus_q", 31), ("letter_retention_q", 31),
    ("field_radius_q", 41), ("field_lifetime_ms", 300), ("dodge_recovery_q", 31),
    ("parry_efficiency_q", 41), ("resonance_bonus_q", 31), ("shared_discount_q", 20),
]

# Rule entry points are source independent. Additive pool entries remain distinct.
TALENT_VALUES = {
    "T01": {"storage_retention_q": 102}, "T13": {"charge_efficiency_q": 102},
    "T19": {"copy_retention_q": 102}, "T49": {"dot_retention_q": 102},
    "T50": {"cold_efficiency_q": 102}, "T52": {"summon_efficiency_q": 102},
    "T04": {"storage_lifetime_ms": 3000, "storage_wait_ms": 1000, "heat_absorption_q": -256},
    "T06": {"manufacture_discount_q": 102, "shell_durability_q": -205},
    "T15": {"hop_range_q": 256, "chain_targets": -1},
    "T16": {"hop_range_q": -205, "chain_targets": 2},
    "T23": {"guard_efficiency_q": 102}, "T24": {"guard_efficiency_q": 102},
    "T46": {"field_radius_q": 102}, "T54": {"storage_slots": -1, "armor_q": 154},
    "T57": {"secondary_retention_q": 102},
}
KEY_VALUES = {
    "K01": {"storage_slots":4,"storage_wait_ms":1500,"storage_lifetime_ms":8000},
    "K02": {"split_targets":3}, "K03": {"chain_targets":-1}, "K04":{"storage_wait_ms":1000},
    "K05":{"storage_lifetime_ms":-1500},"K06":{"reserve_capacity_q":256},"K07":{},
    "K08":{"chain_targets":-1},"K09":{"chain_targets":2,"hop_range_q":-154},
    "K10":{"storage_wait_ms":1000},"K11":{"manufacture_discount_q":205},
    "K12":{"merge_count":2},"K13":{"transport_retention_q":102},"K14":{},"K15":{},"K16":{},
    "K17":{"max_hp_bonus_q":-256,"guard_efficiency_q":256},"K18":{},"K19":{},"K20":{},
}

# Explicit initial tunings. No effect is inferred from prose during combat.
RELICS = {
    1: ("", {"power_bonus_q": 102}), 2: ("conduct", {}), 3: ("cold", {"cold_efficiency_q":154}),
    4:("death-fracture",{}),5:("summon",{"summon_efficiency_q":102}),6:("copy",{}),
    7:("splash",{}),8:("parry",{"parry_efficiency_q":154,"parry_followup_q":102}),9:("",{"dodge_capacity":1}),
    10:("dodge-clear",{}),11:("continuation",{}),12:("acquisition-heal",{"max_hp_bonus_q":102}),
    13:("heal",{}),14:("short-word",{}),15:("long-word",{"long_clear_q":102}),16:("perfect",{"perfect_bonus_q":102}),
    17:("assist",{}),18:("input-slow",{}),19:("",{"armor_q":102}),20:("input-clear",{}),
    21:("progression-policy",{"experience_cap_q":256}),22:("rhythm",{}),23:("",{"hop_range_q":102,"field_radius_q":102}),
    24:("revive",{}),25:("push",{}),26:("pull",{}),27:("execute",{}),28:("dot",{"dot_retention_q":31}),
    29:("perfect-clear",{}),30:("rhythm",{"power_bonus_q":51}),31:("brittle",{}),32:("cold-field",{}),
    33:("",{"chain_retention_q":102}),34:("charge-clear",{}),35:("summon",{"summon_efficiency_q":102}),
    36:("low-health",{}),37:("dodge-pull",{}),38:("graze",{}),39:("input-shield",{}),
    40:("",{"resonance_bonus_q":102}),41:("dodge-window",{}),42:("room-price",{"power_bonus_q":154}),
    43:("glass",{"power_bonus_q":205,"incoming_bonus_q":205}),44:("avalanche",{"split_targets":2}),
    45:("ultimate-shield",{"ultimate_power_q":102}),46:("conduct",{"chain_targets":1}),
    47:("",{"ultimate_duration_ms":2000}),48:("summon",{"summon_capacity":1}),49:("spirit-guard",{}),
    50:("",{"dot_retention_q":31}),51:("",{"dot_duration_ms":1000,"dot_pulses":2}),52:("dot-transfer",{}),
    53:("",{"field_radius_q":102}),54:("empowered-shield",{}),55:("trail",{}),56:("",{"ultimate_pulses":2}),
    57:("parry",{}),58:("",{"parry_cooldown_ms":-70}),66:("heat",{}),
    69:("vault",{}),70:("copy",{}),71:("",{"storage_slots":1,"storage_lifetime_ms":1000,"storage_wait_ms":200}),
    72:("copy-split",{}),73:("copy-concentrate",{}),74:("inherit",{"copy_retention_q":51}),
    75:("short-storage",{"manufacture_discount_q":102}),76:("stagger-release",{}),
    77:("merge",{"merge_count":2,"merge_wait_ms":100}),78:("",{"storage_slots":-1,"storage_retention_q":102}),
    79:("transport",{}),80:("return",{"transport_retention_q":102,"return_wait_ms":200}),81:("pierce",{}),
    82:("base-copy",{"manufacture_discount_q":154}),83:("",{"guard_efficiency_q":205,"copy_retention_q":-102}),
    84:("inherit",{"copy_retention_q":102,"manufacture_discount_q":-102}),
    85:("",{"recovery_q":102,"reserve_capacity_q":-205}),86:("",{"reserve_capacity_q":256,"reserve_cast_cap_q":4*Q,"recovery_q":-51}),
    87:("reserve",{}),88:("meter",{}),89:("burst-reserve",{"burst_ratio_q":154,"burst_cap_q":16*Q,"reserve_cooldown_words":1}),
    90:("dot-recover",{}),91:("extract",{"extract_ratio_q":154}),92:("shell-recover",{}),93:("charge-recover",{}),
    94:("miss-recover",{"recovery_q":51}),95:("archive",{"archive_retention_q":102}),96:("clear-heal",{}),
    97:("heat-hold",{"storage_wait_ms":200}),98:("thin-shell",{"shell_durability_q":-205,"split_targets":1}),
    99:("heat-hold",{}),100:("heat-open",{"heat_threshold_q":-256,"storage_lifetime_ms":-1000}),
    101:("heat-fracture",{}),102:("insulate",{"heat_absorption_q":-256,"storage_lifetime_ms":3000}),
    103:("anneal",{}),104:("heat-transfer",{}),105:("",{"split_retention_q":102}),106:("concentrate",{}),
    107:("split",{}),108:("merge",{}),109:("new-target",{}),110:("conduct",{}),111:("relay",{}),
    112:("long-hop",{"hop_range_q":256,"chain_targets":-1}),113:("near-hop",{"hop_range_q":-205,"chain_targets":2}),
    114:("",{"charge_efficiency_q":102}),115:("guard-spacing",{}),116:("charge-priority",{}),117:("delayed-chain",{}),
    118:("concentrate",{"chain_targets":-1}),119:("cargo-relay",{}),120:("field-relay",{"relay_range_q":205}),
    121:("near",{}),122:("durable",{}),123:("new-target",{}),124:("letters",{}),125:("mark-store",{"letter_store_q":256}),
    126:("mark-spread",{"letter_positions":2}),127:("letter-heavy",{"letter_positions":-3}),128:("long-word",{}),
    129:("short-word",{}),130:("perfect",{"perfect_bonus_q":102}),131:("assist",{"assist_cost_q":-2*Q}),
    132:("last-segment",{}),133:("continuation",{}),134:("letter-inherit",{"letter_retention_q":-102}),
    135:("letter-fixed",{}),136:("input-slow",{}),137:("perfect-shield",{}),138:("guard",{}),
    139:("",{"guard_efficiency_q":102}),140:("echo",{}),141:("oldest",{"guard_efficiency_q":102}),142:("newest",{}),
    143:("armor",{"storage_slots":-1,"armor_q":154}),144:("low-health-guard",{}),145:("parry",{"parry_efficiency_q":102}),
    146:("counter-store",{"counter_capacity":1}),147:("graze-shield",{}),148:("trail",{}),149:("",{"dodge_recovery_q":102}),
    150:("pull",{}),151:("push",{}),152:("cold-field",{}),153:("heat-field",{}),154:("",{"field_lifetime_ms":1500}),
    155:("field-recover",{"recovery_q":51}),156:("clear-heal",{}),157:("low-health",{"max_hp_bonus_q":-154,"power_bonus_q":154}),
    158:("",{"secondary_weight_q":256}),159:("shared-work",{"shared_discount_q":51}),160:("",{"shape_retention_q":102}),
    161:("mastery",{}),162:("blind",{}),163:("reserved-slot",{}),164:("reseal",{}),165:("advance-dot",{}),
    166:("delay-dot",{}),167:("two-materials",{}),168:("late-shape",{"storage_wait_ms":300}),169:("dot-shell",{}),
    170:("closest-guard",{}),171:("work-convert",{}),172:("refract",{}),173:("dot-selective-recover",{}),
    174:("fast-flight",{"flight_speed_q":256,"field_lifetime_ms":-500}),175:("return-target",{}),176:("joint-guard",{}),
    177:("heat-hold",{"heat_capacity_q":512,"shell_space":1}),178:("field-split",{}),179:("continuation-slot",{}),180:("secondary-target",{}),
}

# Expanded as mechanisms gain actual entry points and tests. Unsupported remains visible.
IMPLEMENTED = {
    "cold", "conduct", "dot", "summon", "refract", "stats", "vault", "copy", "heal",
    "guard", "echo", "oldest", "newest", "guard-spacing", "merge", "durable", "near",
    "heat-field", "cold-field", "field-recover", "dot-recover", "extract", "reserve", "meter",
    "archive", "miss-recover", "charge-recover", "shell-recover", "heat", "heat-open", "heat-hold",
    "heat-fracture", "insulate", "thin-shell", "short-storage", "long-hop", "near-hop", "delayed-chain",
    "perfect", "assist", "low-health", "clear-heal", "parry", "acquisition-heal", "revive", "glass",
    "room-price", "advance-dot", "delay-dot", "dot-transfer", "work-convert", "pull", "push",
    "split", "blind", "closest-guard", "joint-guard", "charge-priority", "mastery", "reseal", "last-segment",
    "pierce", "concentrate", "fracture", "death-fracture", "avalanche", "splash", "secondary", "focus", "armor", "letters", "mark-store", "mark-spread",
    "continuation", "graze", "graze-shield", "trail", "dodge-clear", "dodge-window", "dodge-pull", "input-shield",
    "perfect-shield", "empowered-shield", "rhythm", "transport", "return", "relay", "field-relay", "cargo-relay", "shared-work",
    "input-clear", "input-slow", "local-slow", "perfect-clear", "execute", "brittle", "ultimate-shield", "spirit-guard",
    "copy-split", "copy-concentrate", "inherit", "base-copy", "stagger-release", "burst-reserve", "anneal", "heat-transfer",
    "new-target", "letter-fixed", "low-health-guard", "field-split", "dot-shell", "late-shape", "fast-flight",
    "long-word", "short-word", "charge-mark", "counter-store",
    "charge-clear", "letter-heavy", "letter-inherit", "reserved-slot", "two-materials", "dot-selective-recover", "return-target", "continuation-slot", "secondary-target", "progression-policy",
}
IMPLEMENTED.update({f"K{index:02d}" for index in range(1, 21)})
IMPLEMENTED_PARAMETERS = {
    "power_bonus_q", "cold_efficiency_q", "resonance_bonus_q", "dot_retention_q", "copy_retention_q",
    "storage_slots", "storage_lifetime_ms", "storage_wait_ms", "manufacture_discount_q", "chain_targets",
    "hop_range_q", "reserve_capacity_q", "reserve_cast_cap_q", "recovery_q", "merge_wait_ms",
    "heat_absorption_q", "guard_efficiency_q", "max_hp_bonus_q", "heal_efficiency_q", "perfect_bonus_q",
    "field_radius_q", "field_lifetime_ms", "dodge_recovery_q", "dodge_capacity", "incoming_bonus_q",
    "parry_efficiency_q", "parry_cooldown_ms", "assist_cost_q", "dot_duration_ms", "dot_pulses",
    "ultimate_duration_ms", "ultimate_pulses", "summon_capacity", "extract_ratio_q", "archive_retention_q",
    "burst_ratio_q", "burst_cap_q", "reserve_cooldown_words", "ultimate_power_q", "armor_q", "charge_efficiency_q",
    "heat_efficiency_q", "shared_discount_q", "split_targets", "secondary_retention_q", "relay_range_q", "return_wait_ms",
    "counter_capacity", "letter_store_q", "letter_positions", "summon_efficiency_q",
    "storage_retention_q", "split_retention_q", "chain_retention_q", "pierce_retention_q", "transport_retention_q",
    "shell_durability_q", "shape_retention_q", "heat_capacity_q", "shell_space",
    "merge_count", "letter_retention_q", "heat_threshold_q", "secondary_weight_q", "flight_speed_q", "experience_cap_q", "parry_followup_q", "long_clear_q",
}

def quoted(value):
    return json.dumps(value, ensure_ascii=False)

def array(items):
    return "PackedStringArray(" + ", ".join(quoted(x) for x in items) + ")"

def save(id_, title, description, kind, operation="", values=None, **extra):
    values = values or {}
    supported = (not operation or operation in IMPLEMENTED) and all(k in IMPLEMENTED_PARAMETERS for k in values)
    stage = extra.pop("stage", "M3")
    family = KEY_FAMILY.get(operation, next((name for name, contract in FAMILIES.items() if operation in contract[0].split()), "数值池" if not operation else "跨阶段政策"))
    contract = FAMILIES.get(family, ("", "BuildCompiler._install / BattleSession / SpellRuntime" if family == "数值池" else "RoomCombatResult.progression_requests", "声明的加法池；在合法入口使用" if family == "数值池" else "M4 的章级经验和奖励机会政策", "test_m3_catalog.gd: all definitions; mechanism-family tests"))
    MANIFEST.append({"id":id_, "title":title, "disposition":"retained", "stage":stage, "resource":f"game/content/build/{id_}.tres", "operation":operation or "stats", "parameters":values, "conditions_and_tradeoff":description, "requirements":extra.copy(), "family":family, "native_entry":contract[1], "cost_and_ownership":contract[2], "verification_cases":contract[3], "verification_scope":"per-ID compiler/lifecycle smoke plus family semantics; acquisition and balance are separate"})
    cls = {"book":"BookDefinition", "talent":"TalentDefinition", "relic":"RelicDefinition"}[kind]
    filename = {"book":"book_definition", "talent":"talent_definition", "relic":"relic_definition"}[kind]
    rules = bool(operation or values)
    lines = [f'[gd_resource type="Resource" script_class="{cls}" load_steps={4 if rules else 2} format=3]', "",
             f'[ext_resource type="Script" path="res://game/content/{filename}.gd" id="1"]']
    if rules:
        lines += ['[ext_resource type="Script" path="res://game/content/rule_definition.gd" id="2"]', '',
                  '[sub_resource type="Resource" id="Rule"]', 'script = ExtResource("2")',
                  f'id = &{quoted(id_ + ":rule")}', f'operation = &{quoted(operation or "stats")}',
                  'phase = &"compile"', 'parameters = {']
        lines += [f'&{quoted(k)}: {v},' for k,v in values.items()]
        lines += ['}']
    lines += ['', '[resource]', 'script = ExtResource("1")', f'id = &{quoted(id_)}',
              f'title = {quoted(title)}', f'description = {quoted(description)}',
              f'stage = &{quoted(stage)}', f'supported = {str(supported).lower()}']
    if not supported:
        lines.append('unsupported_reason = "规则入口或参数尚未接入原生运行时。"')
    if rules:
        lines.append('rules = Array[ExtResource("2")]([SubResource("Rule")])')
    for k,v in extra.items():
        if isinstance(v, list): v = array(v)
        elif isinstance(v, str): v = "&" + quoted(v) if k in {"mode_slot","primary_kind","replaces"} else quoted(v)
        elif isinstance(v, bool): v = str(v).lower()
        lines.append(f'{k} = {v}')
    (OUT / (id_ + ".tres")).write_text("\n".join(lines)+"\n", encoding="utf-8")

def rows(path):
    for line in path.read_text(encoding="utf-8").splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and re.fullmatch(r"[TKN]\d\d|R\d\d\d", cells[0]):
            yield cells

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (id_, title, op, kind, cadence) in enumerate([
        ("frost","寒墨","cold","frost_spear",4), ("flame","灰烬","dot","flame_burst",3),
        ("storm","雷鸣","conduct","storm_arc",4), ("spirit","纸灵","summon","spirit_mark",3),
    ]):
        save(id_,title,"主书提供主术、基础材料及唯一终式。","book",op,element=index+1, primary_kind=kind,cadence=cadence)
    path = ROOT / "docs/build-system-design/appendix-talent-candidates.md"
    for cells in rows(path):
        id_, title = cells[:2]
        if id_.startswith("N"):
            parameter, amount = NUMBERS[int(id_[1:])-1]
            for instance in re.findall(r"N\d\d-\d\d", cells[4]):
                save(instance,title,cells[2],"talent",values={parameter:amount},point_cost=1)
        elif id_.startswith("T"):
            extra = {"mode_slot":"guard-order"} if id_ in {"T23","T24"} else {}
            save(id_,title,"；".join(cells[3:6]),"talent",cells[6],TALENT_VALUES.get(id_,{}),**extra)
        else:
            prerequisites = re.findall(r"[TK]\d\d", cells[4])
            extra = {"requires_any" if "或" in cells[4] else "requires_all": prerequisites}
            save(id_,title,cells[3]+"；"+cells[5],"talent",id_,KEY_VALUES[id_],point_cost=4,mode_slot=cells[6],**extra)
    for cells in rows(ROOT / "docs/build-system-design/appendix-relic-candidates.md"):
        id_, title = cells[:2]
        index = int(id_[1:])
        operation, values = RELICS[index]
        permits = re.findall(r"[TK]\d\d", cells[4] if len(cells)==5 else cells[4])
        extra = {"permits": permits}
        legacy_id = re.search(r"`([^`]+)`", cells[1])
        if legacy_id and values:
            legacy_definition = ROOT / "legacy/web/src/content/relics" / legacy_id[1] / "definition.ts"
            if legacy_definition.exists():
                maximum = re.search(r"\bmax:\s*(\d+)", legacy_definition.read_text(encoding="utf-8"))
                if maximum: extra["max_stacks"] = int(maximum[1])
        if index in {44,45}: extra["allowed_books"]=["frost"]
        if index in {46,47}: extra["allowed_books"]=["storm"]
        if index in {48,49}: extra["allowed_books"]=["spirit"]
        if index==56: extra["allowed_books"]=["flame"]
        if index in {84,135}: extra["replaces"] = f'R{74 if index==84 else 125:03d}'
        if index in {141,142,170}: extra["mode_slot"]="guard-order"
        if index in {21}: extra["stage"]="M4"
        title = title.split("（")[0]
        save(id_,title,"；".join(cells[3:]),"relic",operation,values,**extra)
    print(f"Generated {len(list(OUT.glob('*.tres')))} native definitions.")
    manifest_path = ROOT / "docs/migration/M3-CONTENT-MAP.json"
    manifest_path.write_text(json.dumps({"parameter_version":"m3.2", "definitions":len(MANIFEST), "content":MANIFEST}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")

if __name__ == "__main__":
    main()
