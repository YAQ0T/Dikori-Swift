// client/ama/src/lib/loadScript.ts
export function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const id = `script-${btoa(src).replace(/=/g, "")}`;
    if (document.getElementById(id)) return resolve();
    const s = document.createElement("script");
    s.id = id;
    s.src = src;
    s.async = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error(`Failed to load ${src}`));
    document.head.appendChild(s);
  });
}
