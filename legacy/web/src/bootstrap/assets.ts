import { assets } from "../content/assets.ts";
import { AssetManager } from "../platform/AssetManager.ts";
/** Shared application cache; simulation never imports media or browser loaders. */
export const assetManager = new AssetManager(assets);
