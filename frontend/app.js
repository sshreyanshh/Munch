const API_BASE = 'http://localhost:8000';

const STUDENTS = [
  { student_id: 1, name: "Rushil Koul", department: "CSE", year: 3 },
  { student_id: 2, name: "Shreyansh Srivastava", department: "CSE", year: 3 },
  { student_id: 3, name: "Aarav Sharma", department: "IT", year: 2 },
  { student_id: 4, name: "Diya Verma", department: "ECE", year: 4 },
  { student_id: 5, name: "Kabir Mehta", department: "Biotech", year: 1 },
  { student_id: 6, name: "Ananya Gupta", department: "CSE", year: 2 }
];

let canteens = [];
let currentCanteenId = 1;
let currentCategory = 'ALL';
let currentSearch = '';
let currentStudentId = 1;
let activeOrderId = null;
let trackerTimer = null;
let cart = [];

function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <span>[${type}]</span>
    <div>${message}</div>
  `;
  container.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 250);
  }, 4000);
}

async function apiRequest(endpoint, options = {}) {
  const res = await fetch(`${API_BASE}${endpoint}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {})
    },
    ...options
  });

  const data = await res.json().catch(() => null);

  if (!res.ok) {
    const errorMsg = data && data.detail ? data.detail : `HTTP ${res.status}: request failed`;
    throw new Error(errorMsg);
  }
  return data;
}

window.switchView = function(viewName) {
  document.querySelectorAll('.nav-tab').forEach(tab => {
    tab.classList.toggle('active', tab.dataset.view === viewName);
  });
  document.querySelectorAll('.view-panel').forEach(panel => {
    panel.classList.toggle('active', panel.id === `view-${viewName}`);
  });

  if (viewName === 'cart') renderCartView();
  if (viewName === 'history') loadOrderHistory();
  if (viewName === 'review') populateReviewItemsDropdown();
  if (viewName === 'admin') loadAdminDashboard();
  if (viewName === 'tracker' && activeOrderId) loadActiveOrder();
};

function setupNavigation() {
  document.querySelectorAll('.nav-tab').forEach(tab => {
    tab.addEventListener('click', () => switchView(tab.dataset.view));
  });

  const logo = document.getElementById('brand-logo');
  if (logo) {
    logo.addEventListener('click', () => switchView('menu'));
  }
}

function setupStudentPicker() {
  const picker = document.getElementById('student-picker');
  if (!picker) return;
  picker.innerHTML = STUDENTS.map(s => `
    <option value="${s.student_id}" ${s.student_id === currentStudentId ? 'selected' : ''}>
      ${s.name.toLowerCase()} (${s.department.toLowerCase()} yr ${s.year})
    </option>
  `).join('');

  picker.addEventListener('change', (e) => {
    currentStudentId = parseInt(e.target.value, 10);
    const student = STUDENTS.find(s => s.student_id === currentStudentId);
    showToast(`active user: ${student.name.toLowerCase()}`, 'info');
    updateCartSummaryHeader();
    if (document.getElementById('view-history')?.classList.contains('active')) {
      loadOrderHistory();
    }
  });
}

async function loadCanteensAndMenu() {
  try {
    canteens = await apiRequest('/canteens');
    if (canteens && canteens.length > 0) {
      currentCanteenId = canteens[0].canteen_id;
    }
    renderCanteenNav();
    await loadMenuForCurrentCanteen();
  } catch (err) {
    showToast(`failed to load menu: ${err.message}`, 'error');
  }
}

function renderCanteenNav() {
  const container = document.getElementById('canteen-pills');
  if (!container) return;
  container.innerHTML = canteens.map(c => `
    <div class="canteen-pill ${c.canteen_id === currentCanteenId ? 'active' : ''}" data-cid="${c.canteen_id}">
      <div class="canteen-pill-name">${c.name.toLowerCase()}</div>
      <div class="canteen-pill-meta">
        <span>${c.location.toLowerCase()}</span>
        <span>•</span>
        <span>${c.opening_time.slice(0, 5)} - ${c.closing_time.slice(0, 5)}</span>
      </div>
    </div>
  `).join('');

  container.querySelectorAll('.canteen-pill').forEach(pill => {
    pill.addEventListener('click', () => {
      currentCanteenId = parseInt(pill.dataset.cid, 10);
      renderCanteenNav();
      loadMenuForCurrentCanteen();
    });
  });
}

