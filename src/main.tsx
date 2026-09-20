import React from "react";
import { createRoot } from "react-dom/client";
import "../data/vocab-index.js";
import { App } from "./ui/App";
import "./style.css";
import "./ui/effects.css";
createRoot(document.getElementById("root")!).render(<App />);
