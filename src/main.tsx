import React from "react";
import { createRoot } from "react-dom/client";
import "../data/vocab-index.js";
import { App } from "./ui/App";
import "./style.css";
import "./ui/effects.css";
import "./ui/ritual.css";
import "./ui/typography.css";
import "./ui/results.css";
import "./ui/open-ui.css";
import "./ui/desktop.css";

if (!document.documentElement.dataset.gameMounted) {
  document.documentElement.dataset.gameMounted = "true";
  createRoot(document.getElementById("root")!).render(<App />);
}