async function loadMenuForCurrentCanteen() {
  try {
    const items = await apiRequest(`/menu?canteen_id=${currentCanteenId}`);
    renderCategoryChips(items);
    renderMenuItems(items);
  } catch (err) {
    showToast(`failed to load menu: ${err.message}`, 'error');
  }
}

function renderCategoryChips(items) {
  const container = document.getElementById('category-chips');
  if (!container) return;
  const categories = ['ALL', ...new Set(items.map(i => i.category_name))];

  container.innerHTML = categories.map(cat => `
    <button class="chip ${currentCategory === cat ? 'active' : ''}" data-cat="${cat}">
      ${cat === 'ALL' ? 'all items' : cat.toLowerCase()}
    </button>
  `).join('');

  container.querySelectorAll('.chip').forEach(btn => {
    btn.addEventListener('click', () => {
      currentCategory = btn.dataset.cat;
      renderCategoryChips(items);
      renderMenuItems(items);
    });
  });
}

function renderMenuItems(items) {
  const container = document.getElementById('menu-grid');
  if (!container) return;
  const filtered = items.filter(item => {
    const matchesCat = currentCategory === 'ALL' || item.category_name === currentCategory;
    const matchesSearch = !currentSearch ||
      item.item_name.toLowerCase().includes(currentSearch.toLowerCase()) ||
      (item.description && item.description.toLowerCase().includes(currentSearch.toLowerCase()));
    return matchesCat && matchesSearch;
  });

  if (filtered.length === 0) {
    container.innerHTML = `
      <div style="grid-column: 1 / -1; text-align: center; padding: 3rem 1rem; color: var(--text-muted);">
        <p style="font-size: 0.9rem; font-weight: 500;">[ no items found matching filters ]</p>
      </div>
    `;
    return;
  }

  container.innerHTML = filtered.map(item => {
    const inCart = cart.find(ci => ci.item_id === item.item_id);
    const qty = inCart ? inCart.quantity : 0;
    const isAvail = item.availability_status;

    return `
      <div class="menu-card">
        <div class="menu-card-header">
          <span class="category-tag">${item.category_name.toLowerCase()}</span>
          <span class="rating-badge">${item.avg_rating || 'new'}</span>
        </div>

        <div style="flex: 1;">
          <h3 class="item-name">${item.item_name.toLowerCase()}</h3>
          <p class="item-desc">${(item.description || '').toLowerCase()}</p>
        </div>

        <div class="menu-card-footer">
          <div class="item-price">rs ${Number(item.price).toFixed(2)}</div>
          <div>
            ${!isAvail ? `
              <button class="btn-add" disabled>sold out</button>
            ` : qty > 0 ? `
              <div class="qty-control">
                <button class="qty-btn" data-action="dec" data-id="${item.item_id}">-</button>
                <span class="qty-val">${qty}</span>
                <button class="qty-btn" data-action="inc" data-id="${item.item_id}">+</button>
              </div>
            ` : `
              <button class="btn-add" data-action="add" data-id="${item.item_id}">add</button>
            `}
          </div>
        </div>
      </div>
    `;
  }).join('');

  container.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', () => {
      const action = btn.dataset.action;
      const itemId = parseInt(btn.dataset.id, 10);
      const item = items.find(i => i.item_id === itemId);
      const curCanteen = canteens.find(c => c.canteen_id === currentCanteenId) || canteens[0] || { canteen_id: 1, name: 'jiit annapurna' };

      if (action === 'add' || action === 'inc') {
        addToCart(item, curCanteen);
      } else if (action === 'dec') {
        removeFromCart(item.item_id);
      }
      renderMenuItems(items);
    });
  });
}

function setupSearchInput() {
  const searchInput = document.getElementById('menu-search');
  if (!searchInput) return;
  searchInput.addEventListener('input', (e) => {
    currentSearch = e.target.value.trim();
    loadMenuForCurrentCanteen();
  });
}

