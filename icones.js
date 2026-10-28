/* IOT CITY — ícones dos botões (traço, 24x24). Usado pelo portal e pela administração. */
window.IOT_ICONES = {
  materiais: { nome: 'Materiais / ERP', p: '<path d="m12 2 9 5-9 5-9-5 9-5Z"/><path d="M3 7v10l9 5 9-5V7M12 12v10"/>' },
  financeiro: { nome: 'Financeiro', p: '<rect x="2" y="5" width="20" height="15" rx="3"/><path d="M2 10h20M12 12v6m-2-4h4M6 2v3m12-3v3"/>' },
  semaforos: { nome: 'Semáforos', p: '<rect x="7" y="2" width="10" height="20" rx="3"/><circle cx="12" cy="6.5" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="12" cy="17.5" r="1.5"/>' },
  iluminacao: { nome: 'Iluminação', p: '<path d="M9 18h6m-6 3h6M8.7 14.5a6.5 6.5 0 1 1 6.6 0L14.7 18H9.3l-.6-3.5Z"/><path d="M12 1v2M3 10H1m22 0h-2M4 3l2 2m14-2-2 2"/>' },
  raiox: { nome: 'Saúde / Raio-X', p: '<path d="M21 9.5c0 5-9 11-9 11S3 14.5 3 9.5a5 5 0 0 1 9-3.2 5 5 0 0 1 9 3.2Z"/><path d="M3 12h4l2-3 3 7 2-4h7"/>' },
  hubbot: { nome: 'Robô / Atendimento', p: '<rect x="3" y="6" width="18" height="14" rx="5"/><circle cx="9" cy="12" r="1.2"/><circle cx="15" cy="12" r="1.2"/><path d="M12 2v4m0-4H9m2 14h2"/>' },
  cidade: { nome: 'Cidade', p: '<path d="M2 22h20M5 22V10h5v12m4 0V5h5v17M7 13v2m0 3v1m9-11v2m0 3v2m0 3v1"/>' },
  bi: { nome: 'BI / Gráficos', p: '<path d="M3 21V13h4v8m3 0V8h4v13m3 0V3h4v18"/>' },
  mapa: { nome: 'Mapa', p: '<path d="m9 4-6 2v14l6-2 6 2 6-2V4l-6 2-6-2Z"/><path d="M9 4v14m6-12v14"/>' },
  alerta: { nome: 'Alertas', p: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4m0 4h.01"/>' },
  escudo: { nome: 'Segurança', p: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>' },
  documento: { nome: 'Documentos', p: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6M8 13h8M8 17h8"/>' },
  apresentacao: { nome: 'Apresentação', p: '<rect x="2" y="3" width="20" height="13" rx="2"/><path d="M12 16v5m-4 0h8M7 12l3-3 3 2 4-4"/>' },
  nuvem: { nome: 'Nuvem / API', p: '<path d="M17.5 19a4.5 4.5 0 1 0-1.4-8.8A6 6 0 0 0 4.3 12 3.5 3.5 0 0 0 5.5 19Z"/>' },
  chip: { nome: 'Dispositivo IoT', p: '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4m6-4v4M9 18v4m6-4v4M2 9h4m-4 6h4m12-6h4m-4 6h4"/><rect x="10" y="10" width="4" height="4"/>' },
  energia: { nome: 'Energia', p: '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8Z"/>' },
  usuarios: { nome: 'Pessoas', p: '<circle cx="9" cy="8" r="3.5"/><path d="M2 21c0-3.9 3.1-7 7-7s7 3.1 7 7M17 11a3 3 0 1 0 0-6M22 21c0-3-1.8-5.6-4.5-6.6"/>' },
  engrenagem: { nome: 'Configuração', p: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3m0 14v3M2 12h3m14 0h3M4.9 4.9 7 7m10 10 2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/>' },
  globo: { nome: 'Site / Web', p: '<circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20"/>' },
  grade: { nome: 'Genérico', p: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>' },
};
window.iotIcone = function (k) {
  const i = window.IOT_ICONES[k] || window.IOT_ICONES.grade;
  return '<svg viewBox="0 0 24 24" aria-hidden="true">' + i.p + '</svg>';
};
window.IOT_SUPA = { url: 'https://ssssvouyqzvqebykoouh.supabase.co', key: 'sb_publishable_O6kuFJ7F_9EaGFpwdynmxA_Mj3O-qpU' };
