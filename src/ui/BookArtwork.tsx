import { useEffect, useState } from "react";
import type { Book } from "../contracts/content.ts";
import { assetManager } from "../bootstrap/assets.ts";

/** Shared media view: all instances reuse the application image cache. */
export function BookArtwork({
  book,
  className = "",
  decorative = false,
}: {
  book: Book;
  className?: string;
  decorative?: boolean;
}) {
  const [loaded, setLoaded] = useState<{ id: string; src: string } | null>(
    null,
  );
  useEffect(() => {
    let active = true;
    if (book.artwork)
      assetManager
        .loadImage(book.artwork)
        .then((image) => {
          if (active) setLoaded({ id: book.artwork!, src: image.src });
        })
        .catch(() => {
          if (active) setLoaded(null);
        });
    return () => {
      active = false;
    };
  }, [book.artwork]);
  const source = loaded?.id === book.artwork ? loaded?.src : undefined;
  return (
    <span className={`book-artwork ${className}`} data-asset={book.artwork}>
      {source ? (
        <img
          src={source}
          alt={decorative ? "" : book.name}
          draggable={false}
          decoding="async"
        />
      ) : (
        <span
          className="book-artwork-fallback"
          aria-hidden={decorative || undefined}
        >
          <svg viewBox="0 0 64 64" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><path d="M9 14Q21 8 32 17Q43 8 55 14V51Q43 46 32 55Q21 46 9 51ZM32 17V55M17 24L24 27M40 27L47 24M17 34L24 37M40 37L47 34" /></svg>
        </span>
      )}
    </span>
  );
}