function addToCart(item, canteen) {
  // ek time pe ek hi canteen se mangwa sakte
  if (cart.length > 0 && cart[0].canteen_id !== canteen.canteen_id) {
    if (!confirm(`clear cart from "${cart[0].canteen_name}" and start fresh with "${canteen.name}"?`)) {
      return;
    }
    cart = [];
  }

  const existing = cart.find(i => i.item_id === item.item_id);
  if (existing) {
    existing.quantity += 1;
  } else {
    cart.push({
      item_id: item.item_id,
      item_name: item.item_name,
      price: Number(item.price),
      quantity: 1,
      canteen_id: canteen.canteen_id,
      canteen_name: canteen.name
    });
  }
  updateCartBadge();
  showToast(`added "${item.item_name.toLowerCase()}"`, 'ok');
}

function removeFromCart(itemId) {
  const idx = cart.findIndex(i => i.item_id === itemId);
  if (idx !== -1) {
    if (cart[idx].quantity > 1) {
      cart[idx].quantity -= 1;
    } else {
      cart.splice(idx, 1);
    }
  }
  updateCartBadge();
}

function updateCartBadge() {
  const count = cart.reduce((acc, i) => acc + i.quantity, 0);
  const badge = document.getElementById('cart-badge');
  if (badge) badge.textContent = count;
}

function updateCartSummaryHeader() {
  const student = STUDENTS.find(s => s.student_id === currentStudentId);
  const checkoutStudent = document.getElementById('checkout-student-name');
  if (checkoutStudent && student) {
    checkoutStudent.textContent = `${student.name.toLowerCase()} (${student.department.toLowerCase()})`;
  }
}

function renderCartView() {
  updateCartSummaryHeader();
  const container = document.getElementById('cart-items-container');
  const btnPlaceOrder = document.getElementById('btn-place-order');
  const checkoutCanteen = document.getElementById('checkout-canteen-name');
  const checkoutSubtotal = document.getElementById('checkout-subtotal');
  const checkoutTotal = document.getElementById('checkout-total');

  if (cart.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 3rem 1rem; color: var(--text-muted);">
        <p style="font-size: 0.85rem;">[ empty cart ]</p>
        <button class="btn-primary" style="max-width: 180px; margin: 1rem auto 0;" onclick="window.switchView('menu')">browse menu</button>
      </div>
    `;
    checkoutCanteen.textContent = '-';
    checkoutSubtotal.textContent = '0.00';
    checkoutTotal.textContent = '0.00';
    btnPlaceOrder.disabled = true;
    return;
  }

  const canteenName = cart[0].canteen_name;
  checkoutCanteen.textContent = canteenName.toLowerCase();

  const subtotal = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  checkoutSubtotal.textContent = subtotal.toFixed(2);
  checkoutTotal.textContent = subtotal.toFixed(2);
  btnPlaceOrder.disabled = false;

  container.innerHTML = `
    <table class="cart-table">
      <thead>
        <tr>
          <th>item</th>
          <th>price</th>
          <th>qty</th>
          <th>subtotal</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        ${cart.map(item => `
          <tr>
            <td>
              <div class="cart-item-info">
                <span class="cart-item-title">${item.item_name.toLowerCase()}</span>
              </div>
            </td>
            <td>rs ${item.price.toFixed(2)}</td>
            <td>
              <div class="qty-control">
                <button class="qty-btn" data-cart-action="dec" data-id="${item.item_id}">-</button>
                <span class="qty-val">${item.quantity}</span>
                <button class="qty-btn" data-cart-action="inc" data-id="${item.item_id}">+</button>
              </div>
            </td>
            <td><strong>rs ${(item.price * item.quantity).toFixed(2)}</strong></td>
            <td>
              <button style="background:transparent; border:none; color:var(--text-muted); cursor:pointer; font-family:inherit; font-size:0.75rem;" data-cart-action="del" data-id="${item.item_id}">[x]</button>
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;

  container.querySelectorAll('[data-cart-action]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = parseInt(btn.dataset.id, 10);
      const action = btn.dataset.cartAction;
      if (action === 'inc') {
        const item = cart.find(i => i.item_id === id);
        if (item) item.quantity += 1;
      } else if (action === 'dec') {
        removeFromCart(id);
      } else if (action === 'del') {
        cart = cart.filter(i => i.item_id !== id);
      }
      updateCartBadge();
      renderCartView();
    });
  });
}

function setupCheckoutButton() {
  const btn = document.getElementById('btn-place-order');
  if (!btn) return;
  btn.addEventListener('click', async () => {
    if (cart.length === 0) return;

    btn.disabled = true;
    btn.innerHTML = `<span>processing...</span>`;

    const selectedMethod = document.querySelector('input[name="payment-method"]:checked').value;
    const canteenId = cart[0].canteen_id;
    const itemsPayload = cart.map(i => ({ item_id: i.item_id, qty: i.quantity }));

    try {
      const orderResp = await apiRequest('/orders', {
        method: 'POST',
        body: JSON.stringify({
          student_id: currentStudentId,
          canteen_id: canteenId,
          items: itemsPayload
        })
      });

      const newOrderId = orderResp.order_id;
      showToast(`order #${newOrderId} placed`, 'ok');

      await apiRequest('/payments', {
        method: 'POST',
        body: JSON.stringify({
          order_id: newOrderId,
          method: selectedMethod
        })
      });
      showToast(`payment confirmed via ${selectedMethod.toLowerCase()}`, 'ok');

      cart = [];
      updateCartBadge();
      activeOrderId = newOrderId;
      switchView('tracker');
      loadActiveOrder();
    } catch (err) {
      showToast(err.message, 'err');
    } finally {
      btn.disabled = false;
      btn.innerHTML = `<span>place order</span>`;
    }
  });
}

