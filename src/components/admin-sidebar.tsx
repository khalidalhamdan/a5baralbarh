import Link from "next/link";
import { Activity, AudioLines, Headphones, Radio, Rss, Settings, ShieldCheck, Sparkles } from "lucide-react";

const links=[
  [Activity,"نظرة عامة","/"],[Headphones,"الحلقات","/episodes"],[Rss,"المصادر","/sources"],
  [AudioLines,"الأصوات","/settings#voices"],[Sparkles,"الموسيقى","/settings#music"],
  [Radio,"قنوات النشر","/settings#channels"],[ShieldCheck,"سجل العمليات","/settings#audit"],[Settings,"الإعدادات","/settings"]
] as const;
export function AdminSidebar({active="/"}:{active?:string}){return <aside className="sidebar"><div className="brand"><span className="brandMark"><Radio size={22}/></span><div><b>سوالف اليوم</b><small>غرفة الأخبار الذكية</small></div></div><nav>{links.map(([Icon,label,href])=><Link className={active===href?"active":""} href={href} key={href}><Icon size={19}/>{label}</Link>)}</nav><div className="owner"><span>ك</span><div><b>حساب المالك</b><small>دخول آمن ومقيّد</small></div></div></aside>}
