// Phase 3: minimal, non-privileged, same-origin host -> Lab context bridge.
// Original Python/Sheets runtimes, workbooks, tokens and editors remain unchanged.
const SEASON = /^(19|20)\d{2}-\d{2}$/;
window.addEventListener('message', event => {
  if (window.parent === window || event.source !== window.parent ||
      event.origin !== window.location.origin) return;
  const data = event.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)) return;
  if (Object.keys(data).sort().join(',') !== 'season,segment,type,version') return;
  if (data.type !== 'arcside:context' || data.version !== 1 ||
      typeof data.season !== 'string' || !SEASON.test(data.season) ||
      !['regular','playoffs'].includes(data.segment)) return;
  // Deliberately no persistent storage, code injection, credential forwarding or network calls.
  const detail = Object.freeze({season:data.season,segment:data.segment});
  window.dispatchEvent(new CustomEvent('arcside:context', {detail}));
  const nodeId = 'arcside-shell-context';
  let badge = document.getElementById(nodeId);
  if (!badge) {
    badge = document.createElement('span');
    badge.id = nodeId;
    badge.setAttribute('role','status');
    badge.style.cssText = 'position:fixed;right:12px;bottom:6px;z-index:9999;padding:2px 8px;border:1px solid #54708a;background:#102238;color:#d0e2f8;border-radius:8px;font:11px system-ui;pointer-events:none';
    document.body.appendChild(badge);
  }
  badge.textContent = 'NBA context: ' + detail.season + ' / ' + detail.segment;
  window.parent.postMessage({type:'arcside:context:ack',version:1,season:detail.season,segment:detail.segment},event.origin);
});
