// src/lib/api.ts
import axios from "axios";

export const API_BASE = import.meta.env.VITE_API_URL || "";

export const api = axios.create({
  baseURL: API_BASE,
  withCredentials: false,
});

export const authHeaders = (token?: string) =>
  token ? { Authorization: `Bearer ${token}` } : {};

export async function handle<T>(
  p: Promise<{ data: T }>
): Promise<[T | null, string | null]> {
  try {
    const { data } = await p;
    return [data, null];
  } catch (e: any) {
    const msg =
      e?.response?.data?.message ||
      e?.response?.data?.error ||
      e?.message ||
      "حدث خطأ";
    return [null, msg];
  }
}
