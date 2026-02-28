/* ── State ───────────────────────────────────────────────────────────────── */
const state = {
  articles: [],
  bookmarks: new Set(),      // Set of article URLs
  sources: [],               // loaded from DEFAULT_SOURCES + localStorage
  settings: {
    theme: 'system',
    autoRefresh: false,
    refreshInterval: 15,
    twitterToken: '',
  },
  filter: 'all',
  search: '',
  reportPeriod: 'today',
  currentReport: null,
  currentArticle: null,
  isLoading: false,
  lastRefreshed: null,
};

const CACHE_KEY = 'ai_news_cache';
const CACHE_TTL = 15 * 60 * 1000;   // 15 minutes
const STORAGE_KEYS = {
  bookmarks: 'ai_news_bookmarks',
  sources:   'ai_news_sources',
  settings:  'ai_news_settings',
};

// CORS proxies (tried in order until one works)
const CORS_PROXIES = [
  url => `https://corsproxy.io/?${encodeURIComponent(url)}`,          // raw response
  url => `https://api.allorigins.win/raw?url=${encodeURIComponent(url)}`, // raw response
];

/* ── Persistence ─────────────────────────────────────────────────────────── */
function loadStorage() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEYS.bookmarks) || '[]');
    state.bookmarks = new Set(saved);
  } catch { state.bookmarks = new Set(); }

  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEYS.sources));
    if (saved) {
      // merge with DEFAULT_SOURCES to pick up new sources on update
      state.sources = DEFAULT_SOURCES.map(def => {
        const stored = saved.find(s => s.id === def.id);
        return stored ? { ...def, enabled: stored.enabled } : def;
      });
    } else {
      state.sources = DEFAULT_SOURCES.map(s => ({ ...s }));
    }
  } catch { state.sources = DEFAULT_SOURCES.map(s => ({ ...s })); }

  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEYS.settings));
    if (saved) state.settings = { ...state.settings, ...saved };
  } catch {}
}

function saveSources() {
  localStorage.setItem(STORAGE_KEYS.sources, JSON.stringify(
    state.sources.map(({ id, enabled }) => ({ id, enabled }))
  ));
}

function saveBookmarks() {
  localStorage.setItem(STORAGE_KEYS.bookmarks, JSON.stringify([...state.bookmarks]));
}

function saveSettings() {
  localStorage.setItem(STORAGE_KEYS.settings, JSON.stringify(state.settings));
}

/* ── Theme ───────────────────────────────────────────────────────────────── */
function applyTheme(theme) {
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const dark = theme === 'dark' || (theme === 'system' && prefersDark);
  document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
  document.getElementById('themeIcon').textContent = dark ? '☀️' : '🌙';
}

/* ── Tab Switching ───────────────────────────────────────────────────────── */
function switchTab(tabId) {
  document.querySelectorAll('.tab-btn').forEach(btn => {
    const active = btn.dataset.tab === tabId;
    btn.classList.toggle('active', active);
    btn.setAttribute('aria-selected', active);
  });
  document.querySelectorAll('.tab-panel').forEach(panel => {
    const active = panel.id === `tab-${tabId}`;
    panel.classList.toggle('active', active);
    panel.hidden = !active;
  });
  if (tabId === 'sources')  renderSources();
  if (tabId === 'settings') renderSettings();
  if (tabId === 'bookmarks') renderBookmarks();
}

/* ── Time Helpers ────────────────────────────────────────────────────────── */
function timeAgo(date) {
  if (!date) return '';
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
  if (seconds < 60)  return 'Just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  return `${Math.floor(seconds / 86400)}d ago`;
}

function formatDate(date) {
  if (!date) return '';
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

/* ── RSS Fetching ────────────────────────────────────────────────────────── */
async function fetchWithProxy(proxyUrl) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(proxyUrl, { signal: controller.signal });
    clearTimeout(timer);
    return res.ok ? await res.text() : null;
  } catch {
    clearTimeout(timer);
    return null;
  }
}

async function fetchSource(source) {
  for (const makeUrl of CORS_PROXIES) {
    const xml = await fetchWithProxy(makeUrl(source.feedURL));
    if (xml) {
      const items = parseFeed(xml, source);
      if (items.length > 0) return items;
    }
  }
  return [];
}

