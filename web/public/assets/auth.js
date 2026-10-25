// Firebase Auth for the web funnel: the same Firebase project and users as the
// iOS app, so the Android app signs in to the same account.
//
// On localhost, `?fakeauth=1` swaps in an offline stand-in for UI tests.

const SDK = "https://www.gstatic.com/firebasejs/12.12.0";

let impl = null;

export async function initAuth(firebaseConfig) {
  if (impl) return impl;
  const fake = ["localhost", "127.0.0.1"].includes(location.hostname) &&
    (new URLSearchParams(location.search).has("fakeauth") || sessionStorage.getItem("sa_fakeauth"));
  impl = fake ? fakeAuth() : await firebaseAuth(firebaseConfig);
  return impl;
}

async function firebaseAuth(config) {
  const [{ initializeApp }, a] = await Promise.all([
    import(`${SDK}/firebase-app.js`),
    import(`${SDK}/firebase-auth.js`),
  ]);
  const app = initializeApp(config);
  const auth = a.initializeAuth(app, {
    persistence: [a.indexedDBLocalPersistence, a.browserLocalPersistence],
    popupRedirectResolver: a.browserPopupRedirectResolver,
  });
  // A redirect sign-in (used when popups are blocked) lands back here.
  const redirectResult = a.getRedirectResult(auth).catch((err) => ({ error: err }));

  return {
    ready: new Promise((resolve) => {
      const off = a.onAuthStateChanged(auth, async (user) => {
        await redirectResult;
        off();
        resolve(user ? wrap(user) : null);
      });
    }),
    onChange(cb) {
      return a.onAuthStateChanged(auth, (user) => cb(user ? wrap(user) : null));
    },
    async google() {
      const provider = new a.GoogleAuthProvider();
      provider.setCustomParameters({ prompt: "select_account" });
      try {
        return wrap((await a.signInWithPopup(auth, provider)).user);
      } catch (err) {
        if (err?.code === "auth/popup-blocked" || err?.code === "auth/operation-not-supported-in-this-environment") {
          await a.signInWithRedirect(auth, provider);
          return null;
        }
        throw err;
      }
    },
    async email(email, password, name) {
      try {
        const cred = await a.createUserWithEmailAndPassword(auth, email, password);
        if (name) await a.updateProfile(cred.user, { displayName: name }).catch(() => {});
        return wrap(cred.user);
      } catch (err) {
        if (err?.code === "auth/email-already-in-use") {
          return wrap((await a.signInWithEmailAndPassword(auth, email, password)).user);
        }
        throw err;
      }
    },
    resetPassword(email) {
      return a.sendPasswordResetEmail(auth, email);
    },
    signOut() {
      return a.signOut(auth);
    },
  };
}

function wrap(user) {
  return {
    uid: user.uid,
    email: user.email,
    name: user.displayName,
    provider: user.providerData?.[0]?.providerId || "password",
    token: (refresh = false) => user.getIdToken(refresh),
  };
}

// ---- offline stand-in (localhost only) ---------------------------------------------

function fakeAuth() {
  sessionStorage.setItem("sa_fakeauth", "1");
  const listeners = new Set();
  const load = () => {
    const raw = sessionStorage.getItem("sa_fake_user");
    return raw ? fakeUser(JSON.parse(raw)) : null;
  };
  const set = (u) => {
    if (u) sessionStorage.setItem("sa_fake_user", JSON.stringify(u));
    else sessionStorage.removeItem("sa_fake_user");
    const wrapped = u ? fakeUser(u) : null;
    listeners.forEach((cb) => cb(wrapped));
    return wrapped;
  };
  function fakeUser(u) {
    return { ...u, token: async () => `fake.${btoa(JSON.stringify(u))}.sig` };
  }
  return {
    ready: Promise.resolve(load()),
    onChange(cb) { listeners.add(cb); return () => listeners.delete(cb); },
    async google() { return set({ uid: "fake-google-uid", email: "test.user@gmail.com", name: "Test User", provider: "google.com" }); },
    async email(email, _password, name) { return set({ uid: `fake-${email}`, email, name: name || null, provider: "password" }); },
    async resetPassword() {},
    async signOut() { set(null); },
  };
}

export function authErrorMessage(err, t) {
  switch (err?.code) {
    case "auth/popup-closed-by-user":
    case "auth/cancelled-popup-request":
      return null;
    case "auth/wrong-password":
    case "auth/invalid-credential":
    case "auth/invalid-login-credentials":
      return t("That email is already registered with a different password.");
    case "auth/invalid-email":
      return t("Please enter a valid email address.");
    case "auth/weak-password":
      return t("Use at least 6 characters for your password.");
    case "auth/network-request-failed":
      return t("No internet connection. Please try again.");
    case "auth/disallowed-useragent":
    case "auth/web-storage-unsupported":
      return t("Google sign-in doesn't work inside this app's browser. Open this page in Chrome, or use email.");
    case "auth/unauthorized-domain":
      return t("Sign-in is not available on this address yet. Please use email.");
    default:
      return t("Something went wrong. Please try again.");
  }
}
