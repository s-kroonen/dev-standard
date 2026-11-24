// CANARY: planted vulnerability for scripts/check canary. Never built, never imported.
export function Canary({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
