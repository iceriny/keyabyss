import metadata from "../../package.json" with { type: "json" };

/** The package version is shared by the UI and persisted battle reports. */
export const APP_VERSION = metadata.version;