function parseFeed(xmlStr, source) {
  try {
    const doc = new DOMParser().parseFromString(xmlStr, 'text/xml');
    if (doc.querySelector('parsererror')) return [];
    const isAtom = !!doc.querySelector('feed');
    const nodes = Array.from(doc.querySelectorAll(isAtom ? 'entry' : 'item')).slice(0, 30);
    return nodes.map(node => {
      const text = sel => node.querySelector(sel)?.textContent?.trim() || '';
      const nsText = (uri, local) => node.getElementsByTagNameNS(uri, local)[0]?.textContent?.trim() || '';
      let link, pubDate;
      if (isAtom) {
        link = node.querySelector('link[rel="alternate"]')?.getAttribute('href')
          || node.querySelector('link:not([rel="self"])')?.getAttribute('href')
          || node.querySelector('link')?.getAttribute('href') || '';
        pubDate = text('published') || text('updated');
      } else {
        const linkEl = node.querySelector('link');
        link = linkEl?.getAttribute('href') || linkEl?.textContent?.trim() || '';
        pubDate = text('pubDate');
      }
      const description = isAtom
        ? (text('content') || text('summary'))
        : (nsText('http://purl.org/rss/1.0/modules/content/', 'encoded') || text('description'));
      const author = isAtom
        ? text('author name')
        : (nsText('http://purl.org/dc/elements/1.1/', 'creator') || text('author'));
      return parseRssItem({
        title: text('title') || '(No title)',
        link, pubDate, description, author,
        guid: text('id') || text('guid') || link,
      }, source);
    });
  } catch { return []; }
}

function parseRssItem(item, source) {
  // iOS Safari needs strict ISO-8601; normalize "2026-02-28 14:30:00" → "2026-02-28T14:30:00"
  const raw = item.pubDate ? String(item.pubDate).trim().replace(' ', 'T') : null;
  const parsed = raw ? new Date(raw) : null;
  const pub = parsed && !isNaN(parsed.getTime()) ? parsed : null;
  let summary = stripHtml(item.description || item.content || item.summary || '');
  if (summary.length > 400) summary = summary.slice(0, 400).trimEnd() + '…';

  // Infer tags from title + summary
  const text = ((item.title || '') + ' ' + summary).toLowerCase();
  const tags = inferTags(text);

  return {
    id: item.guid || item.link || item.title,
    title: item.title || '(No title)',
    summary,
    url: item.link || '',
    source: source.name,
    sourceId: source.id,
    sourceIcon: source.icon,
    sourceColor: source.color,
    sourceCategory: source.category,
    publishedAt: pub,
    author: item.author || null,
    tags,
    thumbnail: item.thumbnail || item.enclosure?.link || null,
  };
}

function stripHtml(html) {
  const div = document.createElement('div');
  div.innerHTML = html;
  return (div.textContent || div.innerText || '').trim().replace(/\s+/g, ' ');
}

function inferTags(text) {
  const tags = [];
  if (/\b(gpt|llm|claude|gemini|model|paper|arxiv|research|benchmark)\b/.test(text)) tags.push('Research');
  if (/\b(fund|invest|acqui|startup|revenue|billion|million)\b/.test(text)) tags.push('Business');
  if (/\b(regulat|policy|safety|law|congress|government|ethics)\b/.test(text)) tags.push('Policy');
  if (/\b(open.source|github|weights|hugging)\b/.test(text)) tags.push('Open Source');
  if (/\b(product|launch|release|feature|update|api|tool)\b/.test(text)) tags.push('Product');
  return tags;
}

async function fetchAllNews() {
  // Check cache
  try {
    const cached = JSON.parse(localStorage.getItem(CACHE_KEY));
    if (cached && (Date.now() - cached.timestamp < CACHE_TTL)) {
      state.articles = cached.articles.map(a => ({ ...a, publishedAt: a.publishedAt ? new Date(a.publishedAt) : null }));
      state.lastRefreshed = new Date(cached.timestamp);
      renderFeed();
      updateRefreshedLabel();
    }
  } catch {}

  setLoading(true);
  const enabledSources = state.sources.filter(s => s.enabled && s.category !== 'social');
  const results = await Promise.allSettled(enabledSources.map(fetchSource));
  const allArticles = results.flatMap(r => r.status === 'fulfilled' ? r.value : []);

  // Deduplicate by URL
  const seen = new Set();
  state.articles = allArticles
    .filter(a => { if (!a.url || seen.has(a.url)) return false; seen.add(a.url); return true; })
    .sort((a, b) => (b.publishedAt || 0) - (a.publishedAt || 0));

  state.lastRefreshed = new Date();
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify({
      timestamp: state.lastRefreshed.getTime(),
      articles: state.articles.map(a => ({ ...a, publishedAt: a.publishedAt?.toISOString() })),
    }));
  } catch {}

  setLoading(false);
  renderFeed();
  updateRefreshedLabel();
}

