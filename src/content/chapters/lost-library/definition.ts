import type { ChapterDefinition } from "../../../contracts/content.ts";
export default {
  bossId: "ink-colossus",
  id: "lost-library",
  name: "失落书库",
  bossName: "吞墨巨像",
  rooms: [
    {
      id: "lost-library-1",
      boss: false,
      waves: 3,
      opening: ["nib", "quill", "wisp"],
      enemies: ["nib", "quill", "quill", "guard", "split", "wisp", "ram"],
      easyEnemies: {
        belowRank: 2,
        pool: ["nib", "nib", "quill", "wisp"],
      },
      routes: ["rest", "gift", "trial"],
    },
    {
      id: "lost-library-2",
      boss: false,
      waves: 3,
      opening: ["nib", "quill", "wisp"],
      enemies: ["nib", "quill", "quill", "guard", "split", "wisp", "ram"],
      routes: ["rest", "trial", ["trade", "forge"]],
    },
    {
      id: "lost-library-3",
      boss: true,
      waves: 3,
      opening: ["nib", "quill", "wisp"],
      enemies: [
        "nib",
        "quill",
        "guard",
        "split",
        "scribe",
        "leech",
        "ram",
        "mortar",
        "priest",
        "mirror",
      ],
      routes: ["rest", "trade", "shelter"],
    },
  ],
} satisfies ChapterDefinition;