async function loadActiveOrder() {
  if (!activeOrderId) return;
  try {
    const order = await apiRequest(`/orders/${activeOrderId}`);
    renderTrackerView(order);

    if (!['COMPLETED', 'CANCELLED'].includes(order.status)) {
      if (trackerTimer) clearTimeout(trackerTimer);
      // baar baar puchh rahe bana ki nahi
      trackerTimer = setTimeout(() => {
        if (document.getElementById('view-tracker')?.classList.contains('active')) {
          loadActiveOrder();
        }
      }, 3500);
    }
  } catch (err) {
    showToast(`tracker error: ${err.message}`, 'err');
  }
}

function renderTrackerView(order) {
  const container = document.getElementById('tracker-card');
  if (!container) return;
  const statuses = ['PLACED', 'CONFIRMED', 'PREPARING', 'READY', 'COMPLETED'];
  const currentIndex = statuses.indexOf(order.status);
  const isCancelled = order.status === 'CANCELLED';
  const progressPercent = currentIndex >= 0 ? (currentIndex / (statuses.length - 1)) * 100 : 0;

  container.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 1px solid var(--border); padding-bottom: 1rem; margin-bottom: 1rem;">
      <div>
        <h2 style="font-size: 1.1rem; font-weight: 700;">order #${order.order_id}</h2>
        <div style="color: var(--text-muted); font-size: 0.75rem; margin-top: 0.2rem;">
          ${order.order_date} &bull; ${order.order_time}
        </div>
      </div>
      <div>
        <span class="status-badge">${order.status.toLowerCase()}</span>
      </div>
    </div>

    ${isCancelled ? `
      <div style="margin: 1.5rem 0; padding: 1rem; background: var(--surface-alt); border: 1px solid var(--border); border-radius: var(--radius-sm); text-align: center;">
        <h4 style="font-weight: 700;">[ order cancelled ]</h4>
        <p style="font-size: 0.78rem; color: var(--text-muted); margin-top: 0.25rem;">ingredients restored to inventory.</p>
      </div>
    ` : `
      <div class="order-stepper">
        <div class="stepper-progress" style="width: ${progressPercent}%;"></div>
        ${statuses.map((st, idx) => {
          const isDone = idx < currentIndex;
          const isActive = idx === currentIndex;
          return `
            <div class="step-node ${isDone ? 'completed' : ''} ${isActive ? 'active' : ''}">
              <div class="step-circle">${isDone ? 'ok' : String(idx + 1)}</div>
              <div class="step-label">${st.toLowerCase()}</div>
            </div>
          `;
        }).join('')}
      </div>
    `}

    <div style="background: var(--surface-alt); padding: 1rem; border-radius: var(--radius-sm); margin-bottom: 1.25rem;">
      <h4 style="font-size: 0.75rem; color: var(--text-muted); margin-bottom: 0.5rem;">line items</h4>
      <div style="display: flex; flex-direction: column; gap: 0.4rem;">
        ${order.items.map(i => `
          <div style="display: flex; justify-content: space-between; font-size: 0.8rem;">
            <span>${i.quantity}x ${i.item_name.toLowerCase()}</span>
            <strong>rs ${Number(i.subtotal).toFixed(2)}</strong>
          </div>
        `).join('')}
        <div style="border-top: 1px solid var(--border); padding-top: 0.5rem; margin-top: 0.4rem; display: flex; justify-content: space-between; font-size: 0.95rem; font-weight: 700;">
          <span>total</span>
          <span>rs ${Number(order.total_amount).toFixed(2)}</span>
        </div>
      </div>
    </div>

    <div style="display: flex; justify-content: space-between; align-items: center; gap: 1rem;">
      <div style="font-size: 0.75rem; color: var(--text-muted);">
        payment: <strong>${order.payment ? `${order.payment.method.toLowerCase()} (${order.payment.status.toLowerCase()})` : 'pending'}</strong>
      </div>

      <div style="display: flex; gap: 0.5rem;">
        ${['PLACED', 'CONFIRMED'].includes(order.status) ? `
          <button class="btn-add" id="btn-cancel-order">
            cancel order
          </button>
        ` : ''}
        <button class="btn-add" onclick="window.switchView('history')">
          view history
        </button>
      </div>
    </div>
  `;

  const btnCancel = document.getElementById('btn-cancel-order');
  if (btnCancel) {
    btnCancel.addEventListener('click', async () => {
      if (!confirm(`cancel order #${order.order_id}?`)) return;
      try {
        await apiRequest(`/orders/${order.order_id}/cancel`, { method: 'POST' });
        showToast(`order #${order.order_id} cancelled`, 'info');
        loadActiveOrder();
      } catch (err) {
        showToast(err.message, 'err');
      }
    });
  }
}

