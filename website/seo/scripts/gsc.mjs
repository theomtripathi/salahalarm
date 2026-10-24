// gum may wrap the Search Console body in an envelope; find the first `rows` array
// whose entries carry `keys`.
export function findRows(node) {
  if (!node || typeof node !== 'object') return [];
  if (Array.isArray(node.rows) && (node.rows.length === 0 || Array.isArray(node.rows[0].keys))) return node.rows;
  for (const v of Object.values(node)) {
    const r = findRows(v);
    if (r.length) return r;
  }
  return [];
}
