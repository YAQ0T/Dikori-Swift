// src/pages/AdminDashboard.tsx
import React, { useState, useEffect, useMemo, useCallback } from "react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useAuth } from "@/context/AuthContext";
import { useNavigate } from "react-router-dom";
import { Loader2, Trash } from "lucide-react";
import axios from "axios";
import UserTable from "@/components/admin/UserTable";

// ✅ مكونات الأدمن
import ProductForm from "@/components/admin/ProductForm";
import ProductEditDialog from "@/components/admin/ProductEditDialog";
import ProductTable from "@/components/admin/ProductTable";
import CategoryFilterMenus from "@/components/admin/CategoryFilterMenus";
import OrderTable from "@/components/admin/OrderTable";
import OrderDetailsDialog from "@/components/admin/OrderDetailsDialog";
import DiscountRulesManager from "@/components/admin/DiscountRulesManager";
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog";
import {
  emptyLocalized,
  ensureLocalizedObject,
  getLocalizedText,
  type LocalizedObject,
} from "@/lib/localized";
import { useLanguage } from "@/context/LanguageContext";

type ProductItem = {
  _id: string;
  name: LocalizedObject;
  description: LocalizedObject;
  images: string[];
  mainCategory?: string;
  subCategory?: string;
  ownershipType?: "ours" | "local";
  minPrice?: number;
  totalStock?: number;
  price?: number;
  quantity?: number;
  createdAt?: string;
};

type ProductLite = {
  _id: string;
  name: LocalizedObject;
  images?: string[];
  mainImage?: string;
  price?: number;
};

const getLiteImage = (p: ProductLite) =>
  p.images?.[0] ||
  p.mainImage ||
  "https://placehold.co/300x200/png?text=No+Image";

type AdminNotification = {
  _id: string;
  title: string;
  message: string;
  target: "all" | "user";
  createdAt: string;
  user?: {
    _id: string;
    name?: string;
    email?: string;
    phone?: string;
  } | null;
};

