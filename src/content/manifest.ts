import relics_rebound from "./relics/rebound/definition.ts";
import relics_inscription from "./relics/inscription/definition.ts";
import { assets } from "./assets.ts";
import books_flame from "./books/flame/definition.ts";
import relics_cinder from "./relics/cinder/definition.ts";
import relics_pitch from "./relics/pitch/definition.ts";
import relics_wildfire from "./relics/wildfire/definition.ts";
import relics_crucible from "./relics/crucible/definition.ts";
import relics_coal from "./relics/coal/definition.ts";
import relics_firewalk from "./relics/firewalk/definition.ts";
import relics_inferno from "./relics/inferno/definition.ts";
import { audio } from "./audio.ts";
import { appearances } from "./appearances.ts";
import boss0 from "./bosses/ink-colossus/definition.ts";
import boss1 from "./bosses/echo-archivist/definition.ts";
import boss2 from "./bosses/final-editor/definition.ts";
// Explicit order preserves existing menu order and seeded reward selection.
import books_frost from "./books/frost/definition.ts";
import books_storm from "./books/storm/definition.ts";
import books_spirit from "./books/spirit/definition.ts";
import enemies_nib from "./enemies/nib/definition.ts";
import enemies_quill from "./enemies/quill/definition.ts";
import enemies_guard from "./enemies/guard/definition.ts";
import enemies_split from "./enemies/split/definition.ts";
import enemies_wisp from "./enemies/wisp/definition.ts";
import enemies_scribe from "./enemies/scribe/definition.ts";
import enemies_leech from "./enemies/leech/definition.ts";
import enemies_sentinel from "./enemies/sentinel/definition.ts";
import enemies_tower from "./enemies/tower/definition.ts";
import enemies_ram from "./enemies/ram/definition.ts";
import enemies_mortar from "./enemies/mortar/definition.ts";
import enemies_priest from "./enemies/priest/definition.ts";
import enemies_binder from "./enemies/binder/definition.ts";
import enemies_mirror from "./enemies/mirror/definition.ts";
import enemies_brood from "./enemies/brood/definition.ts";
import enemies_reaper from "./enemies/reaper/definition.ts";
import enemies_vortex from "./enemies/vortex/definition.ts";
import elites_swift from "./elites/swift.ts";
import elites_iron from "./elites/iron.ts";
import elites_echo from "./elites/echo.ts";
import elites_volatile from "./elites/volatile.ts";
import relics_power from "./relics/power/definition.ts";
import relics_chain from "./relics/chain/definition.ts";
import relics_frost from "./relics/frost/definition.ts";
import relics_shatter from "./relics/shatter/definition.ts";
import relics_spirit from "./relics/spirit/definition.ts";
import relics_echo from "./relics/echo/definition.ts";
import relics_blast from "./relics/blast/definition.ts";
import relics_reflect from "./relics/reflect/definition.ts";
import relics_dash from "./relics/dash/definition.ts";
import relics_dashnova from "./relics/dashnova/definition.ts";
import relics_shield from "./relics/shield/definition.ts";
import relics_heal from "./relics/heal/definition.ts";
import relics_leech from "./relics/leech/definition.ts";
import relics_short from "./relics/short/definition.ts";
import relics_long from "./relics/long/definition.ts";
import relics_perfect from "./relics/perfect/definition.ts";
import relics_feather from "./relics/feather/definition.ts";
import relics_slow from "./relics/slow/definition.ts";
import relics_armor from "./relics/armor/definition.ts";
import relics_pulse from "./relics/pulse/definition.ts";
import relics_gold from "./relics/gold/definition.ts";
import relics_crit from "./relics/crit/definition.ts";
import relics_reach from "./relics/reach/definition.ts";
import relics_rescue from "./relics/rescue/definition.ts";
import relics_heavy from "./relics/heavy/definition.ts";
import relics_gravity from "./relics/gravity/definition.ts";
import relics_execute from "./relics/execute/definition.ts";
import relics_bleed from "./relics/bleed/definition.ts";
import relics_nova from "./relics/nova/definition.ts";
import relics_rhythm from "./relics/rhythm/definition.ts";
import relics_brittle from "./relics/brittle/definition.ts";
import relics_permafrost from "./relics/permafrost/definition.ts";
import relics_conductor from "./relics/conductor/definition.ts";
import relics_stormcell from "./relics/stormcell/definition.ts";
import relics_bond from "./relics/bond/definition.ts";
import relics_sacrifice from "./relics/sacrifice/definition.ts";
import relics_magnet from "./relics/magnet/definition.ts";
import relics_graze from "./relics/graze/definition.ts";
import relics_ward from "./relics/ward/definition.ts";
import relics_haste from "./relics/haste/definition.ts";
import relics_hourglass from "./relics/hourglass/definition.ts";
import relics_bloodprice from "./relics/bloodprice/definition.ts";
import relics_glass from "./relics/glass/definition.ts";
import relics_avalanche from "./relics/avalanche/definition.ts";
import relics_iceheart from "./relics/iceheart/definition.ts";
import relics_superconductor from "./relics/superconductor/definition.ts";
import relics_thunderheart from "./relics/thunderheart/definition.ts";
import relics_legion from "./relics/legion/definition.ts";
import relics_marionette from "./relics/marionette/definition.ts";
import modes_story from "./modes/story.ts";
import modes_normal from "./modes/normal.ts";
import modes_hard from "./modes/hard.ts";
import modes_nightmare from "./modes/nightmare.ts";
import modes_apocalypse from "./modes/apocalypse.ts";
import chapters_lost_library from "./chapters/lost-library/definition.ts";
import chapters_echo_gallery from "./chapters/echo-gallery/definition.ts";
import chapters_final_court from "./chapters/final-court/definition.ts";
import routes_rest from "./routes/rest.ts";
import routes_trial from "./routes/trial.ts";
import routes_trade from "./routes/trade.ts";
import routes_shelter from "./routes/shelter.ts";
import routes_gift from "./routes/gift.ts";
import routes_forge from "./routes/forge.ts";

