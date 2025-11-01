export const CART_HIGHLIGHT_EVENT = "cart:highlight";

export const dispatchCartHighlight = () => {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent(CART_HIGHLIGHT_EVENT));
};

export const subscribeToCartHighlight = (callback: () => void) => {
  if (typeof window === "undefined") {
    return () => undefined;
  }

  const handler = () => {
    callback();
  };

  window.addEventListener(CART_HIGHLIGHT_EVENT, handler);

  return () => {
    window.removeEventListener(CART_HIGHLIGHT_EVENT, handler);
  };
};