async function loadOrderHistory() {
  const container = document.getElementById('history-container');
  if (!container) return;
  try {
    const orders = await apiRequest(`/students/${currentStudentId}/orders`);

    if (!orders || orders.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 3rem 1rem; color: var(--text-muted); background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-sm);">
          <p style="font-size: 0.85rem;">[ no orders found for this user ]</p>
        </div>
      `;
      return;
    }

    container.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 0.75rem;">
        ${orders.map(order => `
          <div class="cart-items-card" style="padding: 1rem;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.6rem;">
              <div>
                <h4 style="font-weight: 700; font-size: 0.95rem;">order #${order.order_id}</h4>
                <div style="font-size: 0.72rem; color: var(--text-muted);">
                  ${order.order_date} &bull; ${order.order_time}
                </div>
              </div>
              <div style="display: flex; align-items: center; gap: 0.5rem;">
                <span class="status-badge">${order.status.toLowerCase()}</span>
                <button class="btn-add" data-track-id="${order.order_id}">
                  track
                </button>
              </div>
            </div>

            <div style="border-top: 1px solid var(--border-muted); padding-top: 0.6rem;">
              <div style="font-size: 0.8rem; margin-bottom: 0.4rem;">
                ${order.items.map(i => `
                  <div style="display: flex; justify-content: space-between; margin-bottom: 0.2rem;">
                    <span>${i.quantity}x ${i.item_name.toLowerCase()}</span>
                    <span>rs ${Number(i.subtotal).toFixed(2)}</span>
                  </div>
                `).join('')}
              </div>
              <div style="display: flex; justify-content: space-between; border-top: 1px solid var(--border); padding-top: 0.4rem; font-weight: 700; font-size: 0.85rem;">
                <span>total</span>
                <span>rs ${Number(order.total_amount).toFixed(2)}</span>
              </div>
            </div>
          </div>
        `).join('')}
      </div>
    `;

    container.querySelectorAll('[data-track-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        activeOrderId = parseInt(btn.dataset.trackId, 10);
        switchView('tracker');
        loadActiveOrder();
      });
    });
  } catch (err) {
    showToast(`history error: ${err.message}`, 'err');
  }
}