function setLoading(loading) {
  state.isLoading = loading;
  const icon = document.getElementById('refreshIcon');
  icon.classList.toggle('spinning', loading);
  document.getElementById('refreshBtn').disabled = loading;
}

function updateRefreshedLabel() {
  const el = document.getElementById('lastRefreshed');
  el.textContent = state.lastRefreshed ? `Updated ${timeAgo(state.lastRefreshed)}` : '';
}

/* ── Filtering ───────────────────────────────────────────────────────────── */
function getFilteredArticles() {
  let articles = state.articles;
  const q = state.search.toLowerCase().trim();
  if (q) {
    articles = articles.filter(a =>
      a.title.toLowerCase().includes(q) ||
      a.summary.toLowerCase().includes(q) ||
      a.source.toLowerCase().includes(q) ||
      a.tags.some(t => t.toLowerCase().includes(q))
    );
  }
  if (state.filter === 'bookmarked') {
    articles = articles.filter(a => state.bookmarks.has(a.url));
  } else if (state.filter !== 'all') {
    articles = articles.filter(a => a.sourceCategory === state.filter);
  }
  return articles;
}

/* ── Render Feed ─────────────────────────────────────────────────────────── */
function renderFeed() {
  const list = document.getElementById('articleList');
  const filtered = getFilteredArticles();

  // Stats
  const statsEl = document.getElementById('feedStats');
  if (state.articles.length > 0) {
    statsEl.textContent = `${filtered.length} of ${state.articles.length} articles`;
    statsEl.hidden = false;
  } else {
    statsEl.hidden = true;
  }

  if (state.isLoading && state.articles.length === 0) {
    list.innerHTML = `<div class="loading-state"><div class="spinner"></div><p>Loading AI news…</p></div>`;
    return;
  }
  if (filtered.length === 0) {
    list.innerHTML = `<div class="empty-state"><span class="empty-icon">🔍</span><h3>${state.search ? 'No results' : 'No articles'}</h3><p>${state.search ? `Nothing matched "${state.search}".` : 'Enable more sources or refresh.'}</p></div>`;
    return;
  }
  list.innerHTML = filtered.map(a => articleCardHTML(a)).join('');
  updateBookmarkBadge();
}

function articleCardHTML(article, mini = false) {
  const bookmarked = state.bookmarks.has(article.url);
  const tagsHtml = article.tags.slice(0, 3).map(t => `<span class="tag">${t}</span>`).join('');
  return `
    <article class="article-card" data-url="${escHtml(article.url)}" role="button" tabindex="0">
      <div class="card-top">
        <div class="source-icon" style="background:${article.sourceColor}22">${article.sourceIcon}</div>
        <div class="card-meta">
          <div class="source-name">${escHtml(article.source)}</div>
          <div class="article-title">${escHtml(article.title)}</div>
          <div class="time-ago">${timeAgo(article.publishedAt)}</div>
        </div>
        <button class="bookmark-btn ${bookmarked ? 'bookmarked' : ''}"
          data-url="${escHtml(article.url)}"
          title="${bookmarked ? 'Remove bookmark' : 'Bookmark'}"
          aria-label="${bookmarked ? 'Remove bookmark' : 'Bookmark article'}"
        >${bookmarked ? '🔖' : '🔖'}</button>
      </div>
      ${article.summary ? `<p class="article-summary">${escHtml(article.summary)}</p>` : ''}
      ${tagsHtml ? `<div class="card-tags">${tagsHtml}</div>` : ''}
    </article>`;
}

