/* IOT CITY — globo 3D (Three.js / WebGL).
   Terra noturna de alta definição (texturas NASA Black Marble 2016 e Blue Marble, domínio público, 4096×2048),
   atmosfera, malha de latitude/longitude, faixa de varredura, nuvens, rotas de dados com pulsos, polos de rede
   e anéis orbitais. Gira sozinho e acompanha o arrasto da órbita dos cartões.
   Se o WebGL não existir ou algo falhar, a imagem terra.webp continua no lugar. */
import * as THREE from 'three';

const caixa = document.getElementById('world');
const reduz = matchMedia('(prefers-reduced-motion: reduce)').matches;
const movel = matchMedia('(max-width: 640px)').matches;
const ESCALA = 1.6; // o canvas é 160% da caixa do globo: sobra espaço para atmosfera e anéis

function temWebGL() {
  try { const c = document.createElement('canvas'); return !!(c.getContext('webgl2') || c.getContext('webgl')); } catch (_) { return false; }
}
if (caixa && temWebGL()) iniciar().catch(e => console.warn('IOT CITY: globo 3D indisponível, mantendo a imagem', e));

/* latitude/longitude → ponto na esfera, no mesmo mapeamento UV da SphereGeometry */
function ponto(lat, lon, r = 1) {
  const f = THREE.MathUtils.degToRad(lat), p = THREE.MathUtils.degToRad(lon + 180);
  return new THREE.Vector3(-Math.cos(p) * Math.cos(f) * r, Math.sin(f) * r, Math.sin(p) * Math.cos(f) * r);
}

// polos da rede (o Brasil no centro das rotas)
const POLOS = {
  sp: [-23.55, -46.63], cwb: [-25.43, -49.27], rio: [-22.9, -43.2], bsb: [-15.8, -47.9], rec: [-8.05, -34.9], for: [-3.73, -38.5],
  mao: [-3.1, -60.0], poa: [-30.03, -51.23], bue: [-34.6, -58.4], scl: [-33.45, -70.67], lim: [-12.05, -77.04], bog: [4.71, -74.07],
  mex: [19.43, -99.13], mia: [25.76, -80.19], nyc: [40.71, -74.0], sfo: [37.77, -122.42], lis: [38.72, -9.14], lon: [51.5, -0.12],
  mad: [40.4, -3.7], fra: [50.11, 8.68], jnb: [-26.2, 28.05], dxb: [25.2, 55.27], tyo: [35.68, 139.69], sin: [1.35, 103.82],
};
const ROTAS = [['sp', 'nyc'], ['sp', 'lis'], ['sp', 'mia'], ['sp', 'bue'], ['sp', 'lim'], ['sp', 'mex'], ['cwb', 'fra'], ['cwb', 'scl'],
  ['cwb', 'poa'], ['rio', 'lon'], ['rio', 'jnb'], ['bsb', 'mao'], ['bsb', 'bog'], ['rec', 'mad'], ['for', 'mia'], ['bsb', 'rec'],
  ['nyc', 'lon'], ['mia', 'sfo'], ['lis', 'dxb'], ['fra', 'sin'], ['sp', 'cwb'], ['sp', 'rio'], ['mao', 'bog'], ['bue', 'scl']];

const VERT_ESFERA = /* glsl */`
  varying vec2 vUv; varying vec3 vNw; varying vec3 vW; varying vec3 vObj;
  void main(){
    vUv = uv; vObj = position;
    vNw = normalize(mat3(modelMatrix) * normal);
    vec4 w = modelMatrix * vec4(position, 1.0); vW = w.xyz;
    gl_Position = projectionMatrix * viewMatrix * w;
  }`;

