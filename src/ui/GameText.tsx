import { cloneElement, isValidElement, type ReactNode } from "react";
import { GLOSSARY, glossaryById } from "../content/glossary.ts";
import { createTextTokenizer } from "../shared/game-text.ts";
import { Tooltip } from "./Tooltip";

const tokenize = createTextTokenizer(GLOSSARY);
const literalTags = new Set([
  "input",
  "textarea",
  "svg",
  "canvas",
  "code",
  "pre",
  "kbd",
  "script",
  "style",
]);

/** React-native rich text: no HTML injection, DOM rewriting or mutation observer. */
function enrich(
  node: ReactNode,
  terms: boolean,
  seen?: Set<string>,
): ReactNode {
  if (typeof node === "string" || typeof node === "number") {
    return tokenize(String(node), terms && !!seen).map((token, i) => {
      if (token.kind === "number")
        return (
          <span className="game-number" data-rich-text key={i}>
            {token.value}
          </span>
        );
      const entry = token.id && glossaryById.get(token.id);
      if (entry && !seen!.has(entry.id)) {
        seen!.add(entry.id);
        return (
          <Tooltip
            key={i}
            term={entry.id}
            title={entry.name}
            description={entry.description}
            category={entry.category}
          >
            {token.value}
          </Tooltip>
        );
      }
      return token.value;
    });
  }
  if (Array.isArray(node))
    return node.map((child) => enrich(child, terms, seen));
  if (
    !isValidElement<{
      children?: ReactNode;
      "data-plain-text"?: boolean;
      "data-rich-text"?: boolean;
      "data-prose"?: boolean;
      "data-prose-rendered"?: boolean;
      className?: string;
    }>(node)
  )
    return node;
  if (
    node.type === GameText ||
    node.type === Tooltip ||
    node.props["data-plain-text"] ||
    node.props["data-prose-rendered"] ||
    node.props["data-rich-text"] ||
    (typeof node.type === "string" && literalTags.has(node.type)) ||
    node.props.className?.includes("cmd-badge")
  )
    return node;
  if (node.props.children === undefined) return node;
  const prose =
    node.props["data-prose"] ||
    (typeof node.type === "string" && ["p", "li", "dd"].includes(node.type));
  const heading = typeof node.type === "string" && /^h[1-6]$/.test(node.type);
  return cloneElement(
    node,
    prose ? { "data-prose-rendered": true } : {},
    enrich(
      node.props.children,
      terms,
      prose ? new Set() : heading ? undefined : seen,
    ),
  );
}

/** Wrap a paragraph or a UI subtree; custom components wrap their own rendered copy. */
export function GameText({
  children,
  terms = true,
}: {
  children: ReactNode;
  terms?: boolean;
}) {
  return <>{enrich(children, terms)}</>;
}
