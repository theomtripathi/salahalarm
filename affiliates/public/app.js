// Copy buttons and small conveniences. Everything works without JS too.
document.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-copy]');
  if (!btn) return;
  e.preventDefault();
  const sel = btn.getAttribute('data-copy');
  const text = sel.startsWith('#') ? (document.querySelector(sel)?.innerText || '') : sel;
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const t = document.createElement('textarea');
    t.value = text; document.body.appendChild(t); t.select();
    try { document.execCommand('copy'); } catch { /* ignore */ }
    t.remove();
  }
  const old = btn.textContent;
  btn.textContent = 'Copied';
  setTimeout(() => { btn.textContent = old; }, 1400);
});

document.addEventListener('change', (e) => {
  if (e.target.matches('[data-check-all]')) {
    document.querySelectorAll('input[name="ids"]').forEach((c) => { c.checked = e.target.checked; });
  }
});
