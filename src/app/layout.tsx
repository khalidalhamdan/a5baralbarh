import "./styles.css";
import type { Metadata } from "next";

export const metadata: Metadata = { title: "سوالف اليوم | غرفة الأخبار", description: "منصة إنتاج بودكاست الأخبار السعودي" };

export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="ar" dir="rtl"><body>{children}</body></html>;
}
