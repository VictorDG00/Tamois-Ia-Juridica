/* Tamois — shared scripts: theme, nav highlight, tweaks panel */
(function () {
  const STORAGE = {
    theme: 'tamois.theme',
    density: 'tamois.density',
    accent: 'tamois.accent',
  };

  function applyPrefs() {
    const html = document.documentElement;
    html.setAttribute('data-theme',   localStorage.getItem(STORAGE.theme)   || 'dark');
    html.setAttribute('data-density', localStorage.getItem(STORAGE.density) || 'default');
    html.setAttribute('data-accent',  localStorage.getItem(STORAGE.accent)  || 'crimson');
  }
  applyPrefs();

  document.addEventListener('DOMContentLoaded', () => {
    // theme toggle
    const t = document.getElementById('themeToggle');
    if (t) {
      const opts = t.querySelectorAll('.theme-opt');
      const cur = localStorage.getItem(STORAGE.theme) || 'dark';
      opts.forEach(o => o.classList.toggle('active', o.dataset.t === cur));
      opts.forEach(opt => opt.addEventListener('click', () => {
        const v = opt.dataset.t;
        document.documentElement.setAttribute('data-theme', v);
        localStorage.setItem(STORAGE.theme, v);
        opts.forEach(o => o.classList.toggle('active', o.dataset.t === v));
      }));
    }

    // active nav (based on body data attr or filename)
    const cur = document.body.dataset.page;
    if (cur) {
      document.querySelectorAll('.nav-links a').forEach(a => {
        if (a.dataset.page === cur) a.classList.add('active');
      });
    }

    // tweaks panel
    const tw = document.getElementById('tweaks');
    if (tw) {
      tw.querySelectorAll('.tweaks-seg').forEach(seg => {
        const key = seg.dataset.key;
        const stored = localStorage.getItem('tamois.' + key) || seg.dataset.default;
        seg.querySelectorAll('button').forEach(b => b.classList.toggle('active', b.dataset.v === stored));
        document.documentElement.setAttribute('data-' + key, stored);
        seg.addEventListener('click', e => {
          const btn = e.target.closest('button'); if (!btn) return;
          const v = btn.dataset.v;
          localStorage.setItem('tamois.' + key, v);
          document.documentElement.setAttribute('data-' + key, v);
          seg.querySelectorAll('button').forEach(b => b.classList.toggle('active', b.dataset.v === v));
        });
      });
    }
  });
})();
