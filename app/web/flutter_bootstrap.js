{{flutter_js}}
{{flutter_build_config}}

// 載入畫面（index.html 的 #loader）：引擎初始化時顯示進度字，App 畫出第一幀後淡出移除。
(function () {
  const loader = document.getElementById('loader');
  const status = document.getElementById('loader-status');
  const say = (t) => { if (status) status.textContent = t; };
  const done = () => {
    if (!loader) return;
    loader.classList.add('gone');
    setTimeout(() => loader.remove(), 600);
  };
  // Flutter 畫出第一幀時會發這個事件
  window.addEventListener('flutter-first-frame', done, { once: true });

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      say('準備籤筒…');
      const appRunner = await engineInitializer.initializeEngine();
      say('請稍候…');
      await appRunner.runApp();
      setTimeout(done, 8000); // 保險：萬一沒收到第一幀事件也別一直擋著
    },
  }).catch(function () {
    say('載入失敗，請重新整理頁面');
  });
})();
