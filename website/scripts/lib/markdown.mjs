// Small Markdown subset for articles: headings, paragraphs, lists, blockquotes,
// bold, italic, links and inline code. Kept dependency-free so the Cloudflare
// Pages build needs nothing but Node.

const escapeHtml = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export function slugifyHeading(text) {
  return text
    .toLowerCase()
    .normalize('NFKC')
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .trim()
    .replace(/\s+/g, '-');
}

export function inline(text) {
  let out = escapeHtml(text);
  out = out.replace(/`([^`]+)`/g, '<code>$1</code>');
  out = out.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  out = out.replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>');
  out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, label, href) => {
    const external = /^https?:\/\//.test(href) && !href.startsWith('https://salahalarm.com');
    const rel = external ? ' rel="noopener" target="_blank"' : '';
    return `<a href="${href}"${rel}>${label}</a>`;
  });
  return out;
}

// Returns { html, headings } where headings lists the h2s for a table of contents.
export function render(md) {
  const lines = md.replace(/\r\n/g, '\n').split('\n');
  const html = [];
  const headings = [];
  let para = [];
  let list = null; // { tag, items }
  let quote = [];

  const flushPara = () => {
    if (para.length) html.push(`<p>${inline(para.join(' '))}</p>`);
    para = [];
  };
  const flushList = () => {
    if (list) html.push(`<${list.tag}>${list.items.map((i) => `<li>${inline(i)}</li>`).join('')}</${list.tag}>`);
    list = null;
  };
  const flushQuote = () => {
    if (quote.length) html.push(`<blockquote><p>${inline(quote.join(' '))}</p></blockquote>`);
    quote = [];
  };
  const flushAll = () => {
    flushPara();
    flushList();
    flushQuote();
  };

  for (const raw of lines) {
    const line = raw.trimEnd();
    let m;
    if (!line.trim()) {
      flushAll();
    } else if ((m = line.match(/^(#{2,4})\s+(.*)$/))) {
      flushAll();
      const level = m[1].length;
      const id = slugifyHeading(m[2]);
      if (level === 2) headings.push({ id, text: m[2] });
      html.push(`<h${level} id="${id}">${inline(m[2])}</h${level}>`);
    } else if ((m = line.match(/^\s*[-*]\s+(.*)$/))) {
      flushPara();
      flushQuote();
      if (!list || list.tag !== 'ul') {
        flushList();
        list = { tag: 'ul', items: [] };
      }
      list.items.push(m[1]);
    } else if ((m = line.match(/^\s*\d+[.)]\s+(.*)$/))) {
      flushPara();
      flushQuote();
      if (!list || list.tag !== 'ol') {
        flushList();
        list = { tag: 'ol', items: [] };
      }
      list.items.push(m[1]);
    } else if ((m = line.match(/^>\s?(.*)$/))) {
      flushPara();
      flushList();
      quote.push(m[1]);
    } else if (list && /^\s{2,}\S/.test(raw)) {
      list.items[list.items.length - 1] += ' ' + line.trim();
    } else {
      flushList();
      flushQuote();
      para.push(line.trim());
    }
  }
  flushAll();
  return { html: html.join('\n'), headings };
}

// Frontmatter is simple `key: value` lines; `faq` entries are `- q: ... | a: ...`.
export function parseFrontmatter(src) {
  const m = src.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) throw new Error('missing frontmatter');
  const data = {};
  let currentList = null;
  for (const line of m[1].split('\n')) {
    if (!line.trim()) continue;
    const item = line.match(/^\s+-\s+(.*)$/);
    if (item && currentList) {
      data[currentList].push(item[1]);
      continue;
    }
    const kv = line.match(/^([A-Za-z_]+):\s*(.*)$/);
    if (!kv) throw new Error(`bad frontmatter line: ${line}`);
    const [, key, value] = kv;
    if (value === '') {
      data[key] = [];
      currentList = key;
    } else {
      data[key] = value.replace(/^"(.*)"$/, '$1');
      currentList = null;
    }
  }
  if (Array.isArray(data.faq)) {
    data.faq = data.faq.map((entry) => {
      const parts = entry.match(/^q:\s*(.*?)\s*\|\s*a:\s*(.*)$/);
      if (!parts) throw new Error(`bad faq entry: ${entry}`);
      return { q: parts[1], a: parts[2] };
    });
  }
  return { data, body: m[2] };
}

export { escapeHtml };