async function populateReviewItemsDropdown() {
  const select = document.getElementById('review-item-select');
  if (!select) return;
  try {
    const items = await apiRequest(`/menu?canteen_id=${currentCanteenId}`);
    select.innerHTML = items.map(i => `
      <option value="${i.item_id}">${i.item_name.toLowerCase()} (${i.category_name.toLowerCase()})</option>
    `).join('');
  } catch {
    // chalo koi baat nahi
  }
}

function setupReviewForm() {
  const starsContainer = document.getElementById('star-rating');
  const ratingInput = document.getElementById('review-rating-val');
  if (!starsContainer) return;

  starsContainer.querySelectorAll('[data-star]').forEach(star => {
    star.addEventListener('click', () => {
      const val = parseInt(star.dataset.star, 10);
      ratingInput.value = val;
      updateStarsVisual(val);
    });
  });

  function updateStarsVisual(rating) {
    starsContainer.querySelectorAll('[data-star]').forEach(star => {
      const starNum = parseInt(star.dataset.star, 10);
      star.style.color = starNum <= rating ? '#ffffff' : 'var(--text-muted)';
    });
  }
  updateStarsVisual(5);

  const form = document.getElementById('review-form');
  if (!form) return;
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const itemId = parseInt(document.getElementById('review-item-select').value, 10);
    const rating = parseInt(ratingInput.value, 10);
    const comment = document.getElementById('review-comment').value.trim();

    try {
      await apiRequest('/reviews', {
        method: 'POST',
        body: JSON.stringify({
          student_id: currentStudentId,
          item_id: itemId,
          rating: rating,
          comment: comment
        })
      });
      showToast('review submitted', 'ok');
      form.reset();
      updateStarsVisual(5);
    } catch (err) {
      showToast(err.message, 'err');
    }
  });
}

function setupAdminSubtabs() {
  document.querySelectorAll('.admin-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.admin-tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.admin-subpanel').forEach(p => p.style.display = 'none');

      tab.classList.add('active');
      const targetPanel = document.getElementById(`subpanel-${tab.dataset.subtab}`);
      if (targetPanel) targetPanel.style.display = 'block';

      if (tab.dataset.subtab === 'kitchen') loadKitchenOrders();
      if (tab.dataset.subtab === 'low-stock') loadLowStock();
      if (tab.dataset.subtab === 'suggestions') loadRestockSuggestions();
      if (tab.dataset.subtab === 'top-items') loadTopItems();
      if (tab.dataset.subtab === 'sales') loadSalesReport();
    });
  });
}

async function loadAdminDashboard() {
  loadKitchenOrders();
  loadLowStock();
  loadRestockSuggestions();
}

async function loadKitchenOrders() {
  const container = document.getElementById('kitchen-orders-container');
  if (!container) return;
  try {
    const orders = await apiRequest(`/students/${currentStudentId}/orders`).catch(() => []);

    if (orders.length === 0) {
      container.innerHTML = `<p style="font-size:0.8rem; color:var(--text-muted); padding:1rem 0;">[ no orders in queue ]</p>`;
      return;
    }

    container.innerHTML = `
      <table class="data-table">
        <thead>
          <tr>
            <th>order id</th>
            <th>total</th>
            <th>status</th>
            <th>actions</th>
          </tr>
        </thead>
        <tbody>
          ${orders.map(o => {
            const nextStatusMap = {
              'PLACED': 'CONFIRMED',
              'CONFIRMED': 'PREPARING',
              'PREPARING': 'READY',
              'READY': 'COMPLETED'
            };
            const nextStatus = nextStatusMap[o.status];

            return `
              <tr>
                <td><strong>#${o.order_id}</strong></td>
                <td>rs ${Number(o.total_amount).toFixed(2)}</td>
                <td><span class="status-badge">${o.status.toLowerCase()}</span></td>
                <td>
                  <div style="display: flex; gap: 0.3rem;">
                    ${nextStatus ? `
                      <button class="btn-add" data-advance-id="${o.order_id}" data-new-status="${nextStatus}">
                        mark ${nextStatus.toLowerCase()}
                      </button>
                    ` : '<span style="color:var(--text-muted); font-size:0.75rem;">completed</span>'}
                    ${['PLACED', 'CONFIRMED'].includes(o.status) ? `
                      <button class="btn-add" style="color:var(--text-muted);" data-cancel-id="${o.order_id}">
                        cancel
                      </button>
                    ` : ''}
                  </div>
                </td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    `;

    container.querySelectorAll('[data-advance-id]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const oid = parseInt(btn.dataset.advanceId, 10);
        const st = btn.dataset.newStatus;
        try {
          await apiRequest(`/orders/${oid}/status`, {
            method: 'PATCH',
            body: JSON.stringify({ status: st })
          });
          showToast(`order #${oid} moved to ${st.toLowerCase()}`, 'ok');
          loadKitchenOrders();
        } catch (err) {
          showToast(err.message, 'err');
        }
      });
    });

    container.querySelectorAll('[data-cancel-id]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const oid = parseInt(btn.dataset.cancelId, 10);
        try {
          await apiRequest(`/orders/${oid}/cancel`, { method: 'POST' });
          showToast(`order #${oid} cancelled`, 'info');
          loadKitchenOrders();
        } catch (err) {
          showToast(err.message, 'err');
        }
      });
    });
  } catch (err) {
    showToast(`kitchen error: ${err.message}`, 'err');
  }
}

