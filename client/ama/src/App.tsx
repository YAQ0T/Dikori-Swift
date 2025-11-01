import { Routes, Route } from "react-router-dom";
import Home from "@/pages/Home";
import Products from "./pages/Products";
import About from "./pages/About";
import Contact from "./pages/Contact";
import Cart from "./pages/Cart";
import Account from "./pages/Account";
import Login from "./pages/Login";
import Register from "./pages/Register";
import ProductDetails from "@/pages/ProductDetails";
import PrivacyPolicy from "./pages/PrivacyPolicy";
import Terms from "./pages/Terms";
import Favorites from "./pages/Favorites";
import AdminDashboard from "./pages/AdminDashboard";
import UserOrderDetails from "./pages/UserOrderDetails";
// import OfferDialog from "./components/common/OfferDialog";
// import { useEffect, useState } from "react";
import CheckoutSuccess from "./pages/CheckoutSuccess";
import ReturnsPolicy from "./pages/ReturnsPolicy";
import AdminHomeCollections from "./pages/AdminHomeCollections";
import VerifyPhone from "./pages/VerifyPhone";

// ✅ صفحات جديدة لإدارة كلمة المرور
import ForgotPassword from "./pages/ForgotPassword";
import ResetPassword from "./pages/ResetPassword";

function App() {
  // const [open, setOpen] = useState(false);

  // useEffect(() => {
  //   setOpen(true);
  // }, []);

  return (
    <>
      {/* <OfferDialog open={open} onClose={() => setOpen(false)} /> */}
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/products" element={<Products />} />
        <Route path="/favorites" element={<Favorites />} />
        <Route path="/about" element={<About />} />
        <Route path="/contact" element={<Contact />} />
        <Route path="/cart" element={<Cart />} />
        <Route path="/account" element={<Account />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />

        {/* ✅ صفحة توثيق الجوال (المسار القديم) */}
        <Route path="/verify" element={<VerifyPhone />} />
        {/* ✅ إضافة المسار الجديد المستخدم في بعض التحويلات */}
        <Route path="/verify-phone" element={<VerifyPhone />} />

        <Route path="/products/:id" element={<ProductDetails />} />

        <Route path="/privacy-policy" element={<PrivacyPolicy />} />
        <Route path="/returnes" element={<ReturnsPolicy />} />
        <Route path="/terms" element={<Terms />} />
        <Route path="/admin" element={<AdminDashboard />} />
        <Route path="/my-orders/:orderId" element={<UserOrderDetails />} />
        <Route path="/checkout/success" element={<CheckoutSuccess />} />
        <Route
          path="/admin/home-collections"
          element={<AdminHomeCollections />}
        />

        {/* ✅ إدارة كلمة المرور */}
        <Route path="/forgot-password" element={<ForgotPassword />} />
        <Route path="/reset-password" element={<ResetPassword />} />
      </Routes>
    </>
  );
}

export default App;
