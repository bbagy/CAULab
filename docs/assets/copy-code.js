document.querySelectorAll('pre > code').forEach((code) => {
  const pre = code.parentElement;
  const wrapper = document.createElement('div');
  wrapper.className = 'code-block';
  pre.before(wrapper);
  wrapper.append(pre);

  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'copy-code';
  button.setAttribute('aria-label', '코드 복사');
  button.title = '코드 복사';
  button.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V4a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h4"/></svg>';
  const copyIcon = button.innerHTML;
  const status = document.createElement('span');
  status.className = 'copy-status';
  status.setAttribute('role', 'status');
  wrapper.append(button, status);

  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(code.textContent);
      button.innerHTML = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m5 12 4 4 10-10"/></svg>';
      button.title = '복사됨';
      status.textContent = '코드를 복사했습니다.';
    } catch {
      button.title = '복사 실패';
      status.textContent = '복사하지 못했습니다. 코드를 직접 선택해 복사하세요.';
    }
    setTimeout(() => {
      button.innerHTML = copyIcon;
      button.title = '코드 복사';
      status.textContent = '';
    }, 2000);
  });
});