async function loadLowStock() {
  const container = document.getElementById('low-stock-container');
  if (!container) return;
  try {
    const list = await apiRequest('/admin/inventory/low-stock');
    const alertsEl = document.getElementById('kpi-alerts');
    if (alertsEl) alertsEl.textContent = `${list.length} items`;

    container.innerHTML = `
      <table class="data-table">
        <thead>
          <tr>
            <th>item</th>
            <th>available</th>
            <th>reorder level</th>
            <th>shortfall</th>
          </tr>
        </thead>
        <tbody>
          ${list.map(i => `
            <tr>
              <td><strong>${i.item_name.toLowerCase()}</strong></td>
              <td>${Number(i.quantity_available)} ${i.unit}</td>
              <td>${Number(i.reorder_level)} ${i.unit}</td>
              <td style="color: #ffffff; font-weight: 700;">-${Number(i.shortfall)} ${i.unit}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    showToast(`inventory error: ${err.message}`, 'err');
  }
}

async function loadRestockSuggestions() {
  const container = document.getElementById('suggestions-container');
  if (!container) return;
  try {
    const list = await apiRequest('/admin/restock-suggestions');

    container.innerHTML = `
      <table class="data-table">
        <thead>
          <tr>
            <th>ingredient</th>
            <th>current</th>
            <th>suggested</th>
            <th>supplier</th>
            <th>action</th>
          </tr>
        </thead>
        <tbody>
          ${list.map(s => `
            <tr>
              <td><strong>${s.item_name.toLowerCase()}</strong></td>
              <td>${Number(s.current_qty)} ${s.unit}</td>
              <td style="font-weight: 700;">+${Number(s.suggested_qty)} ${s.unit}</td>
              <td>${(s.last_supplier_name || 'preferred vendor').toLowerCase()}</td>
              <td>
                <button class="btn-add" data-prefill-id="${s.inventory_id}" data-prefill-qty="${s.suggested_qty}">
                  po
                </button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;

    container.querySelectorAll('[data-prefill-id]').forEach(btn => {
      btn.addEventListener('click', () => {
        openPurchaseModal(parseInt(btn.dataset.prefillId, 10), parseFloat(btn.dataset.prefillQty));
      });
    });
  } catch (err) {
    showToast(`suggestions error: ${err.message}`, 'err');
  }
}

async function loadTopItems() {
  const container = document.getElementById('top-items-container');
  if (!container) return;
  try {
    const items = await apiRequest('/admin/reports/top-items');

    container.innerHTML = `
      <table class="data-table">
        <thead>
          <tr>
            <th>rank</th>
            <th>item</th>
            <th>category</th>
            <th>ordered</th>
            <th>revenue</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(item => `
            <tr>
              <td><strong>#${item.item_rank}</strong></td>
              <td>${item.item_name.toLowerCase()}</td>
              <td>${item.category_name.toLowerCase()}</td>
              <td>${item.quantity_ordered}</td>
              <td>rs ${Number(item.revenue).toFixed(2)}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    showToast(`top items error: ${err.message}`, 'err');
  }
}