function escHtml(str) {
  return String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

/* ── Article Modal ───────────────────────────────────────────────────────── */
function openArticle(url) {
  const article = state.articles.find(a => a.url === url);
  if (!article) return;
  state.currentArticle = article;

  const modal = document.getElementById('articleModal');
  const bookmarked = state.bookmarks.has(article.url);

  document.getElementById('modalSourceBadge').innerHTML =
    `<span style="font-size:18px">${article.sourceIcon}</span> <span>${escHtml(article.source)}</span>`;
  document.getElementById('modalBookmarkBtn').textContent = bookmarked ? '🔖' : '🔖';
  document.getElementById('modalBookmarkBtn').style.opacity = bookmarked ? '1' : '0.4';
  document.getElementById('readFullArticleBtn').href = article.url;

  document.getElementById('modalBody').innerHTML = `
    <h2 id="modalTitle">${escHtml(article.title)}</h2>
    <div class="modal-article-meta">
      ${article.author ? `<span>✍️ ${escHtml(article.author)}</span> <span>·</span>` : ''}
      <span>📅 ${formatDate(article.publishedAt)}</span>
      <span>·</span>
      <span>${timeAgo(article.publishedAt)}</span>
    </div>
    ${article.summary ? `<p class="modal-article-summary">${escHtml(article.summary)}</p>` : ''}
    ${article.tags.length ? `<div class="modal-tags">${article.tags.map(t => `<span class="tag">${escHtml(t)}</span>`).join('')}</div>` : ''}
  `;

  modal.hidden = false;
  document.body.style.overflow = 'hidden';
}

function closeModal() {
  document.getElementById('articleModal').hidden = true;
  document.body.style.overflow = '';
  state.currentArticle = null;
}

/* ── Bookmarks ───────────────────────────────────────────────────────────── */
function toggleBookmark(url) {
  if (state.bookmarks.has(url)) {
    state.bookmarks.delete(url);
  } else {
    state.bookmarks.add(url);
  }
  saveBookmarks();
  updateBookmarkBadge();

  // Update card UI without full re-render
  document.querySelectorAll(`.bookmark-btn[data-url="${CSS.escape(url)}"]`).forEach(btn => {
    const bk = state.bookmarks.has(url);
    btn.classList.toggle('bookmarked', bk);
    btn.style.opacity = bk ? '1' : '0.4';
  });

  // Update modal bookmark btn if open
  if (state.currentArticle?.url === url) {
    const btn = document.getElementById('modalBookmarkBtn');
    const bk = state.bookmarks.has(url);
    btn.style.opacity = bk ? '1' : '0.4';
  }
}

function updateBookmarkBadge() {
  const count = state.articles.filter(a => state.bookmarks.has(a.url)).length;
  const badge = document.getElementById('bookmarkBadge');
  badge.textContent = count || '';
  badge.hidden = count === 0;

  const clearBtn = document.getElementById('clearBookmarksBtn');
  if (clearBtn) clearBtn.hidden = count === 0;
}

function renderBookmarks() {
  const list = document.getElementById('bookmarkList');
  const bookmarked = state.articles.filter(a => state.bookmarks.has(a.url));
  if (bookmarked.length === 0) {
    list.innerHTML = `<div class="empty-state"><span class="empty-icon">🔖</span><h3>No saved articles</h3><p>Tap the bookmark icon on any article to save it here.</p></div>`;
  } else {
    list.innerHTML = bookmarked.map(a => articleCardHTML(a)).join('');
  }
  document.getElementById('clearBookmarksBtn').hidden = bookmarked.length === 0;
}

/* ── Quick Report ────────────────────────────────────────────────────────── */
function periodCutoff(period) {
  const now = new Date();
  if (period === 'hour') return new Date(now - 60 * 60 * 1000);
  if (period === 'today') {
    const d = new Date(now); d.setHours(0, 0, 0, 0); return d;
  }
  return new Date(now - 7 * 24 * 60 * 60 * 1000); // week
}

function categoriseArticle(article) {
  const text = (article.title + ' ' + article.summary).toLowerCase();
  let best = null, bestScore = 0;
  for (const cat of REPORT_CATEGORIES) {
    const score = cat.keywords.filter(k => text.includes(k)).length;
    if (score > bestScore) { bestScore = score; best = cat; }
  }
  return best || REPORT_CATEGORIES[3]; // default: Products
}

function generateReport() {
  const cutoff = periodCutoff(state.reportPeriod);
  const inPeriod = state.articles.filter(a => a.publishedAt && a.publishedAt >= cutoff);

  if (inPeriod.length === 0) {
    document.getElementById('reportContent').innerHTML = `
      <div class="empty-state">
        <span class="empty-icon">📭</span>
        <h3>No articles in this period</h3>
        <p>Try a wider time range or refresh the feed first.</p>
      </div>`;
    document.getElementById('exportReportBtn').hidden = true;
    return;
  }

  // Group by category
  const groups = {};
  for (const a of inPeriod) {
    const cat = categoriseArticle(a);
    if (!groups[cat.id]) groups[cat.id] = { ...cat, articles: [] };
    groups[cat.id].articles.push(a);
  }

  // Top sources
  const sourceCounts = {};
  inPeriod.forEach(a => { sourceCounts[a.source] = (sourceCounts[a.source] || 0) + 1; });
  const topSources = Object.entries(sourceCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name]) => name);

  state.currentReport = { inPeriod, groups, topSources };

  const periodLabel = { hour: 'Last Hour', today: 'Today', week: 'This Week' }[state.reportPeriod];
  const sourcesHtml = topSources.map(s => `<span class="source-chip">${escHtml(s)}</span>`).join('');

  const sectionsHtml = Object.values(groups)
    .sort((a, b) => b.articles.length - a.articles.length)
    .map(group => {
      const top5 = group.articles.slice(0, 5);
      const rowsHtml = top5.map(a => `
        <div class="report-article-row" data-url="${escHtml(a.url)}" role="button" tabindex="0">
          <div style="flex:1">
            <div class="report-article-title">${escHtml(a.title)}</div>
            <div class="report-article-source">${escHtml(a.source)} · ${timeAgo(a.publishedAt)}</div>
          </div>
        </div>`).join('');
      return `
        <div class="report-section">
          <div class="report-section-header">
            <div class="report-category-label"><span>${group.emoji}</span>${escHtml(group.label)}</div>
            <div class="report-headline">${escHtml(group.articles[0].title)}</div>
            <div class="report-summary">${group.articles.length} article${group.articles.length !== 1 ? 's' : ''} · Top sources: ${escHtml(group.articles.slice(0, 3).map(a => a.source).join(', '))}</div>
          </div>
          <div class="report-articles">${rowsHtml}</div>
        </div>`;
    }).join('');

  document.getElementById('reportContent').innerHTML = `
    <div class="report-meta">
      <div class="report-stat">
        <span class="report-stat-value">${inPeriod.length}</span>
        <span class="report-stat-label">Articles</span>
      </div>
      <div class="report-stat">
        <span class="report-stat-value">${Object.keys(groups).length}</span>
        <span class="report-stat-label">Categories</span>
      </div>
      <div class="report-stat">
        <span class="report-stat-value">${topSources.length}</span>
        <span class="report-stat-label">Sources</span>
      </div>
    </div>
    <div style="margin-bottom:4px;font-size:12px;color:var(--text-ter);font-weight:600;text-transform:uppercase;letter-spacing:.5px">Top Sources</div>
    <div class="top-sources">${sourcesHtml}</div>
    ${sectionsHtml}`;

  document.getElementById('exportReportBtn').hidden = false;
}

