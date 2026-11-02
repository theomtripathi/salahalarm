// Serves the static site from dist/ and sends every request to one canonical
// origin (https://salahalarm.com), so Google never sees www or http duplicates.

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.hostname === 'www.salahalarm.com' || url.protocol === 'http:') {
      url.hostname = 'salahalarm.com';
      url.protocol = 'https:';
      return Response.redirect(url.toString(), 301);
    }
    return env.ASSETS.fetch(request);
  },
};