async function loadSalesReport() {
  const container = document.getElementById('sales-report-container');
  if (!container) return;
  try {
    const report = await apiRequest('/admin/reports/sales');

    container.innerHTML = `
      <table class="data-table">
        <thead>
          <tr>
            <th>date</th>
            <th>outlet</th>
            <th>orders</th>
            <th>revenue</th>
          </tr>
        </thead>
        <tbody>
          ${report.map(r => `
            <tr>
              <td>${r.sales_date}</td>
              <td>${r.canteen_name.toLowerCase()}</td>
              <td>${r.orders_count}</td>
              <td>rs ${Number(r.total_sales).toFixed(2)}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    showToast(`sales error: ${err.message}`, 'err');
  }
}

function setupAuditLogInspector() {
  const btn = document.getElementById('btn-fetch-audit');
  if (!btn) return;
  btn.addEventListener('click', async () => {
    const input = document.getElementById('audit-order-id-input');
    const orderId = parseInt(input.value, 10);
    const container = document.getElementById('audit-log-results');

    if (!orderId) {
      showToast('enter order id', 'err');
      return;
    }

    try {
      const logs = await apiRequest(`/admin/audit-log/${orderId}`);
      if (!logs || logs.length === 0) {
        container.innerHTML = `<p style="color: var(--text-muted); padding: 0.5rem 0; font-size:0.8rem;">[ no audit records found for order #${orderId} ]</p>`;
        return;
      }

      container.innerHTML = `
        <div style="border-left: 2px solid var(--border); padding-left: 1rem; display: flex; flex-direction: column; gap: 0.6rem;">
          ${logs.map(log => `
            <div>
              <div style="font-size: 0.8rem;">
                ${log.old_status ? `${log.old_status.toLowerCase()} &rarr; ` : 'created as '}
                <strong>${log.new_status.toLowerCase()}</strong>
              </div>
              <div style="font-size: 0.7rem; color: var(--text-muted);">
                ${new Date(log.changed_at).toLocaleTimeString()}
              </div>
            </div>
          `).join('')}
        </div>
      `;
    } catch (err) {
      showToast(err.message, 'err');
    }
  });
}

function openPurchaseModal(inventoryId = 5, suggestedQty = 20) {
  const modal = document.getElementById('purchase-modal');
  if (!modal) return;
  modal.classList.add('active');
  const invSelect = document.getElementById('purchase-inventory-id');
  if (inventoryId && invSelect) invSelect.value = inventoryId;
  const qtyInput = document.getElementById('purchase-qty');
  if (suggestedQty && qtyInput) qtyInput.value = suggestedQty;
  const costInput = document.getElementById('purchase-cost');
  if (costInput) costInput.value = (suggestedQty * 50).toFixed(0);
}

function setupPurchaseModal() {
  const modal = document.getElementById('purchase-modal');
  const btnOpen = document.getElementById('btn-open-purchase-modal');
  const btnClose = document.getElementById('purchase-modal-close');
  const form = document.getElementById('purchase-form');

  if (btnOpen) btnOpen.addEventListener('click', () => openPurchaseModal());
  if (btnClose) btnClose.addEventListener('click', () => modal.classList.remove('active'));

  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const canteenId = parseInt(document.getElementById('purchase-canteen-id').value, 10);
      const supplierId = parseInt(document.getElementById('purchase-supplier-id').value, 10);
      const inventoryId = parseInt(document.getElementById('purchase-inventory-id').value, 10);
      const qty = parseFloat(document.getElementById('purchase-qty').value);
      const cost = parseFloat(document.getElementById('purchase-cost').value);

      try {
        const resp = await apiRequest('/admin/purchases', {
          method: 'POST',
          body: JSON.stringify({
            supplier_id: supplierId,
            inventory_id: inventoryId,
            canteen_id: canteenId,
            quantity: qty,
            cost: cost
          })
        });
        showToast(`purchase po #${resp.purchase_id} saved`, 'ok');
        modal.classList.remove('active');
        form.reset();
        loadLowStock();
        loadRestockSuggestions();
      } catch (err) {
        showToast(err.message, 'err');
      }
    });
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  setupNavigation();
  setupStudentPicker();
  setupSearchInput();
  setupCheckoutButton();
  setupReviewForm();
  setupAdminSubtabs();
  setupAuditLogInspector();
  setupPurchaseModal();

  await loadCanteensAndMenu();
});