function exportReport() {
  if (!state.currentReport) return;
  const { inPeriod, groups, topSources } = state.currentReport;
  const period = { hour: 'Last Hour', today: 'Today', week: 'This Week' }[state.reportPeriod];
  let md = `# AI News Quick Report — ${period}\n\n`;
  md += `**Generated:** ${new Date().toLocaleString()}\n`;
  md += `**Total articles:** ${inPeriod.length}\n`;
  md += `**Top sources:** ${topSources.join(', ')}\n\n---\n\n`;
  for (const group of Object.values(groups).sort((a, b) => b.articles.length - a.articles.length)) {
    md += `## ${group.emoji} ${group.label}\n\n`;
    group.articles.slice(0, 5).forEach(a => {
      md += `- **${a.title}** — *${a.source}* (${timeAgo(a.publishedAt)})\n  ${a.url}\n`;
    });
    md += '\n';
  }
  const blob = new Blob([md], { type: 'text/markdown' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `ai-news-report-${state.reportPeriod}-${Date.now()}.md`;
  a.click();
}

/* ── Sources ─────────────────────────────────────────────────────────────── */
function renderSources(filter = '') {
  const q = filter.toLowerCase();
  const filtered = state.sources.filter(s =>
    !q || s.name.toLowerCase().includes(q) || s.category.includes(q)
  );
  const active = state.sources.filter(s => s.enabled).length;
  document.getElementById('sourcesActiveCount').textContent = active;
  document.getElementById('sourcesTotalCount').textContent = state.sources.length;

  const groups = {};
  filtered.forEach(s => { if (!groups[s.category]) groups[s.category] = []; groups[s.category].push(s); });

  const order = ['company', 'news', 'research', 'social'];
  let html = '';
  for (const cat of order) {
    if (!groups[cat]) continue;
    html += `<div class="source-group-label">${CATEGORY_LABELS[cat] || cat}</div>`;
    html += groups[cat].map(s => `
      <div class="source-row ${s.enabled ? '' : 'disabled'}" data-source-id="${s.id}">
        <div class="source-row-icon" style="background:${s.color}22">${s.icon}</div>
        <div class="source-row-info">
          <div class="source-row-name">${escHtml(s.name)}</div>
          <div class="source-row-cat">${CATEGORY_LABELS[s.category] || s.category}</div>
        </div>
        <label class="toggle" title="${s.enabled ? 'Disable' : 'Enable'} ${s.name}">
          <input type="checkbox" ${s.enabled ? 'checked' : ''} data-source-id="${s.id}" aria-label="Toggle ${s.name}">
          <span class="toggle-track"></span>
        </label>
      </div>`).join('');
  }
  document.getElementById('sourcesList').innerHTML = html || '<div class="empty-state"><span class="empty-icon">🔍</span><p>No sources match.</p></div>';
}

function toggleSource(sourceId, enabled) {
  const source = state.sources.find(s => s.id === sourceId);
  if (!source) return;
  source.enabled = enabled;
  saveSources();
  renderSources(document.getElementById('sourcesSearch').value);
}

/* ── Settings ────────────────────────────────────────────────────────────── */
function renderSettings() {
  const s = state.settings;
  const twitterOk = s.twitterToken.length > 10;

  document.getElementById('settingsContainer').innerHTML = `
    <!-- App Info -->
    <div class="settings-section">
      <div class="settings-section-title">App Info</div>
      <div class="settings-row">
        <span class="settings-row-icon">🤖</span>
        <span class="settings-row-label">AI News Aggregator</span>
        <span class="settings-row-value">v1.0</span>
      </div>
      <div class="settings-row">
        <span class="settings-row-icon">📡</span>
        <span class="settings-row-label">Active Sources</span>
        <span class="settings-row-value">${state.sources.filter(s => s.enabled).length} / ${state.sources.length}</span>
      </div>
      <div class="settings-row">
        <span class="settings-row-icon">📰</span>
        <span class="settings-row-label">Cached Articles</span>
        <span class="settings-row-value">${state.articles.length}</span>
      </div>
    </div>

    <!-- Twitter -->
    <div class="settings-section">
      <div class="settings-section-title">X (Twitter) Integration</div>
      <div class="settings-row" style="flex-wrap:wrap;gap:8px">
        <span class="settings-row-icon">🐦</span>
        <span class="settings-row-label">Bearer Token</span>
        <input
          type="password"
          id="twitterTokenInput"
          class="settings-input"
          placeholder="Paste your Twitter API v2 bearer token"
          value="${escHtml(s.twitterToken)}"
          style="flex-basis:100%;margin-top:4px"
        >
      </div>
      <div class="settings-row">
        <span class="settings-row-icon">${twitterOk ? '✅' : '⚠️'}</span>
        <span class="settings-row-label">Status</span>
        <span class="settings-row-value">
          <span class="status-dot ${twitterOk ? 'green' : 'grey'}"></span>
          ${twitterOk ? 'Configured' : 'Not configured'}
        </span>
      </div>
    </div>

    <!-- Preferences -->
    <div class="settings-section">
      <div class="settings-section-title">Preferences</div>
      <div class="settings-row">
        <span class="settings-row-icon">🎨</span>
        <span class="settings-row-label">Theme</span>
        <select id="themeSelect" class="settings-select">
          <option value="system" ${s.theme === 'system' ? 'selected' : ''}>System</option>
          <option value="light"  ${s.theme === 'light'  ? 'selected' : ''}>Light</option>
          <option value="dark"   ${s.theme === 'dark'   ? 'selected' : ''}>Dark</option>
        </select>
      </div>
      <div class="settings-row">
        <span class="settings-row-icon">🔄</span>
        <span class="settings-row-label">Auto-Refresh</span>
        <label class="toggle">
          <input type="checkbox" id="autoRefreshToggle" ${s.autoRefresh ? 'checked' : ''} aria-label="Auto-refresh">
          <span class="toggle-track"></span>
        </label>
      </div>
      <div class="settings-row">
        <span class="settings-row-icon">⏱️</span>
        <span class="settings-row-label">Refresh Interval</span>
        <select id="refreshIntervalSelect" class="settings-select" ${!s.autoRefresh ? 'disabled' : ''}>
          <option value="5"  ${s.refreshInterval === 5  ? 'selected' : ''}>5 min</option>
          <option value="10" ${s.refreshInterval === 10 ? 'selected' : ''}>10 min</option>
          <option value="15" ${s.refreshInterval === 15 ? 'selected' : ''}>15 min</option>
          <option value="30" ${s.refreshInterval === 30 ? 'selected' : ''}>30 min</option>
          <option value="60" ${s.refreshInterval === 60 ? 'selected' : ''}>60 min</option>
        </select>
      </div>
    </div>

    <!-- Data -->
    <div class="settings-section">
      <div class="settings-section-title">Data</div>
      <div class="settings-row">
        <span class="settings-row-icon">🔖</span>
        <span class="settings-row-label">Bookmarks</span>
        <span class="settings-row-value">${state.bookmarks.size}</span>
      </div>
      <div class="settings-row">
        <span class="settings-row-icon">🕐</span>
        <span class="settings-row-label">Last Refreshed</span>
        <span class="settings-row-value">${state.lastRefreshed ? timeAgo(state.lastRefreshed) : 'Never'}</span>
      </div>
      <div class="settings-row danger" style="cursor:pointer" id="clearDataBtn">
        <span class="settings-row-icon">🗑️</span>
        <span class="settings-row-label" style="color:var(--danger)">Clear All Data</span>
      </div>
    </div>

    <!-- About -->
    <div class="settings-section">
      <div class="settings-section-title">About</div>
      <div class="settings-row">
        <span class="settings-row-icon">🔒</span>
        <span class="settings-row-label">Privacy</span>
        <span class="settings-row-value" style="font-size:12px">No data collected</span>
      </div>
      <div class="settings-row">
        <span class="settings-row-icon">📦</span>
        <span class="settings-row-label">Sources</span>
        <span class="settings-row-value" style="font-size:12px">RSS + X API v2</span>
      </div>
    </div>
  `;

  // Bind settings events
  document.getElementById('twitterTokenInput').addEventListener('change', e => {
    state.settings.twitterToken = e.target.value.trim();
    saveSettings();
  });
  document.getElementById('themeSelect').addEventListener('change', e => {
    state.settings.theme = e.target.value;
    saveSettings();
    applyTheme(state.settings.theme);
  });
  document.getElementById('autoRefreshToggle').addEventListener('change', e => {
    state.settings.autoRefresh = e.target.checked;
    saveSettings();
    setupAutoRefresh();
    document.getElementById('refreshIntervalSelect').disabled = !e.target.checked;
  });
  document.getElementById('refreshIntervalSelect').addEventListener('change', e => {
    state.settings.refreshInterval = parseInt(e.target.value, 10);
    saveSettings();
    setupAutoRefresh();
  });
  document.getElementById('clearDataBtn').addEventListener('click', () => {
    if (!confirm('Clear all bookmarks and cached articles?')) return;
    state.bookmarks.clear();
    state.articles = [];
    saveBookmarks();
    localStorage.removeItem(CACHE_KEY);
    updateBookmarkBadge();
    renderSettings();
    alert('Data cleared. Refresh to reload articles.');
  });
}

/* ── Auto Refresh ────────────────────────────────────────────────────────── */
let autoRefreshTimer = null;
function setupAutoRefresh() {
  clearInterval(autoRefreshTimer);
  if (state.settings.autoRefresh) {
    autoRefreshTimer = setInterval(fetchAllNews, state.settings.refreshInterval * 60 * 1000);
  }
}

/* ── Event Delegation ────────────────────────────────────────────────────── */
function initEvents() {
  // Tab nav
  document.querySelector('.tab-nav').addEventListener('click', e => {
    const btn = e.target.closest('.tab-btn');
    if (btn) switchTab(btn.dataset.tab);
  });

  // Refresh
  document.getElementById('refreshBtn').addEventListener('click', fetchAllNews);

  // Theme toggle
  document.getElementById('themeToggle').addEventListener('click', () => {
    const current = state.settings.theme;
    const themes = ['system', 'light', 'dark'];
    state.settings.theme = themes[(themes.indexOf(current) + 1) % 3];
    saveSettings();
    applyTheme(state.settings.theme);
  });

  // Search
  let searchTimeout;
  document.getElementById('searchInput').addEventListener('input', e => {
    state.search = e.target.value;
    document.getElementById('clearSearch').hidden = !state.search;
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(renderFeed, 250);
  });
  document.getElementById('clearSearch').addEventListener('click', () => {
    document.getElementById('searchInput').value = '';
    state.search = '';
    document.getElementById('clearSearch').hidden = true;
    renderFeed();
  });

  // Filter pills
  document.querySelector('.filter-pills').addEventListener('click', e => {
    const pill = e.target.closest('.pill');
    if (!pill) return;
    document.querySelectorAll('.pill').forEach(p => p.classList.remove('active'));
    pill.classList.add('active');
    state.filter = pill.dataset.filter;
    renderFeed();
  });

  // Article list — card click & bookmark click
  document.getElementById('articleList').addEventListener('click', handleArticleListClick);
  document.getElementById('articleList').addEventListener('keydown', e => {
    if (e.key === 'Enter') handleArticleListClick(e);
  });

  // Bookmark list
  document.getElementById('bookmarkList').addEventListener('click', handleArticleListClick);

  // Clear bookmarks
  document.getElementById('clearBookmarksBtn').addEventListener('click', () => {
    if (!confirm('Remove all bookmarks?')) return;
    state.bookmarks.clear();
    saveBookmarks();
    updateBookmarkBadge();
    renderBookmarks();
  });

  // Quick report period
  document.querySelector('.period-selector').addEventListener('click', e => {
    const btn = e.target.closest('.period-btn');
    if (!btn) return;
    document.querySelectorAll('.period-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    state.reportPeriod = btn.dataset.period;
  });
  document.getElementById('generateReportBtn').addEventListener('click', generateReport);
  document.getElementById('exportReportBtn').addEventListener('click', exportReport);

  // Report article click
  document.getElementById('reportContent').addEventListener('click', e => {
    const row = e.target.closest('.report-article-row');
    if (row && row.dataset.url) openArticle(row.dataset.url);
  });

  // Sources search
  document.getElementById('sourcesSearch').addEventListener('input', e => renderSources(e.target.value));

  // Sources toggle
  document.getElementById('sourcesList').addEventListener('change', e => {
    if (e.target.type === 'checkbox' && e.target.dataset.sourceId) {
      toggleSource(e.target.dataset.sourceId, e.target.checked);
    }
  });

  // Modal
  document.getElementById('modalBackdrop').addEventListener('click', closeModal);
  document.getElementById('closeModalBtn').addEventListener('click', closeModal);
  document.getElementById('modalBookmarkBtn').addEventListener('click', () => {
    if (state.currentArticle) toggleBookmark(state.currentArticle.url);
  });
  document.getElementById('modalShareBtn').addEventListener('click', () => {
    if (!state.currentArticle) return;
    if (navigator.share) {
      navigator.share({ title: state.currentArticle.title, url: state.currentArticle.url });
    } else {
      navigator.clipboard.writeText(state.currentArticle.url).then(() => alert('Link copied!'));
    }
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closeModal();
  });

  // System theme changes
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (state.settings.theme === 'system') applyTheme('system');
  });
}

function handleArticleListClick(e) {
  const bookmarkBtn = e.target.closest('.bookmark-btn');
  if (bookmarkBtn) {
    e.stopPropagation();
    toggleBookmark(bookmarkBtn.dataset.url);
    return;
  }
  const card = e.target.closest('.article-card');
  if (card && card.dataset.url) openArticle(card.dataset.url);
}

/* ── Bootstrap ───────────────────────────────────────────────────────────── */
function init() {
  loadStorage();
  applyTheme(state.settings.theme);
  initEvents();
  setupAutoRefresh();
  fetchAllNews();
}

document.addEventListener('DOMContentLoaded', init);