const AdminDashboard: React.FC = () => {
  const { user, loading, token } = useAuth();
  const navigate = useNavigate();
  const { locale } = useLanguage();

  const [checkingAuth, setCheckingAuth] = useState(true);

  // ======================= المنتجات (تبويب المنتجات) =======================
  const [newProduct, setNewProduct] = useState({
    name: { ...emptyLocalized },
    mainCategory: "",
    subCategory: "",
    description: { ...emptyLocalized },
    images: [] as string[],
    ownershipType: "ours" as "ours" | "local",
    priority: "C" as "A" | "B" | "C",
  });
  const [editingProduct, setEditingProduct] = useState<any | null>(null);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [productsState, setProductsState] = useState<ProductItem[]>([]);
  const [productFilter, setProductFilter] = useState("all");
  const [selectedMainCategory, setSelectedMainCategory] =
    useState<string>("all");
  const [ownershipFilter, setOwnershipFilter] = useState<
    "all" | "ours" | "local"
  >("all");

  // ======================= المستخدمون =======================
  const [users, setUsers] = useState<any[]>([]);
  const [userRoleFilter, setUserRoleFilter] = useState("all");

  // ======================= الإشعارات =======================
  const [notifications, setNotifications] = useState<AdminNotification[]>([]);
  const [notificationsLoading, setNotificationsLoading] = useState(false);
  const [notificationForm, setNotificationForm] = useState({
    title: "",
    message: "",
    target: "all" as "all" | "user",
    userId: "",
  });
  const [notificationError, setNotificationError] = useState<string | null>(
    null
  );
  const [notificationSuccess, setNotificationSuccess] = useState<string | null>(
    null
  );
  const [notificationSubmitting, setNotificationSubmitting] = useState(false);
  const [notificationsLoadError, setNotificationsLoadError] =
    useState<string | null>(null);
  const [deletingNotificationId, setDeletingNotificationId] = useState<
    string | null
  >(null);

  // ======================= الطلبات =======================
  const [orders, setOrders] = useState<any[]>([]);
  const [filter, setFilter] = useState("all");
  const [selectedOrder, setSelectedOrder] = useState<any>(null);

  // ======================= واجهة المتجر (القوائم) =======================
  const [hcLoading, setHcLoading] = useState(true);
  const [hcSaving, setHcSaving] = useState(false);
  const [recommended, setRecommended] = useState<ProductLite[]>([]);
  const [newArrivals, setNewArrivals] = useState<ProductLite[]>([]);
  const [searchTab, setSearchTab] = useState<"recommended" | "new">(
    "recommended"
  );
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<ProductLite[]>([]);

  const apiHeaders = useMemo(
    () => (token ? { Authorization: `Bearer ${token}` } : undefined),
    [token]
  );

  const normalizeNotification = useCallback((raw: any): AdminNotification => {
    const createdAtValue =
      typeof raw?.createdAt === "string"
        ? raw.createdAt
        : raw?.createdAt
        ? new Date(raw.createdAt).toISOString()
        : new Date().toISOString();

    let userInfo: AdminNotification["user"] = null;
    if (raw?.user && typeof raw.user === "object") {
      userInfo = {
        _id: String(raw.user._id || ""),
        name: raw.user.name || undefined,
        email: raw.user.email || undefined,
        phone: raw.user.phone || undefined,
      };
    }

    return {
      _id: String(raw?._id || ""),
      title: String(raw?.title || ""),
      message: String(raw?.message || ""),
      target: raw?.target === "user" ? "user" : "all",
      createdAt: createdAtValue,
      user: userInfo,
    };
  }, []);

  // تحقق من صلاحيات الأدمن
  useEffect(() => {
    if (!loading && (!user || user.role !== "admin")) {
      navigate("/");
    } else {
      setCheckingAuth(false);
    }
  }, [user, loading, navigate]);

  // جلب المستخدمين
  useEffect(() => {
    if (!token) return;
    axios
      .get(`${import.meta.env.VITE_API_URL}/api/users`, {
        headers: apiHeaders,
      })
      .then((res) => setUsers(res.data))
      .catch((err) => console.error("❌ Failed to fetch users", err));
  }, [token, apiHeaders]);

  // جلب الإشعارات
  useEffect(() => {
    if (!token) return;
    let active = true;
    setNotificationsLoading(true);
    setNotificationsLoadError(null);
    axios
      .get(`${import.meta.env.VITE_API_URL}/api/notifications`, {
        headers: apiHeaders,
      })
      .then((res) => {
        if (!active) return;
        const list = Array.isArray(res.data) ? res.data : [];
        setNotifications(list.map((item: any) => normalizeNotification(item)));
      })
      .catch((err) => {
        if (!active) return;
        console.error("❌ Failed to fetch notifications", err);
        setNotificationsLoadError("تعذّر جلب الإشعارات حاليًا");
      })
      .finally(() => {
        if (!active) return;
        setNotificationsLoading(false);
      });

    return () => {
      active = false;
    };
  }, [token, apiHeaders, normalizeNotification]);

  const handleDeleteNotification = useCallback(
    async (notificationId: string) => {
      if (!token) return;

      const confirmed = window.confirm("هل أنت متأكد من حذف هذا الإشعار؟");
      if (!confirmed) {
        return;
      }

      setNotificationError(null);
      setNotificationSuccess(null);
      setDeletingNotificationId(notificationId);

      try {
        await axios.delete(
          `${import.meta.env.VITE_API_URL}/api/notifications/${notificationId}`,
          {
            headers: apiHeaders,
          }
        );

        setNotifications((prev) =>
          prev.filter((notification) => notification._id !== notificationId)
        );
        setNotificationSuccess("تم حذف الإشعار بنجاح");
      } catch (err) {
        console.error("❌ Failed to delete notification", err);
        setNotificationError("تعذّر حذف الإشعار، حاول مرة أخرى لاحقًا");
      } finally {
        setDeletingNotificationId(null);
      }
    },
    [token, apiHeaders]
  );

  // دالة جلب الطلبات
  const fetchOrders = async () => {
    if (!token) return;
    try {
      const res = await axios.get(
        `${import.meta.env.VITE_API_URL}/api/orders`,
        { headers: apiHeaders }
      );
      setOrders(res.data);
    } catch (err) {
      console.error("Order Fetch Error:", err);
    }
  };

  useEffect(() => {
    fetchOrders();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  // جلب المنتجات + الإحصاءات
  const fetchProductsWithStats = async () => {
    if (!token) return;
    try {
      const base = `${import.meta.env.VITE_API_URL}/api/products/with-stats`;
      const params: Record<string, string | number> = { page: 1, limit: 2000 };
      if (ownershipFilter !== "all") params.ownership = ownershipFilter;
      const url = `${base}?${new URLSearchParams(
        Object.entries(params).map(([k, v]) => [k, String(v)])
      ).toString()}`;

      const res = await axios.get(url, { headers: apiHeaders });
      const { items } = res.data || { items: [] };
      const mapped: ProductItem[] = (items || []).map((p: any) => ({
        ...p,
        name: ensureLocalizedObject(p.name),
        description: ensureLocalizedObject(p.description),
        images: Array.isArray(p.images) ? p.images : [],
        price: typeof p.minPrice === "number" ? p.minPrice : 0,
        quantity: typeof p.totalStock === "number" ? p.totalStock : 0,
      }));
      setProductsState(mapped);
    } catch (err) {
      console.error("❌ Failed to fetch products with stats", err);
      setProductsState([]);
    }
  };

  useEffect(() => {
    fetchProductsWithStats();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, ownershipFilter]);

  // تعديل حالة الطلب
  const updateStatus = async (
    orderId: string,
    newStatus:
      | "waiting_confirmation"
      | "pending"
      | "on_the_way"
      | "delivered"
      | "cancelled"
  ) => {
    try {
      if (!orderId) throw new Error("orderId مفقود");
      await axios.patch(
        `${import.meta.env.VITE_API_URL}/api/orders/${orderId}/status`,
        { status: newStatus },
        { headers: apiHeaders }
      );

      setOrders((prev) =>
        prev.map((o) => (o._id === orderId ? { ...o, status: newStatus } : o))
      );

      fetchOrders();
    } catch (err: any) {
      const status = err?.response?.status;
      const data = err?.response?.data;
      console.error("Failed to update status", status, data || err);
      alert(
        data?.message
          ? `فشل تحديث الحالة: ${data.message}`
          : `فشل تحديث الحالة (HTTP ${status || "?"})`
      );
    }
  };

  // تجميع التصنيفات
  const categoryMap = useMemo(() => {
    return productsState.reduce((acc, product) => {
      const mainKey = product.mainCategory || "";
      if (!acc[mainKey]) acc[mainKey] = new Set<string>();
      if (product.subCategory) acc[mainKey].add(product.subCategory);
      return acc;
    }, {} as Record<string, Set<string>>);
  }, [productsState]);

  // فلترة محلية حسب الملكية
  const productsForTable = useMemo(() => {
    if (ownershipFilter === "all") return productsState;
    return productsState.filter(
      (p) => (p.ownershipType || "ours") === ownershipFilter
    );
  }, [productsState, ownershipFilter]);

  const filteredUsers = users.filter((u) =>
    userRoleFilter === "all" ? true : u.role === userRoleFilter
  );

  const handleDeleteUser = async (userId: string, userName: string) => {
    const confirmDelete = confirm(
      `هل أنت متأكد من حذف المستخدم "${userName}"؟`
    );
    if (!confirmDelete) return;

    try {
      await axios.delete(
        `${import.meta.env.VITE_API_URL}/api/users/${userId}`,
        { headers: apiHeaders }
      );
      setUsers((prev) => prev.filter((u) => u._id !== userId));
    } catch (err) {
      console.error("❌ Error deleting user", err);
      alert("فشل في حذف المستخدم");
    }
  };

  const handleCreateNotification = async (
    event: React.FormEvent<HTMLFormElement>
  ) => {
    event.preventDefault();
    if (!token) return;

    setNotificationError(null);
    setNotificationSuccess(null);

    const trimmedTitle = notificationForm.title.trim();
    const trimmedMessage = notificationForm.message.trim();

    if (!trimmedTitle) {
      setNotificationError("يرجى إدخال عنوان الإشعار");
      return;
    }

    if (!trimmedMessage) {
      setNotificationError("يرجى كتابة نص الإشعار");
      return;
    }

    if (notificationForm.target === "user" && !notificationForm.userId) {
      setNotificationError("يرجى اختيار المستخدم المستهدف");
      return;
    }

    setNotificationSubmitting(true);

    try {
      const payload: {
        title: string;
        message: string;
        target: "all" | "user";
        userId?: string;
      } = {
        title: trimmedTitle,
        message: trimmedMessage,
        target: notificationForm.target,
      };

      if (notificationForm.target === "user") {
        payload.userId = notificationForm.userId;
      }

      const { data } = await axios.post(
        `${import.meta.env.VITE_API_URL}/api/notifications`,
        payload,
        { headers: apiHeaders }
      );

      const created = normalizeNotification(data);
      setNotifications((prev) =>
        created._id ? [created, ...prev] : prev
      );
      setNotificationsLoadError(null);
      setNotificationForm({ title: "", message: "", target: "all", userId: "" });
      setNotificationSuccess("تم إرسال الإشعار بنجاح ✅");
    } catch (err: any) {
      console.error("❌ Failed to send notification", err);
      const message =
        err?.response?.data?.message ||
        "تعذّر إرسال الإشعار، حاول مرة أخرى.";
      setNotificationError(message);
    } finally {
      setNotificationSubmitting(false);
    }
  };

  const handleAfterProductChange = () => {
    fetchProductsWithStats();
  };

  // ======================= واجهة المتجر: تحميل/بحث/حفظ =======================
  // تحميل القوائم الحالية
  useEffect(() => {
    let live = true;
    (async () => {
      try {
        setHcLoading(true);
        const base = import.meta.env.VITE_API_URL;
        const { data } = await axios.get(`${base}/api/home-collections`, {
          headers: apiHeaders,
        });
        if (!live) return;
        setRecommended(
          Array.isArray(data?.recommended)
            ? data.recommended.map((p: any) => ({
                ...p,
                name: ensureLocalizedObject(p.name),
              }))
            : []
        );
        setNewArrivals(
          Array.isArray(data?.newArrivals)
            ? data.newArrivals.map((p: any) => ({
                ...p,
                name: ensureLocalizedObject(p.name),
              }))
            : []
        );
      } catch (e) {
        // تجاهل
      } finally {
        if (live) setHcLoading(false);
      }
    })();
    return () => {
      live = false;
    };
  }, [apiHeaders]);

  // البحث عن منتجات لإضافتها لأي قائمة
  useEffect(() => {
    let live = true;
    const t = setTimeout(async () => {
      if (!query.trim()) {
        setResults([]);
        return;
      }
      try {
        const base = import.meta.env.VITE_API_URL;
        const params = new URLSearchParams();
        params.set("page", "1");
        params.set("limit", "12");
        params.set("q", query.trim());
        const url = `${base}/api/products/with-stats?${params.toString()}`;
        const { data } = await axios.get(url, { headers: apiHeaders });
        if (!live) return;

        const items = Array.isArray(data?.items) ? data.items : [];
        const mapped: ProductLite[] = items.map((p: any) => ({
          _id: p._id,
          name: ensureLocalizedObject(p.name),
          images: p.images,
          mainImage: p.mainImage,
          price: p.minPrice,
        }));
        setResults(mapped);
      } catch {
        if (!live) return;
        setResults([]);
      }
    }, 300);
    return () => {
      live = false;
      clearTimeout(t);
    };
  }, [query, apiHeaders]);

  const addToList = (p: ProductLite) => {
    const existsInRec = recommended.some((x) => x._id === p._id);
    const existsInNew = newArrivals.some((x) => x._id === p._id);
    if (searchTab === "recommended" && !existsInRec) {
      setRecommended((prev) => [...prev, p]);
    }
    if (searchTab === "new" && !existsInNew) {
      setNewArrivals((prev) => [...prev, p]);
    }
  };

  const removeFromList = (list: "recommended" | "new", id: string) => {
    if (list === "recommended") {
      setRecommended((prev) => prev.filter((x) => x._id !== id));
    } else {
      setNewArrivals((prev) => prev.filter((x) => x._id !== id));
    }
  };

  const move = (list: "recommended" | "new", index: number, dir: -1 | 1) => {
    const arr = list === "recommended" ? [...recommended] : [...newArrivals];
    const newIndex = index + dir;
    if (newIndex < 0 || newIndex >= arr.length) return;
    const tmp = arr[index];
    arr[index] = arr[newIndex];
    arr[newIndex] = tmp;
    if (list === "recommended") setRecommended(arr);
    else setNewArrivals(arr);
  };

  const saveHomeCollections = async () => {
    try {
      setHcSaving(true);
      const base = import.meta.env.VITE_API_URL;
      const payload = {
        recommendedIds: recommended.map((p) => p._id),
        newArrivalIds: newArrivals.map((p) => p._id),
      };
      await axios.put(`${base}/api/home-collections`, payload, {
        headers: apiHeaders,
      });
      alert("تم الحفظ بنجاح ✅");
    } catch {
      alert("فشل الحفظ، حاول مجددًا.");
    } finally {
      setHcSaving(false);
    }
  };

  if (checkingAuth) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center gap-4">
        <Loader2 className="w-10 h-10 text-primary animate-spin" />
        <p className="text-sm text-muted-foreground">
          جارٍ التحقق من الصلاحيات...
        </p>
      </div>
    );
  }

  return (
    <>
      <Navbar />
      <main className="container mx-auto p-6 text-right">
        <h1 className="text-3xl font-bold mb-6">لوحة تحكم الأدمن</h1>

        <Tabs defaultValue="products" className="w-full">
          <TabsList className="flex justify-end mb-6 flex-wrap gap-2">
            <TabsTrigger value="home">واجهة المتجر</TabsTrigger>
            <TabsTrigger value="products">المنتجات</TabsTrigger>
            <TabsTrigger value="orders">الطلبات</TabsTrigger>
            <TabsTrigger value="users">المستخدمين</TabsTrigger>
            <TabsTrigger value="notifications">الإشعارات</TabsTrigger>
            <TabsTrigger value="discounts">خصومات الطلبات</TabsTrigger>
          </TabsList>

          {/* ======================= تبويب واجهة المتجر ======================= */}
          <TabsContent value="home">
            <h2 className="text-xl font-semibold mb-4">
              إدارة منتجات الصفحة الرئيسية
            </h2>

            {hcLoading ? (
              <p className="text-center">جاري التحميل…</p>
            ) : (
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* القوائم المختارة */}
                <section className="lg:col-span-2">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {/* المقترحة */}
                    <div className="rounded-2xl border p-4 bg-white dark:bg-gray-900">
                      <div className="flex items-center justify-between mb-3">
                        <h3 className="font-semibold text-lg">
                          منتجات مُقترحة لك
                        </h3>
                        <span className="text-sm text-gray-500">
                          {recommended.length} منتج
                        </span>
                      </div>
                      <ul className="space-y-3">
                        {recommended.map((p, idx) => {
                          const displayName =
                            getLocalizedText(p.name, locale) || p._id;
                          return (
                            <li
                              key={p._id}
                              className="flex gap-3 items-center border rounded-lg p-2"
                            >
                              <img
                                src={getLiteImage(p)}
                                alt={displayName}
                                className="w-16 h-16 object-cover rounded-md"
                              />
                              <div className="flex-1">
                                <div className="font-medium line-clamp-1">
                                  {displayName}
                                </div>
                                {typeof p.price === "number" && (
                                  <div className="text-sm text-gray-500 mt-0.5">
                                    {p.price} ₪
                                  </div>
                                )}
                              </div>
                              <div className="flex items-center gap-1">
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  onClick={() => move("recommended", idx, -1)}
                                  title="أعلى"
                                >
                                  ▲
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  onClick={() => move("recommended", idx, +1)}
                                  title="أسفل"
                                >
                                  ▼
                                </Button>
                                <Button
                                  variant="destructive"
                                  onClick={() =>
                                    removeFromList("recommended", p._id)
                                  }
                                >
                                  إزالة
                                </Button>
                              </div>
                            </li>
                          );
                        })}
                      </ul>
                    </div>

                    {/* وصل حديثًا */}
                    <div className="rounded-2xl border p-4 bg-white dark:bg-gray-900">
                      <div className="flex items-center justify-between mb-3">
                        <h3 className="font-semibold text-lg">وصل حديثًا</h3>
                        <span className="text-sm text-gray-500">
                          {newArrivals.length} منتج
                        </span>
                      </div>
                      <ul className="space-y-3">
                        {newArrivals.map((p, idx) => {
                          const displayName =
                            getLocalizedText(p.name, locale) || p._id;
                          return (
                            <li
                              key={p._id}
                              className="flex gap-3 items-center border rounded-lg p-2"
                            >
                              <img
                                src={getLiteImage(p)}
                                alt={displayName}
                                className="w-16 h-16 object-cover rounded-md"
                              />
                              <div className="flex-1">
                                <div className="font-medium line-clamp-1">
                                  {displayName}
                                </div>
                                {typeof p.price === "number" && (
                                  <div className="text-sm text-gray-500 mt-0.5">
                                    {p.price} ₪
                                  </div>
                                )}
                              </div>
                              <div className="flex items-center gap-1">
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  onClick={() => move("new", idx, -1)}
                                  title="أعلى"
                                >
                                  ▲
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  onClick={() => move("new", idx, +1)}
                                  title="أسفل"
                                >
                                  ▼
                                </Button>
                                <Button
                                  variant="destructive"
                                  onClick={() => removeFromList("new", p._id)}
                                >
                                  إزالة
                                </Button>
                              </div>
                            </li>
                          );
                        })}
                      </ul>
                    </div>
                  </div>

                  <div className="mt-6 flex justify-end">
                    <Button onClick={saveHomeCollections} disabled={hcSaving}>
                      {hcSaving ? "جارٍ الحفظ…" : "حفظ التغييرات"}
                    </Button>
                  </div>
                </section>

                {/* البحث والإضافة */}
                <aside className="rounded-2xl border p-4 bg-white dark:bg-gray-900">
                  <div className="flex items-center justify-between gap-2 mb-3">
                    <h3 className="font-semibold">البحث عن المنتجات</h3>
                    <div className="flex items-center gap-2">
                      <button
                        className={`px-3 py-1 rounded ${
                          searchTab === "recommended"
                            ? "bg-black text-white"
                            : "bg-gray-100"
                        }`}
                        onClick={() => setSearchTab("recommended")}
                      >
                        أضف للمقترحة
                      </button>
                      <button
                        className={`px-3 py-1 rounded ${
                          searchTab === "new"
                            ? "bg-black text-white"
                            : "bg-gray-100"
                        }`}
                        onClick={() => setSearchTab("new")}
                      >
                        أضف لوصل حديثًا
                      </button>
                    </div>
                  </div>

                  <Input
                    type="text"
                    placeholder="اكتب اسم المنتج…"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                  />

                  <div className="mt-4 space-y-3 max-h-[60vh] overflow-auto">
                    {results.map((p) => {
                      const displayName =
                        getLocalizedText(p.name, locale) || p._id;
                      return (
                        <div
                          key={p._id}
                          className="flex gap-3 items-center border rounded-lg p-2"
                        >
                          <img
                            src={getLiteImage(p)}
                            alt={displayName}
                            className="w-14 h-14 object-cover rounded-md"
                          />
                          <div className="flex-1">
                            <div className="font-medium line-clamp-1">
                              {displayName}
                            </div>
                            {typeof p.price === "number" && (
                              <div className="text-sm text-gray-500 mt-0.5">
                                {p.price} ₪
                              </div>
                            )}
                          </div>
                          <Button onClick={() => addToList(p)}>
                            {searchTab === "recommended"
                              ? "إضافة للمقترحة"
                              : "إضافة لوصل حديثًا"}
                          </Button>
                        </div>
                      );
                    })}
                    {!results.length && query.trim() && (
                      <p className="text-sm text-gray-500 text-center">
                        لا توجد نتائج مطابقة…
                      </p>
                    )}
                  </div>
                </aside>
              </div>
            )}
          </TabsContent>

          {/* ======================= تبويب المنتجات ======================= */}
          <TabsContent value="products">
            <div className="flex justify-between mb-4">
              <h2 className="text-xl font-semibold">جميع المنتجات</h2>
              <div className="flex gap-2">
                <CategoryFilterMenus
                  selectedMainCategory={selectedMainCategory}
                  setSelectedMainCategory={setSelectedMainCategory}
                  productFilter={productFilter}
                  setProductFilter={setProductFilter}
                  categoryMap={categoryMap}
                  ownershipFilter={ownershipFilter}
                  setOwnershipFilter={setOwnershipFilter}
                />

                <Dialog>
                  <DialogTrigger asChild>
                    <Button>➕ إضافة منتج</Button>
                  </DialogTrigger>
                  <DialogContent>
                    {token && (
                      <ProductForm
                        newProduct={newProduct}
                        setNewProduct={setNewProduct}
                        productsState={productsState}
                        setProductsState={setProductsState}
                        token={token}
                        onSuccess={handleAfterProductChange}
                      />
                    )}
                  </DialogContent>
                </Dialog>

                <Dialog
                  open={isEditModalOpen}
                  onOpenChange={setIsEditModalOpen}
                >
                  {token && (
                    <ProductEditDialog
                      onClose={() => setIsEditModalOpen(false)}
                      editingProduct={editingProduct}
                      setEditingProduct={setEditingProduct}
                      setProductsState={setProductsState}
                      token={token}
                      products={productsState}
                      onSuccess={handleAfterProductChange}
                    />
                  )}
                </Dialog>
              </div>
            </div>

            {token && (
              <ProductTable
                productsState={productsForTable}
                setProductsState={setProductsState}
                productFilter={productFilter}
                token={token}
                onEdit={(product) => {
                  setEditingProduct({
                    ...product,
                    name: ensureLocalizedObject(product.name),
                    description: ensureLocalizedObject(product.description),
                  });
                  setIsEditModalOpen(true);
                }}
                onRefreshProducts={handleAfterProductChange}
              />
            )}
          </TabsContent>

          {/* ======================= تبويب الطلبات ======================= */}
          <TabsContent value="orders">
            <h2 className="text-xl font-semibold mb-4">الطلبات</h2>

            <div className="flex justify-end gap-2 mb-4 flex-wrap">
              <Button
                variant={filter === "all" ? "default" : "outline"}
                onClick={() => setFilter("all")}
              >
                الكل
              </Button>
              <Button
                variant={
                  filter === "waiting_confirmation" ? "default" : "outline"
                }
                onClick={() => setFilter("waiting_confirmation")}
              >
                ⏱️ بانتظار التأكيد
              </Button>
              <Button
                variant={filter === "pending" ? "default" : "outline"}
                onClick={() => setFilter("pending")}
              >
                قيد الانتظار
              </Button>
              <Button
                variant={filter === "on_the_way" ? "default" : "outline"}
                onClick={() => setFilter("on_the_way")}
              >
                🚚 في الطريق
              </Button>
              <Button
                variant={filter === "delivered" ? "default" : "outline"}
                onClick={() => setFilter("delivered")}
              >
                تم التوصيل
              </Button>
              <Button
                variant={filter === "cancelled" ? "default" : "outline"}
                onClick={() => setFilter("cancelled")}
              >
                ملغى
              </Button>
            </div>

            <OrderTable
              orders={orders}
              filter={filter}
              updateStatus={updateStatus}
              setSelectedOrder={setSelectedOrder}
            />
            {token && (
              <OrderDetailsDialog
                selectedOrder={selectedOrder}
                setSelectedOrder={setSelectedOrder}
                setOrders={setOrders}
                token={token}
                orders={orders}
              />
            )}
          </TabsContent>

          {/* ======================= تبويب المستخدمين ======================= */}
          <TabsContent value="users">
            <h2 className="text-xl font-semibold mb-4">جميع المستخدمين</h2>
            <div className="flex justify-end gap-2 mb-4">
              <Button
                variant={userRoleFilter === "all" ? "default" : "outline"}
                onClick={() => setUserRoleFilter("all")}
              >
                الكل
              </Button>
              <Button
                variant={userRoleFilter === "admin" ? "default" : "outline"}
                onClick={() => setUserRoleFilter("admin")}
              >
                أدمن
              </Button>
              <Button
                variant={userRoleFilter === "user" ? "default" : "outline"}
                onClick={() => setUserRoleFilter("user")}
              >
                مستخدم
              </Button>
            </div>
          {user?._id && (
            <UserTable
              users={filteredUsers}
              onDelete={handleDeleteUser}
              currentAdminId={user?._id}
            />
          )}
        </TabsContent>

          {/* ======================= تبويب الإشعارات ======================= */}
          <TabsContent value="notifications">
            <h2 className="text-xl font-semibold mb-4">إدارة الإشعارات</h2>

            <form
              onSubmit={handleCreateNotification}
              className="space-y-4 max-w-2xl ml-auto"
            >
              <div>
                <label className="mb-2 block text-sm font-medium">
                  عنوان الإشعار
                </label>
                <Input
                  value={notificationForm.title}
                  onChange={(e) =>
                    setNotificationForm((prev) => ({
                      ...prev,
                      title: e.target.value,
                    }))
                  }
                  placeholder="مثال: عروض جديدة على المنتجات"
                  required
                />
              </div>

              <div>
                <label className="mb-2 block text-sm font-medium">
                  نص الإشعار
                </label>
                <Textarea
                  value={notificationForm.message}
                  onChange={(e) =>
                    setNotificationForm((prev) => ({
                      ...prev,
                      message: e.target.value,
                    }))
                  }
                  rows={4}
                  placeholder="اكتب تفاصيل الإشعار هنا"
                  required
                />
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <div>
                  <label className="mb-2 block text-sm font-medium">
                    الفئة المستهدفة
                  </label>
                  <Select
                    value={notificationForm.target}
                    onValueChange={(value) =>
                      setNotificationForm((prev) => ({
                        ...prev,
                        target: value as "all" | "user",
                        userId: value === "user" ? prev.userId : "",
                      }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="اختر الفئة" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">جميع المستخدمين</SelectItem>
                      <SelectItem value="user">مستخدم محدد</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                {notificationForm.target === "user" && (
                  <div>
                    <label className="mb-2 block text-sm font-medium">
                      اختر المستخدم
                    </label>
                    <Select
                      value={notificationForm.userId || undefined}
                      onValueChange={(value) =>
                        setNotificationForm((prev) => ({
                          ...prev,
                          userId: value,
                        }))
                      }
                    >
                      <SelectTrigger>
                        <SelectValue placeholder="اختر المستخدم" />
                      </SelectTrigger>
                      <SelectContent>
                        {users.length === 0 ? (
                          <SelectItem value="" disabled>
                            لا يوجد مستخدمون
                          </SelectItem>
                        ) : (
                          users.map((u: any) => (
                            <SelectItem key={u._id} value={u._id}>
                              {u.name || u.email || u.phone || u._id}
                            </SelectItem>
                          ))
                        )}
                      </SelectContent>
                    </Select>
                  </div>
                )}
              </div>

              {notificationError && (
                <p className="text-destructive text-sm">
                  {notificationError}
                </p>
              )}
              {notificationSuccess && (
                <p className="text-green-600 text-sm">
                  {notificationSuccess}
                </p>
              )}

              <Button type="submit" disabled={notificationSubmitting}>
                {notificationSubmitting ? "جاري الإرسال..." : "إرسال الإشعار"}
              </Button>
            </form>

            <div className="mt-8">
              <h3 className="text-lg font-semibold mb-3">آخر الإشعارات</h3>
              {notificationsLoading ? (
                <p className="text-gray-500">جاري التحميل…</p>
              ) : notificationsLoadError ? (
                <p className="text-destructive">{notificationsLoadError}</p>
              ) : notifications.length === 0 ? (
                <p className="text-gray-500">لا يوجد إشعارات بعد.</p>
              ) : (
                <div className="space-y-3">
                  {notifications.map((notification) => {
                    const createdAt = new Date(
                      notification.createdAt
                    ).toLocaleString("ar-EG");
                    const targetLabel =
                      notification.target === "all"
                        ? "مرسل إلى جميع المستخدمين"
                        : `مستخدم محدد: ${
                            notification.user?.name ||
                            notification.user?.email ||
                            notification.user?.phone ||
                            notification.user?._id ||
                            "-"
                          }`;

                    const isDeleting =
                      deletingNotificationId === notification._id;

                    return (
                      <div
                        key={notification._id}
                        className="rounded-lg border p-4 bg-white dark:bg-gray-900 shadow-sm"
                      >
                        <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
                          <div>
                            <h4 className="font-semibold text-base">
                              {notification.title}
                            </h4>
                            <p className="text-xs text-muted-foreground">
                              {createdAt}
                            </p>
                          </div>
                          <div className="flex flex-col items-start gap-2 md:items-end md:text-right">
                            <span className="text-xs text-muted-foreground">
                              {targetLabel}
                            </span>
                            <Button
                              size="sm"
                              variant="destructive"
                              className="flex items-center gap-2"
                              onClick={() =>
                                handleDeleteNotification(notification._id)
                              }
                              disabled={isDeleting}
                            >
                              {isDeleting ? (
                                <>
                                  <Loader2 className="h-4 w-4 animate-spin" />
                                  جارٍ الحذف...
                                </>
                              ) : (
                                <>
                                  <Trash className="h-4 w-4" />
                                  حذف
                                </>
                              )}
                            </Button>
                          </div>
                        </div>
                        <p className="mt-3 text-sm leading-relaxed">
                          {notification.message}
                        </p>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </TabsContent>

          {/* ======================= تبويب خصومات الطلبات ======================= */}
          <TabsContent value="discounts">
            <h2 className="text-xl font-semibold mb-4">خصومات الطلبات</h2>
            <DiscountRulesManager />
          </TabsContent>
        </Tabs>
      </main>
      <Footer />
    </>
  );
};

export default AdminDashboard;
