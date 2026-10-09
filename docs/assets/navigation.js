document.querySelectorAll('.pipeline-menu').forEach(menu => {
  const summary = menu.querySelector('summary');
  let pinned = false;
  menu.addEventListener('pointerenter', event => {
    if (event.pointerType === 'mouse') menu.open = true;
  });
  menu.addEventListener('pointerleave', () => {
    if (!pinned && !menu.contains(document.activeElement)) menu.open = false;
  });
  summary.addEventListener('click', event => {
    event.preventDefault();
    pinned = !pinned;
    menu.open = pinned;
  });
  menu.addEventListener('focusout', event => {
    if (!pinned && !menu.contains(event.relatedTarget)) menu.open = false;
  });
  document.addEventListener('pointerdown', event => {
    if (!menu.contains(event.target)) { pinned = false; menu.open = false; }
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && menu.open) {
      pinned = false;
      if (menu.contains(document.activeElement)) summary.focus();
      menu.open = false;
    }
  });
});