async function iniciar() {
  const canvas = document.createElement('canvas');
  canvas.className = 'globo3d-canvas'; canvas.setAttribute('aria-hidden', 'true');
  caixa.appendChild(canvas);
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, movel ? 1.5 : 2));
  renderer.setClearColor(0x000000, 0);

  const cena = new THREE.Scene();
  // câmera a uma distância em que a esfera (raio 1) ocupa 0,94 da caixa — o mesmo tamanho da imagem antiga
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  const t = Math.tan(THREE.MathUtils.degToRad(15)) * (0.94 / ESCALA);
  camera.position.set(0, 0, 1 / Math.sin(Math.atan(t)));

  const carregador = new THREE.TextureLoader();
  const ani = renderer.capabilities.getMaxAnisotropy();
  const tex = u => new Promise((ok, erro) => carregador.load(u, x => { x.anisotropy = ani; ok(x); }, undefined, erro));
  const [tNoite, tDia, tNuvens] = await Promise.all([tex('terra_noite.webp'), tex('terra_dia.webp'), tex('terra_nuvens.webp')]);

  const U = { uT: { value: 0 }, uLuz: { value: new THREE.Vector3(-0.55, 0.35, 0.75).normalize() } };

  // eixo inclinado; "giro" é a rotação diária (Terra + nuvens + rotas giram juntas)
  const eixo = new THREE.Group(); eixo.rotation.z = THREE.MathUtils.degToRad(16); eixo.rotation.x = THREE.MathUtils.degToRad(10); cena.add(eixo);
  const giro = new THREE.Group(); eixo.add(giro);
  const LON_INICIAL = -52; // começa mostrando o Brasil
  const giroBase = -THREE.MathUtils.degToRad(LON_INICIAL + 90);

  const seg = movel ? 96 : 160;
  const terra = new THREE.Mesh(new THREE.SphereGeometry(1, seg, seg), new THREE.ShaderMaterial({
    uniforms: { ...U, tNoite: { value: tNoite }, tDia: { value: tDia } },
    vertexShader: VERT_ESFERA,
    fragmentShader: /* glsl */`
      uniform sampler2D tNoite, tDia; uniform float uT; uniform vec3 uLuz;
      varying vec2 vUv; varying vec3 vNw; varying vec3 vW; varying vec3 vObj;
      void main(){
        vec3 n = normalize(vNw), v = normalize(cameraPosition - vW);
        vec3 dia = texture2D(tDia, vUv).rgb, noite = texture2D(tNoite, vUv).rgb;
        float luz = smoothstep(-0.25, 0.65, dot(n, uLuz));
        // relevo do dia em azul profundo (visual tecnológico), mais claro do lado iluminado
        float terraF = smoothstep(0.02, 0.12, dia.r + dia.g - dia.b * 1.1);
        vec3 oceano = vec3(0.006, 0.03, 0.085) + vec3(0.015, 0.08, 0.19) * luz;
        vec3 solo = dia * vec3(0.30, 0.62, 0.78) * (0.42 + 1.15 * luz) + vec3(0.0, 0.035, 0.06);
        vec3 cor = mix(oceano, solo, terraF);
        // luzes das cidades em âmbar, mais fortes no lado escuro
        vec3 cidades = pow(noite, vec3(1.7)) * vec3(1.7, 1.12, 0.55) * 2.4 * (1.0 - luz * 0.55);
        cor += cidades;
        // malha de latitude/longitude (15°)
        vec2 g = vec2(vUv.x * 24.0, vUv.y * 12.0);
        vec2 d = abs(fract(g - 0.5) - 0.5) / fwidth(g);
        float linha = 1.0 - min(min(d.x, d.y), 1.0);
        cor += vec3(0.12, 0.62, 1.0) * linha * 0.16;
        // faixa de varredura subindo e descendo
        float sc = exp(-pow((vObj.y - sin(uT * 0.32) * 0.95) * 10.0, 2.0));
        cor += vec3(0.25, 0.9, 1.0) * sc * (0.10 + linha * 0.5);
        // borda (fresnel) em ciano
        float fr = pow(1.0 - max(dot(n, v), 0.0), 3.2);
        cor += vec3(0.12, 0.6, 1.0) * fr * 0.7;
        gl_FragColor = vec4(cor, 1.0);
      }`,
  }));
  giro.add(terra);

  // nuvens finas, girando um pouco mais rápido
  const nuvens = new THREE.Mesh(new THREE.SphereGeometry(1.012, seg / 2, seg / 2), new THREE.ShaderMaterial({
    uniforms: { ...U, tNuvens: { value: tNuvens } }, transparent: true, depthWrite: false,
    vertexShader: VERT_ESFERA,
    fragmentShader: /* glsl */`
      uniform sampler2D tNuvens; uniform vec3 uLuz; varying vec2 vUv; varying vec3 vNw;
      void main(){
        float c = texture2D(tNuvens, vUv).r; float luz = smoothstep(-0.2, 0.7, dot(normalize(vNw), uLuz));
        gl_FragColor = vec4(vec3(0.7, 0.88, 1.0) * (0.25 + luz * 0.75), c * (0.10 + luz * 0.28));
      }`,
  }));
  giro.add(nuvens);

  // atmosfera (halo por fora da esfera)
  const atm = new THREE.Mesh(new THREE.SphereGeometry(1.0, 96, 96), new THREE.ShaderMaterial({
    side: THREE.BackSide, blending: THREE.AdditiveBlending, transparent: true, depthWrite: false,
    vertexShader: /* glsl */`varying vec3 vN; void main(){ vN = normalize(normalMatrix * normal); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
    fragmentShader: /* glsl */`varying vec3 vN; void main(){ float i = pow(max(0.0, 0.66 - dot(vN, vec3(0.0, 0.0, 1.0))), 4.0); gl_FragColor = vec4(vec3(0.16, 0.6, 1.0) * i * 1.7, i); }`,
  }));
  atm.scale.setScalar(1.13); cena.add(atm);

  // rotas de dados: arco com trilha fraca e um pulso (cometa) correndo de um polo ao outro
  const matRota = new THREE.ShaderMaterial({
    uniforms: { uT: U.uT }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */`attribute float aOff; varying vec2 vUv; varying float vOff; void main(){ vUv = uv; vOff = aOff; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
    fragmentShader: /* glsl */`
      uniform float uT; varying vec2 vUv; varying float vOff;
      void main(){
        float cab = fract(uT * 0.22 + vOff) * 1.6 - 0.3;
        float d = vUv.x - cab;
        float cometa = smoothstep(-0.30, 0.0, d) * (1.0 - smoothstep(0.0, 0.015, d));
        float pontas = smoothstep(0.0, 0.06, vUv.x) * smoothstep(1.0, 0.94, vUv.x);
        vec3 cor = mix(vec3(0.1, 0.65, 1.0), vec3(0.85, 1.0, 1.0), cometa);
        gl_FragColor = vec4(cor * (0.22 + cometa * 2.2) * pontas, 1.0);
      }`,
  });
  ROTAS.forEach(([a, b], i) => {
    const A = ponto(...POLOS[a]), B = ponto(...POLOS[b]);
    const ang = A.angleTo(B), alt = 0.05 + ang * 0.16, pts = [];
    for (let k = 0; k <= 64; k++) {
      const s = k / 64, q = new THREE.Vector3().copy(A).lerp(B, s).normalize(); // aproximação do grande círculo
      pts.push(q.multiplyScalar(1.004 + Math.sin(Math.PI * s) * alt));
    }
    const geo = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 80, movel ? 0.0045 : 0.0035, 6, false);
    geo.setAttribute('aOff', new THREE.BufferAttribute(new Float32Array(geo.attributes.position.count).fill((i * 0.137) % 1), 1));
    giro.add(new THREE.Mesh(geo, matRota));
  });

  // polos: pontos brilhantes pulsando + ondas na superfície
  const nomes = Object.keys(POLOS), pos = new Float32Array(nomes.length * 3), fase = new Float32Array(nomes.length);
  nomes.forEach((k, i) => { ponto(...POLOS[k], 1.006).toArray(pos, i * 3); fase[i] = Math.random() * 6.28; });
  const gPolos = new THREE.BufferGeometry();
  gPolos.setAttribute('position', new THREE.BufferAttribute(pos, 3)); gPolos.setAttribute('aFase', new THREE.BufferAttribute(fase, 1));
  const uTam = { value: 10 };
  giro.add(new THREE.Points(gPolos, new THREE.ShaderMaterial({
    uniforms: { uT: U.uT, uTam }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */`uniform float uT, uTam; attribute float aFase; varying float vP;
      void main(){ vP = 0.75 + 0.25 * sin(uT * 2.6 + aFase); gl_PointSize = uTam * vP; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
    fragmentShader: /* glsl */`varying float vP; void main(){ float d = length(gl_PointCoord - 0.5);
      float a = smoothstep(0.5, 0.0, d), nucleo = smoothstep(0.14, 0.0, d);
      gl_FragColor = vec4(mix(vec3(0.2, 0.8, 1.0), vec3(1.0), nucleo) * (a * 0.9 + nucleo) * vP, 1.0); }`,
  })));
  const ondas = ['sp', 'cwb', 'nyc', 'lon', 'tyo'].map((k, i) => {
    const m = new THREE.Mesh(new THREE.RingGeometry(0.018, 0.024, 48), new THREE.MeshBasicMaterial({ color: 0x5fe8ff, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    const p = ponto(...POLOS[k], 1.003); m.position.copy(p); m.lookAt(p.clone().multiplyScalar(2)); m.userData.off = i * 0.21;
    giro.add(m); return m;
  });

  // anéis orbitais com satélites e uma nuvem de partículas de dados
  const orbitas = new THREE.Group(); cena.add(orbitas);
  const aneis = [[1.34, 74, -12, 0x37d9ff, 0.38], [1.46, 64, 28, 0x8a7bff, 0.26]].map(([r, rx, rz, cor, op], i) => {
    const g = new THREE.Group(); g.rotation.x = THREE.MathUtils.degToRad(rx); g.rotation.z = THREE.MathUtils.degToRad(rz); orbitas.add(g);
    g.add(new THREE.Mesh(new THREE.RingGeometry(r - 0.0025, r + 0.0025, 256), new THREE.MeshBasicMaterial({ color: cor, transparent: true, opacity: op, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending })));
    const sat = new THREE.Mesh(new THREE.SphereGeometry(0.016, 16, 16), new THREE.MeshBasicMaterial({ color: 0xe8fbff }));
    const brilho = new THREE.Mesh(new THREE.SphereGeometry(0.05, 16, 16), new THREE.MeshBasicMaterial({ color: cor, transparent: true, opacity: 0.35, depthWrite: false, blending: THREE.AdditiveBlending }));
    sat.add(brilho); g.add(sat);
    return { g, sat, r, vel: i ? -0.23 : 0.31, fase: i * 2.1 };
  });
  const NP = movel ? 450 : 900, pp = new Float32Array(NP * 3);
  for (let i = 0; i < NP; i++) {
    const a = Math.random() * Math.PI * 2, r = 1.22 + Math.random() * 0.32, h = (Math.random() - 0.5) * 0.08;
    pp[i * 3] = Math.cos(a) * r; pp[i * 3 + 1] = h; pp[i * 3 + 2] = Math.sin(a) * r;
  }
  const gPart = new THREE.BufferGeometry(); gPart.setAttribute('position', new THREE.BufferAttribute(pp, 3));
  const particulas = new THREE.Points(gPart, new THREE.PointsMaterial({ color: 0x6fdcff, size: 0.012, transparent: true, opacity: 0.55, depthWrite: false, blending: THREE.AdditiveBlending }));
  particulas.rotation.x = THREE.MathUtils.degToRad(76); particulas.rotation.z = THREE.MathUtils.degToRad(-12); orbitas.add(particulas);

  // tamanho acompanha a caixa do globo
  function medir() {
    const w = caixa.clientWidth * ESCALA, h = caixa.clientHeight * ESCALA; if (!w || !h) return;
    renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
    uTam.value = h * renderer.getPixelRatio() * 0.016;
  }
  new ResizeObserver(medir).observe(caixa); medir();

  const relogio = new THREE.Clock(); let pronto = false;
  function quadro() {
    relogio.getDelta(); const tempo = relogio.elapsedTime;
    U.uT.value = tempo;
    const arrasto = window.IOTCity && window.IOTCity.getAngle ? window.IOTCity.getAngle() * 0.55 : 0;
    giro.rotation.y = giroBase + (reduz ? 0 : tempo * 0.06) + arrasto;
    nuvens.rotation.y = reduz ? 0 : tempo * 0.012;
    ondas.forEach(m => { const f = (tempo * 0.45 + m.userData.off) % 1; m.scale.setScalar(1 + f * 3.2); m.material.opacity = (1 - f) * 0.85; });
    aneis.forEach(a => { const ang = a.fase + (reduz ? 0 : tempo * a.vel); a.sat.position.set(Math.cos(ang) * a.r, Math.sin(ang) * a.r, 0); });
    particulas.rotation.y = reduz ? 0 : tempo * 0.02;
    renderer.render(cena, camera);
    if (!pronto) { pronto = true; caixa.classList.add('globo3d'); }
    requestAnimationFrame(quadro);
  }
  requestAnimationFrame(quadro);
}
