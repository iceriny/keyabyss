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
          {book.icon}
        </span>
      )}
    </span>
  );
}
