export function About() {
  return (
    <section className="settings-about" aria-labelledby="about-heading" data-plain-text>
      <h3 id="about-heading">关于</h3>
      <p>键渊：失控咒典 · 词令共鸣</p>
      <dl>
        <dt>版本</dt><dd>{__APP_VERSION__}</dd>
        <dt>作者</dt><dd>Iceriny</dd>
        <dt>GitHub</dt><dd><a data-nav-order={110} href="https://github.com/iceriny/keyabyss" target="_blank" rel="noopener noreferrer">github.com/iceriny/keyabyss</a></dd>
        <dt>邮箱</dt><dd><a data-nav-order={111} href="mailto:serinamisssu@gmail.com">serinamisssu@gmail.com</a></dd>
        <dt>许可</dt><dd>{__APP_LICENSE__} · <a data-nav-order={112} href={import.meta.env.DEV ? "https://github.com/iceriny/keyabyss/blob/HEAD/LICENSE" : "./LICENSE"} target="_blank" rel="noopener noreferrer">许可全文</a></dd>
      </dl>
      <nav aria-label="项目资料">
        <a data-nav-order={113} href="https://github.com/iceriny/keyabyss/issues" target="_blank" rel="noopener noreferrer">问题反馈</a>
        <a data-nav-order={114} href={import.meta.env.DEV ? "https://github.com/iceriny/keyabyss/blob/HEAD/THIRD_PARTY_NOTICES.md" : "./THIRD-PARTY-LICENSES.txt"} target="_blank" rel="noopener noreferrer">第三方许可</a>
      </nav>
      <p className="about-note">设置、自定义词库和最近 50 份战报保存在当前浏览器中；清理浏览器数据会移除这些记录，可在词库与远征记录页导出备份。</p>
      <p className="about-note">字体：汇文明朝体、京華老宋体。感谢开源依赖与词库项目的作者和贡献者。</p>
    </section>
  );
}
