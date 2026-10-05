const $ = id => document.getElementById(id);
const val = id => $(id).value.trim();

async function call(method, url, body) {
  const out = $('out');
  out.className = '';
  out.textContent = 'Sending...';
  try {
    const res = await fetch(url, {
      method,
      headers: {'Content-Type': 'application/json'},
      body: body ? JSON.stringify(body) : undefined
    });
    const text = await res.text();
    let data = null, shown = text;
    try { data = JSON.parse(text); shown = JSON.stringify(data, null, 2); } catch (e) {}
        out.textContent = method + ' ' + url + '\n' + res.status + ' ' + res.statusText + '\n' + shown;
    out.className = res.ok ? 'ok' : 'bad';
    return data;
  } catch (e) {
    out.textContent = 'Could not reach ' + url + ' (' + e.message + '). Check that the stack is running.';
    out.className = 'bad';
    return null;
  }
}

function rememberOrder(id) { try { localStorage.setItem('orderId', id); } catch (e) {} }
function lastOrder() { try { return localStorage.getItem('orderId') || ''; } catch (e) { return ''; } }
function enc(id) { return encodeURIComponent(val(id)); }