export const manifest = {
  assets,
  audio,
  appearances,
  bosses: [boss0, boss1, boss2],
  books: [books_frost, books_storm, books_spirit, books_flame],
  enemies: [
    enemies_nib,
    enemies_quill,
    enemies_guard,
    enemies_split,
    enemies_wisp,
    enemies_scribe,
    enemies_leech,
    enemies_sentinel,
    enemies_tower,
    enemies_ram,
    enemies_mortar,
    enemies_priest,
    enemies_binder,
    enemies_mirror,
    enemies_brood,
    enemies_reaper,
    enemies_vortex,
  ],
  elites: [elites_swift, elites_iron, elites_echo, elites_volatile],
  relics: [
    relics_power,
    relics_chain,
    relics_frost,
    relics_shatter,
    relics_spirit,
    relics_echo,
    relics_blast,
    relics_reflect,
    relics_dash,
    relics_dashnova,
    relics_shield,
    relics_heal,
    relics_leech,
    relics_short,
    relics_long,
    relics_perfect,
    relics_feather,
    relics_slow,
    relics_armor,
    relics_pulse,
    relics_gold,
    relics_crit,
    relics_reach,
    relics_rescue,
    relics_heavy,
    relics_gravity,
    relics_execute,
    relics_bleed,
    relics_nova,
    relics_rhythm,
    relics_brittle,
    relics_permafrost,
    relics_conductor,
    relics_stormcell,
    relics_bond,
    relics_sacrifice,
    relics_magnet,
    relics_graze,
    relics_ward,
    relics_haste,
    relics_hourglass,
    relics_bloodprice,
    relics_glass,
    relics_avalanche,
    relics_iceheart,
    relics_superconductor,
    relics_thunderheart,
    relics_legion,
    relics_marionette,
    relics_cinder,
    relics_pitch,
    relics_wildfire,
    relics_crucible,
    relics_coal,
    relics_firewalk,
    relics_inferno,
    relics_inscription,
    relics_rebound,
  ],
  modes: [
    modes_story,
    modes_normal,
    modes_hard,
    modes_nightmare,
    modes_apocalypse,
  ],
  chapters: [
    chapters_lost_library,
    chapters_echo_gallery,
    chapters_final_court,
  ],
  routes: [
    routes_rest,
    routes_trial,
    routes_trade,
    routes_shelter,
    routes_gift,
    routes_forge,
  ],
} as const;
