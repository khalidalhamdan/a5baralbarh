import { Activity, AudioLines, CircleCheck, Clock3, Coins, Headphones, Newspaper, Radio, Rss, Settings, ShieldCheck, Sparkles, TriangleAlert } from "lucide-react";

const stages = [
  ["جمع الأخبار", "تم", "08:00"], ["التحقق والترتيب", "تم", "08:04"], ["كتابة الحوار", "تم", "08:08"],
  ["توليد الأصوات", "جارٍ", "68%"], ["المكساج", "قادم", "—"], ["بانتظار المراجعة", "قادم", "—"]
];
const stories = ["إطلاق مبادرة وطنية جديدة للذكاء الاصطناعي", "نمو القطاع غير النفطي خلال الربع الثاني", "تحديثات مشاريع النقل في الرياض", "نتائج الجولة الأخيرة من دوري روشن"];

export default function Dashboard() {
  return <main className="shell">
    <aside className="sidebar">
      <div className="brand"><span className="brandMark"><Radio size={22}/></span><div><b>سوالف اليوم</b><small>غرفة الأخبار الذكية</small></div></div>
      <nav>{[[Activity,"نظرة عامة",true],[Headphones,"الحلقات"],[Rss,"المصادر"],[AudioLines,"الأصوات"],[Sparkles,"الموسيقى"],[Radio,"قنوات النشر"],[ShieldCheck,"سجل العمليات"],[Settings,"الإعدادات"]].map(([Icon,label,on]) => { const I=Icon as typeof Activity; return <a className={on?"active":""} key={label as string}><I size={19}/>{label as string}</a>})}</nav>
      <div className="owner"><span>ك</span><div><b>حساب المالك</b><small>دخول آمن ومقيّد</small></div></div>
    </aside>
    <section className="content">
      <header><div><p className="eyebrow">الأحد، ١٠ أغسطس ٢٠٢٦</p><h1>صباح الخير 👋</h1><p>هذه حالة حلقة اليوم ومسار الإنتاج.</p></div><div className="live"><i/> النظام يعمل</div></header>
      <section className="hero">
        <div><span className="pill"><Sparkles size={15}/> حلقة اليوم</span><h2>موجز الأحد: اقتصاد وتقنية وحياة</h2><p>يتم الآن تحويل الحوار إلى صوت المضيفين. ستصل الحلقة إلى المراجعة قبل النشر.</p><div className="progress"><i style={{width:"68%"}}/></div><small>اكتمل ٦٨٪ · المدة المتوقعة ١٠:٢٤</small></div>
        <div className="orb"><AudioLines size={42}/><span>توليد الصوت</span></div>
      </section>
      <section className="stats">
        <Stat icon={Newspaper} label="قصص مختارة" value="6" note="من ٢٤ خبراً"/>
        <Stat icon={Clock3} label="المدة المتوقعة" value="10:24" note="ضمن الهدف" good/>
        <Stat icon={Coins} label="تكلفة اليوم" value="8.40 ر.س" note="أقل من الحد"/>
        <Stat icon={CircleCheck} label="المصادر" value="9 / 10" note="مصدر يحتاج انتباه" warn/>
      </section>
      <div className="grid">
        <section className="panel pipeline"><div className="panelHead"><div><h3>مسار إنتاج اليوم</h3><p>كل خطوة محفوظة ويمكن استئنافها</p></div><button>عرض التفاصيل</button></div>
          <div className="steps">{stages.map(([name,state,time],i)=><div className={`step ${state==="جارٍ"?"current":""}`} key={name}><span className="stepIcon">{state==="تم"?<CircleCheck size={20}/>:i+1}</span><div><b>{name}</b><small>{state}</small></div><em>{time}</em></div>)}</div>
        </section>
        <section className="panel"><div className="panelHead"><div><h3>القصص المختارة</h3><p>مرتبة حسب الأهمية للسعودية</p></div><span className="count">٦</span></div>
          <div className="stories">{stories.map((s,i)=><div key={s}><span>{i+1}</span><p>{s}<small>{i<2?"مصدران موثوقان":"مصدر موثوق"}</small></p></div>)}</div><button className="wide">مراجعة كل القصص</button>
        </section>
      </div>
      <section className="notice"><TriangleAlert size={22}/><div><b>النشر التلقائي متوقف بأمان</b><p>لن تُنشر أي حلقة قبل الاستماع إليها والموافقة عليها من حساب المالك.</p></div><button>فتح إعدادات النشر</button></section>
    </section>
  </main>
}

function Stat({icon:Icon,label,value,note,good,warn}:{icon:typeof Activity,label:string,value:string,note:string,good?:boolean,warn?:boolean}) { return <div className="stat"><span className={warn?"warn":""}><Icon size={21}/></span><div><small>{label}</small><b>{value}</b><em className={good?"green":warn?"amber":""}>{note}</em></div></div> }
