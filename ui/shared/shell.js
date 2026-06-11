// GWorkbench shell behavior: theme switch + 3-pane selection linkage.

(function () {
  function applyTheme() {
    const params = new URLSearchParams(location.search);
    const theme = params.get('theme') === 'dark' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', theme);
    const tag = document.querySelector('[data-theme-tag]');
    if (tag) tag.textContent = theme === 'dark' ? 'Dark' : 'Light';
  }

  function selectRow(row) {
    const list = row.closest('[data-list]');
    if (!list) return;
    const detailGroup = document.querySelector('[data-detail-group="' + list.dataset.list + '"]');
    list.querySelectorAll('.list-row').forEach((r) =>
      r.setAttribute('aria-selected', r === row ? 'true' : 'false')
    );
    const id = row.dataset.itemId;
    if (detailGroup) {
      detailGroup.querySelectorAll('[data-detail-for]').forEach((d) => {
        d.classList.toggle('active', d.dataset.detailFor === id);
      });
    }
  }

  function selectTableRow(row) {
    const table = row.closest('[data-table-list]');
    if (!table) return;
    const detailGroup = document.querySelector('[data-detail-group="' + table.dataset.tableList + '"]');
    table.querySelectorAll('tbody tr').forEach((r) =>
      r.classList.toggle('selected', r === row)
    );
    const id = row.dataset.itemId;
    if (detailGroup) {
      detailGroup.querySelectorAll('[data-detail-for]').forEach((d) => {
        d.classList.toggle('active', d.dataset.detailFor === id);
      });
    }
  }

  function selectSettingsNav(item) {
    const nav = item.closest('[data-settings-nav]');
    if (!nav) return;
    nav.querySelectorAll('.sn-item').forEach((n) =>
      n.setAttribute('aria-current', n === item ? 'true' : 'false')
    );
    const target = item.dataset.target;
    if (target) {
      const el = document.getElementById(target);
      const scroller = document.querySelector('.settings-scroll');
      if (el && scroller) {
        scroller.scrollTo({ top: Math.max(0, el.offsetTop - 16), behavior: 'smooth' });
      }
    }
  }

  function bindClicks() {
    document.querySelectorAll('[data-list] .list-row').forEach((row) => {
      row.addEventListener('click', () => selectRow(row));
    });
    document.querySelectorAll('[data-table-list] tbody tr[data-item-id]').forEach((row) => {
      row.addEventListener('click', () => selectTableRow(row));
    });
    document.querySelectorAll('[data-settings-nav] .sn-item').forEach((item) => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        selectSettingsNav(item);
      });
    });

    // toggles
    document.querySelectorAll('.toggle').forEach((t) => {
      t.addEventListener('click', () => {
        const pressed = t.getAttribute('aria-pressed') === 'true';
        t.setAttribute('aria-pressed', pressed ? 'false' : 'true');
      });
    });

    // segmented controls
    document.querySelectorAll('.segmented').forEach((seg) => {
      seg.querySelectorAll('button').forEach((btn) => {
        btn.addEventListener('click', () => {
          seg.querySelectorAll('button').forEach((b) =>
            b.setAttribute('aria-pressed', b === btn ? 'true' : 'false')
          );
        });
      });
    });

    // checkbox row labels
    document.querySelectorAll('.checkbox-row').forEach((row) => {
      const cb = row.querySelector('input[type="checkbox"]');
      if (!cb) return;
      row.addEventListener('click', (e) => {
        if (e.target.tagName !== 'INPUT') {
          cb.checked = !cb.checked;
        }
      });
    });
  }

  function bindKeyboard() {
    document.addEventListener('keydown', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
      if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
      const lists = document.querySelectorAll('[data-list]');
      for (const list of lists) {
        const current = list.querySelector('.list-row[aria-selected="true"]');
        if (!current) continue;
        const rows = Array.from(list.querySelectorAll('.list-row'));
        const idx = rows.indexOf(current);
        const next = e.key === 'ArrowDown' ? rows[idx + 1] : rows[idx - 1];
        if (next) {
          e.preventDefault();
          selectRow(next);
          const scroller = list.querySelector('.list-scroll') || list;
          const rect = next.getBoundingClientRect();
          const sRect = scroller.getBoundingClientRect();
          if (rect.bottom > sRect.bottom) {
            scroller.scrollTop += rect.bottom - sRect.bottom;
          } else if (rect.top < sRect.top) {
            scroller.scrollTop -= sRect.top - rect.top;
          }
        }
        return;
      }
    });
  }

  applyTheme();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => { bindClicks(); bindKeyboard(); });
  } else {
    bindClicks();
    bindKeyboard();
  }
})();
