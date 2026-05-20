"use client";

import { useEffect, useState } from "react";

/**
 * Renders an ISO-8601 timestamp in the visitor's browser-local timezone.
 *
 * The rest of the page is a server component, and `new Date(...).toLocaleString(...)`
 * without an explicit `timeZone` runs on the deploy server (Fyra) — which
 * is UTC — so the "Local" label was just the same as the "UTC" one.
 * This component renders nothing on the server, then hydrates on the
 * client where `toLocaleString` actually has the visitor's locale.
 */
export default function PublishedLocal({ iso }) {
  const [label, setLabel] = useState(null);

  useEffect(() => {
    if (!iso) return;
    const formatted = new Date(iso).toLocaleString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "short",
    });
    setLabel(`${formatted} Local`);
  }, [iso]);

  if (!label) return null;
  // Include the leading separator so the line doesn't render with a
  // dangling " · " during SSR while we wait for the client to mount.
  return <> · {label}</>;
}
