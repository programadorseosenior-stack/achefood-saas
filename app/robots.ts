import type { MetadataRoute } from "next";
export default function robots():MetadataRoute.Robots{return{rules:[{userAgent:"*",allow:["/","/login","/cadastro","/planos","/termos","/privacidade"],disallow:["/app/","/admin/"]}],sitemap:`${process.env.NEXT_PUBLIC_SITE_URL||"http://localhost:3000"}/sitemap.xml`}}
