import "@/components/brand/brand.css";
import "@/components/dashboard/dashboard.css";
import { ClientDashboard } from "@/components/dashboard/client-dashboard";
export const metadata={title:"Painel do cliente",robots:{index:false,follow:false}};
export default function Dashboard(){return <ClientDashboard/>}
