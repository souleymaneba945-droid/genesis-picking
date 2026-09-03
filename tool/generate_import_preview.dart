import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_picking/features/import/data/import_source.dart';
import 'package:genesis_picking/features/import/data/parsers/pdf_parser.dart';
import 'package:genesis_picking/features/import/data/parsers/pdf_text_extractor.dart';

/// Génère un aperçu HTML autonome du résultat réel de l'extraction PDF —
/// mêmes données que ce qui atterrit en base (image, qté, emplacement,
/// référence, nom), pour vérifier un correctif sans repasser par
/// connexion → import à chaque fois.
void main() {
  test('generate extraction preview HTML', () async {
    const fileName = 'pickinglist--3139.pdf';
    final bytes = await File('C:\\Users\\NIANG\\Downloads\\$fileName').readAsBytes();
    final parser = PdfParser(textExtractor: SyncfusionPdfTextExtractor());
    final result = await parser.parse(
      ImportSource(bytes: Uint8List.fromList(bytes), fileName: fileName),
    );

    final total = result.produits.length;
    final avecImage = result.produits.where((p) => p.imageUrl != null).length;
    final avecEmplacement =
        result.produits.where((p) => p.emplacement != null).length;
    final avecRef = result.produits.where((p) => p.description != null).length;

    String esc(String? s) => (s ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;');

    final rows = StringBuffer();
    for (var i = 0; i < result.produits.length; i++) {
      final p = result.produits[i];
      final manque = <String>[];
      if (p.imageUrl == null) manque.add('image');
      if (p.emplacement == null) manque.add('emplacement');
      if (p.description == null) manque.add('référence');

      final statusClass = manque.isEmpty
          ? 'ok'
          : (manque.length == 1 && manque.first == 'emplacement' ? 'warn' : 'bad');
      final statusLabel = manque.isEmpty ? 'Complet' : 'Manque : ${manque.join(', ')}';

      rows.write('''
<li class="row" data-status="$statusClass" data-action="">
  <span class="idx">${i + 1}</span>
  <div class="thumb-stage">${p.imageUrl != null ? '<button type="button" class="thumb" aria-label="Agrandir la photo produit"><img src="${p.imageUrl}" alt="" loading="lazy"></button>' : '<span class="noimg">—</span>'}</div>
  <div class="qty">${p.quantiteDemandee ?? '—'}</div>
  <div class="loc">${esc(p.emplacement) == '' ? '<span class="muted">—</span>' : esc(p.emplacement)}</div>
  <div class="info">
    <div class="ref">${esc(p.description) == '' ? '<span class="muted">—</span>' : esc(p.description)}</div>
    <div class="name">${esc(p.nom)}</div>
  </div>
  <div class="row-right">
    <span class="dot dot--$statusClass" title="$statusLabel"></span>
    <span class="courier-tag" hidden></span>
    <div class="actions">
      <button type="button" class="act act--ok" data-action="valide" title="Validé" aria-label="Marquer validé">
        <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>
      </button>
      <button type="button" class="act act--bad" data-action="introuvable" title="Non trouvé" aria-label="Marquer non trouvé">
        <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>
      </button>
      <button type="button" class="act act--info" data-action="coursier" title="Envoyer à un coursier" aria-label="Envoyer à un coursier">
        <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7h11v9H3zM14 10h4l3 3v3h-7z"/><circle cx="7.5" cy="18" r="1.6"/><circle cx="17.5" cy="18" r="1.6"/></svg>
      </button>
    </div>
  </div>
</li>
''');
    }

    final html = '''
<title>Contrôle d'import</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@500;600&display=swap" rel="stylesheet">
<style>
  :root {
    --primary: #0b3d91;
    --primary-soft: #e7edf8;
    --success: #2e7d32;
    --success-soft: #e5f3e6;
    --warning: #b45309;
    --warning-soft: #fdf1de;
    --error: #b3261e;
    --error-soft: #fbe6e5;
    --neutral: #5b6472;
    --bg: #f6f7f9;
    --surface: #ffffff;
    --border: #e3e6ea;
    --text: #16181d;
    --text-muted: #6b7280;
    --mono: 'IBM Plex Mono', ui-monospace, monospace;
    --sans: 'IBM Plex Sans', system-ui, -apple-system, sans-serif;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --primary: #7ea6f2;
      --primary-soft: #1b2b4d;
      --success: #6fcf7a;
      --success-soft: #163420;
      --warning: #f2b04e;
      --warning-soft: #3a2a10;
      --error: #f2867e;
      --error-soft: #3a1a18;
      --neutral: #9aa4b2;
      --bg: #0e1116;
      --surface: #161a21;
      --border: #262b34;
      --text: #e7ebf1;
      --text-muted: #9aa4b2;
    }
  }
  :root[data-theme="dark"] {
    --primary: #7ea6f2;
    --primary-soft: #1b2b4d;
    --success: #6fcf7a;
    --success-soft: #163420;
    --warning: #f2b04e;
    --warning-soft: #3a2a10;
    --error: #f2867e;
    --error-soft: #3a1a18;
    --neutral: #9aa4b2;
    --bg: #0e1116;
    --surface: #161a21;
    --border: #262b34;
    --text: #e7ebf1;
    --text-muted: #9aa4b2;
  }

  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--bg);
    color: var(--text);
    font-family: var(--sans);
    -webkit-font-smoothing: antialiased;
  }
  a { color: inherit; }

  header {
    position: sticky;
    top: 0;
    z-index: 5;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 20px clamp(16px, 4vw, 40px);
  }
  .eyebrow {
    font-family: var(--mono);
    font-size: 12px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--primary);
    font-weight: 600;
  }
  h1 {
    margin: 4px 0 2px;
    font-size: clamp(20px, 2.6vw, 26px);
    font-weight: 700;
    text-wrap: balance;
  }
  .source {
    font-family: var(--mono);
    font-size: 13px;
    color: var(--text-muted);
  }

  .stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
    gap: 10px;
    margin-top: 16px;
    max-width: 720px;
  }
  .stat {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 10px 14px;
  }
  .stat .n {
    font-family: var(--mono);
    font-variant-numeric: tabular-nums;
    font-size: 22px;
    font-weight: 600;
    line-height: 1.1;
  }
  .stat .n.ok { color: var(--success); }
  .stat .n.warn { color: var(--warning); }
  .stat .label {
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  main {
    max-width: 980px;
    margin: 0 auto;
    padding: 20px clamp(16px, 4vw, 40px) 60px;
  }

  ul.list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }

  .row {
    position: relative;
    display: grid;
    grid-template-columns: 28px 96px 40px 72px 1fr auto;
    align-items: center;
    gap: 14px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 10px 14px;
    transition: background 0.25s ease;
  }
  .row[data-status="bad"] { border-color: color-mix(in srgb, var(--error) 40%, var(--border)); }
  .row[data-status="warn"] { border-color: color-mix(in srgb, var(--warning) 40%, var(--border)); }
  .row[data-action="valide"] { background: color-mix(in srgb, var(--success) 7%, var(--surface)); }
  .row[data-action="introuvable"] { background: color-mix(in srgb, var(--error) 7%, var(--surface)); }
  .row[data-action="coursier"] { background: color-mix(in srgb, var(--primary) 7%, var(--surface)); }

  .idx {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--text-muted);
    text-align: right;
  }

  /* Scène 3D : la perspective vit sur le parent, l'inclinaison sur le
     bouton lui-même (voir JS plus bas) — un vrai repère 3D CSS, pas un
     effet peint. */
  .thumb-stage {
    width: 96px;
    height: 40px;
    perspective: 400px;
  }
  .thumb {
    all: unset;
    display: block;
    width: 100%;
    height: 100%;
    border-radius: 6px;
    overflow: hidden;
    background: var(--bg);
    border: 1px solid var(--border);
    cursor: zoom-in;
    transform-style: preserve-3d;
    transition: transform 0.35s cubic-bezier(0.22, 1, 0.36, 1), box-shadow 0.35s ease;
    will-change: transform;
  }
  .thumb:hover, .thumb:focus-visible {
    box-shadow: 0 10px 22px -6px rgb(0 0 0 / 0.35);
    z-index: 1;
    position: relative;
  }
  .thumb:focus-visible { outline: 2px solid var(--primary); outline-offset: 2px; }
  .thumb img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    pointer-events: none;
    transform: translateZ(14px) scale(0.94);
  }
  .noimg { color: var(--text-muted); font-size: 12px; }

  .qty {
    font-family: var(--mono);
    font-variant-numeric: tabular-nums;
    font-weight: 600;
    text-align: center;
    background: var(--primary-soft);
    color: var(--primary);
    border-radius: 6px;
    padding: 4px 0;
    font-size: 13px;
  }
  .loc {
    font-family: var(--mono);
    font-size: 12px;
    font-weight: 600;
    color: var(--text-muted);
    text-align: center;
  }
  .info { min-width: 0; }
  .ref {
    font-family: var(--mono);
    font-size: 11px;
    color: var(--text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .name {
    font-size: 14px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .muted { color: var(--text-muted); }

  /* Point de complétude d'extraction (image/emplacement/référence) — un
     simple point avec infobulle, pour laisser la place aux 3 actions de
     picking qui sont maintenant le vrai centre d'attention de la ligne. */
  .row-right { display: flex; align-items: center; gap: 10px; }
  .dot {
    width: 8px;
    height: 8px;
    border-radius: 999px;
    flex: none;
  }
  .dot--ok { background: var(--success); }
  .dot--warn { background: var(--warning); }
  .dot--bad { background: var(--error); }

  .courier-tag {
    font-size: 11px;
    font-weight: 600;
    color: var(--primary);
    background: var(--primary-soft);
    padding: 4px 9px;
    border-radius: 999px;
    white-space: nowrap;
  }

  /* Les 3 options de picking : validé / introuvable / envoyer à un
     coursier — un seul actif à la fois par ligne, comme des cases à
     cocher exclusives. */
  .actions { display: flex; gap: 6px; }
  .act {
    all: unset;
    width: 32px;
    height: 32px;
    border-radius: 999px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    background: var(--bg);
    border: 1.5px solid var(--border);
    color: var(--text-muted);
    transition: background 0.15s ease, border-color 0.15s ease, color 0.15s ease, transform 0.15s ease;
  }
  .act:hover { transform: translateY(-1px); }
  .act:focus-visible { outline: 2px solid var(--primary); outline-offset: 2px; }
  .act--ok.is-active { background: var(--success); border-color: var(--success); color: #fff; }
  .act--bad.is-active { background: var(--error); border-color: var(--error); color: #fff; }
  .act--info.is-active { background: var(--primary); border-color: var(--primary); color: #fff; }

  /* position: fixed — positionné en JS au clic (voir openCourierPop),
     relatif à la fenêtre, pas à une ligne : un seul nœud DOM pour toute
     la page, jamais un par ligne. */
  .courier-pop {
    position: fixed;
    z-index: 30;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    box-shadow: 0 14px 32px -10px rgb(0 0 0 / 0.28);
    padding: 6px;
    display: flex;
    flex-direction: column;
    min-width: 140px;
  }
  .courier-pop[hidden] { display: none; }
  .courier-pop-title {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 4px 8px 6px;
  }
  .courier-opt {
    all: unset;
    box-sizing: border-box;
    width: 100%;
    padding: 7px 8px;
    border-radius: 6px;
    font-size: 13px;
    cursor: pointer;
  }
  .courier-opt:hover, .courier-opt:focus-visible { background: var(--primary-soft); color: var(--primary); }

  @media (max-width: 640px) {
    .row {
      grid-template-columns: 24px 72px 1fr;
      grid-template-areas:
        "idx thumb info"
        "idx thumb right"
        "qty loc loc";
    }
    .idx { grid-area: idx; }
    .thumb-stage { grid-area: thumb; width: 72px; }
    .info { grid-area: info; }
    .row-right { grid-area: right; justify-self: start; }
    .qty, .loc { display: none; }
  }

  /* Plein écran — pas une boîte : toute la fenêtre, fond noir. */
  .lightbox {
    position: fixed;
    inset: 0;
    z-index: 50;
    background: rgba(4, 6, 10, 0.96);
    display: none;
    align-items: center;
    justify-content: center;
    touch-action: none;
    overscroll-behavior: contain;
  }
  .lightbox.is-open { display: flex; }
  .lightbox-surface {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    cursor: grab;
  }
  .lightbox-surface.is-panning { cursor: grabbing; }
  .lightbox img {
    max-width: 92vw;
    max-height: 88vh;
    border-radius: 14px;
    box-shadow: 0 30px 80px -20px rgb(0 0 0 / 0.7);
    transform-origin: center center;
    will-change: transform;
    user-select: none;
    -webkit-user-drag: none;
  }
  .lightbox-close {
    all: unset;
    position: absolute;
    top: max(16px, env(safe-area-inset-top));
    right: max(16px, env(safe-area-inset-right));
    width: 44px;
    height: 44px;
    border-radius: 999px;
    background: rgba(255, 255, 255, 0.12);
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 22px;
    cursor: pointer;
    z-index: 1;
  }
  .lightbox-close:hover { background: rgba(255, 255, 255, 0.22); }
  .lightbox-hint {
    position: absolute;
    bottom: max(18px, env(safe-area-inset-bottom));
    left: 50%;
    transform: translateX(-50%);
    color: rgba(255, 255, 255, 0.55);
    font-size: 12px;
    font-family: var(--mono);
    letter-spacing: 0.02em;
  }

  @media (prefers-reduced-motion: reduce) {
    .thumb, .lightbox img { transition: none !important; }
  }
</style>

<header>
  <div class="eyebrow">GENESIS PICKING · Contrôle d'import</div>
  <h1>Résultat réel de l'extraction PDF</h1>
  <div class="source">$fileName — régénéré à chaque correctif, sans reconnexion à l'appli</div>
  <div class="stats">
    <div class="stat"><div class="n">$total</div><div class="label">Produits détectés</div></div>
    <div class="stat"><div class="n ${avecImage == total ? 'ok' : 'warn'}">$avecImage/$total</div><div class="label">Avec image</div></div>
    <div class="stat"><div class="n ${avecEmplacement == total ? 'ok' : 'warn'}">$avecEmplacement/$total</div><div class="label">Avec emplacement</div></div>
    <div class="stat"><div class="n ${avecRef == total ? 'ok' : 'warn'}">$avecRef/$total</div><div class="label">Avec référence</div></div>
  </div>
</header>

<main>
  <ul class="list">
    $rows
  </ul>
</main>

<!-- Un seul popover coursier, partagé et repositionné au clic — jamais
     un par ligne : structurellement impossible d'en avoir deux ouverts
     à la fois. -->
<div class="courier-pop" id="courierPop" hidden>
  <div class="courier-pop-title">Envoyer à</div>
  <button type="button" class="courier-opt" data-name="Thierno">Thierno</button>
  <button type="button" class="courier-opt" data-name="Moussa">Moussa</button>
  <button type="button" class="courier-opt" data-name="Ibrahima">Ibrahima</button>
  <button type="button" class="courier-opt" data-name="Fatou">Fatou</button>
</div>

<div class="lightbox" id="lightbox" role="dialog" aria-modal="true" aria-label="Photo produit en plein écran">
  <button type="button" class="lightbox-close" id="lightboxClose" aria-label="Fermer">✕</button>
  <div class="lightbox-surface" id="lightboxSurface">
    <img id="lightboxImg" src="" alt="">
  </div>
  <div class="lightbox-hint">Molette ou pincer pour zoomer · glisser pour déplacer · Échap pour fermer</div>
</div>

<script>
(function () {
  // Inclinaison 3D des vignettes au survol de la souris — vrai repère
  // CSS 3D (perspective + rotateX/rotateY), pas un habillage visuel.
  document.querySelectorAll('.thumb').forEach(function (el) {
    el.addEventListener('mousemove', function (e) {
      var r = el.getBoundingClientRect();
      var px = (e.clientX - r.left) / r.width - 0.5;
      var py = (e.clientY - r.top) / r.height - 0.5;
      el.style.transform = 'rotateX(' + (py * -14) + 'deg) rotateY(' + (px * 14) + 'deg) scale(1.06)';
    });
    el.addEventListener('mouseleave', function () {
      el.style.transform = '';
    });
  });

  // Zoom plein écran — jamais une petite boîte : toute la fenêtre.
  var lightbox = document.getElementById('lightbox');
  var lightboxImg = document.getElementById('lightboxImg');
  var lightboxSurface = document.getElementById('lightboxSurface');
  var scale = 1, originX = 0, originY = 0;
  var panning = false, panStartX = 0, panStartY = 0, originStartX = 0, originStartY = 0;

  function applyTransform() {
    lightboxImg.style.transform = 'translate(' + originX + 'px,' + originY + 'px) scale(' + scale + ')';
  }
  function resetZoom() {
    scale = 1; originX = 0; originY = 0;
    applyTransform();
  }
  function openLightbox(src) {
    lightboxImg.src = src;
    resetZoom();
    lightbox.classList.add('is-open');
    document.body.style.overflow = 'hidden';
  }
  function closeLightbox() {
    lightbox.classList.remove('is-open');
    lightboxImg.src = '';
    document.body.style.overflow = '';
  }

  document.querySelectorAll('.thumb').forEach(function (btn) {
    var img = btn.querySelector('img');
    if (!img) return;
    btn.addEventListener('click', function () { openLightbox(img.src); });
  });
  document.getElementById('lightboxClose').addEventListener('click', closeLightbox);
  lightbox.addEventListener('click', function (e) { if (e.target === lightbox) closeLightbox(); });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && lightbox.classList.contains('is-open')) closeLightbox();
  });

  lightboxSurface.addEventListener('wheel', function (e) {
    if (!lightbox.classList.contains('is-open')) return;
    e.preventDefault();
    var next = scale + (e.deltaY < 0 ? 0.18 : -0.18);
    scale = Math.min(5, Math.max(1, next));
    if (scale === 1) { originX = 0; originY = 0; }
    applyTransform();
  }, { passive: false });

  lightboxSurface.addEventListener('mousedown', function (e) {
    if (scale <= 1) return;
    panning = true;
    lightboxSurface.classList.add('is-panning');
    panStartX = e.clientX; panStartY = e.clientY;
    originStartX = originX; originStartY = originY;
  });
  window.addEventListener('mousemove', function (e) {
    if (!panning) return;
    originX = originStartX + (e.clientX - panStartX);
    originY = originStartY + (e.clientY - panStartY);
    applyTransform();
  });
  window.addEventListener('mouseup', function () {
    panning = false;
    lightboxSurface.classList.remove('is-panning');
  });

  // Pincement tactile.
  var pinchStartDist = null, pinchStartScale = 1;
  lightboxSurface.addEventListener('touchstart', function (e) {
    if (e.touches.length === 2) {
      var dx = e.touches[0].clientX - e.touches[1].clientX;
      var dy = e.touches[0].clientY - e.touches[1].clientY;
      pinchStartDist = Math.hypot(dx, dy);
      pinchStartScale = scale;
    } else if (e.touches.length === 1 && scale > 1) {
      panning = true;
      panStartX = e.touches[0].clientX; panStartY = e.touches[0].clientY;
      originStartX = originX; originStartY = originY;
    }
  }, { passive: true });
  lightboxSurface.addEventListener('touchmove', function (e) {
    if (e.touches.length === 2 && pinchStartDist) {
      var dx = e.touches[0].clientX - e.touches[1].clientX;
      var dy = e.touches[0].clientY - e.touches[1].clientY;
      var dist = Math.hypot(dx, dy);
      scale = Math.min(5, Math.max(1, pinchStartScale * (dist / pinchStartDist)));
      applyTransform();
    } else if (e.touches.length === 1 && panning) {
      originX = originStartX + (e.touches[0].clientX - panStartX);
      originY = originStartY + (e.touches[0].clientY - panStartY);
      applyTransform();
    }
  }, { passive: true });
  lightboxSurface.addEventListener('touchend', function () {
    pinchStartDist = null;
    panning = false;
  });

  // Les 3 options de picking par ligne — validé / introuvable / envoyer
  // à un coursier, exclusives entre elles (cliquer l'option déjà active
  // la désélectionne). Un seul popover coursier partagé par toute la
  // page (voir #courierPop dans le HTML) : il n'apparaît QUE quand on
  // clique l'icône coursier d'une ligne, jamais ailleurs, et il n'y en a
  // jamais deux ouverts en même temps puisqu'il n'existe qu'un seul nœud.
  var courierPop = document.getElementById('courierPop');
  var courierPopRow = null; // ligne pour laquelle le popover est ouvert

  function setAction(row, action) {
    row.setAttribute('data-action', action);
    row.querySelectorAll('.act').forEach(function (b) {
      b.classList.toggle('is-active', b.getAttribute('data-action') === action);
    });
    if (action !== 'coursier') {
      var tag = row.querySelector('.courier-tag');
      tag.hidden = true;
      tag.textContent = '';
    }
  }

  function openCourierPop(anchorBtn, row) {
    courierPopRow = row;
    var r = anchorBtn.getBoundingClientRect();
    courierPop.hidden = false;
    // Placé sous l'icône coursier cliquée ; recalé si ça dépasse à droite
    // ou en bas de la fenêtre.
    var popWidth = courierPop.offsetWidth || 150;
    var left = Math.min(r.right - popWidth, window.innerWidth - popWidth - 8);
    var top = r.bottom + 6;
    if (top + courierPop.offsetHeight > window.innerHeight) {
      top = r.top - courierPop.offsetHeight - 6;
    }
    courierPop.style.left = Math.max(8, left) + 'px';
    courierPop.style.top = Math.max(8, top) + 'px';
  }

  function closeCourierPop() {
    courierPop.hidden = true;
    courierPopRow = null;
  }

  document.querySelectorAll('.row').forEach(function (row) {
    row.querySelectorAll('.act').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        var action = btn.getAttribute('data-action');
        var already = row.getAttribute('data-action') === action;

        if (action === 'coursier') {
          if (already) {
            setAction(row, '');
            closeCourierPop();
            return;
          }
          openCourierPop(btn, row);
          return;
        }

        closeCourierPop();
        setAction(row, already ? '' : action);
      });
    });
  });

  courierPop.querySelectorAll('.courier-opt').forEach(function (opt) {
    opt.addEventListener('click', function (e) {
      e.stopPropagation();
      if (!courierPopRow) return;
      setAction(courierPopRow, 'coursier');
      var tag = courierPopRow.querySelector('.courier-tag');
      tag.hidden = false;
      tag.textContent = '→ ' + opt.getAttribute('data-name');
      closeCourierPop();
    });
  });

  courierPop.addEventListener('click', function (e) { e.stopPropagation(); });
  document.addEventListener('click', closeCourierPop);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') closeCourierPop();
  });
  window.addEventListener('scroll', closeCourierPop, true);
})();
</script>
''';

    final outFile = File(
      r'C:\Users\NIANG\AppData\Local\Temp\claude\c--Users-NIANG-Downloads-gp-src\08463852-f7da-4525-ab43-b938c3e169d4\scratchpad\import_preview.html',
    );
    await outFile.writeAsString(html);
    // ignore: avoid_print
    print('written: ${outFile.path} (${html.length} chars)');
  });
}
