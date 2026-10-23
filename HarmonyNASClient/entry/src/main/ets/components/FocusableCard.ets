/**
 * 焦点卡片：TV / 手表用遥控器/表冠导航，手机/平板退化为点击
 * - focused 时放大 1.1 倍，带缓动动画
 * - KEYCODE_ENTER / DPAD_CENTER 触发 onActivate
 */
@Component
export struct FocusableCard {
  @Prop active: boolean = false;
  @State focused: boolean = false;
  onActivate: () => void = () => {};

  @BuilderParam content: () => void = () => {};

  build() {
    Column() {
      this.content()
    }
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(this.active)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .padding(8)
    .scale(this.focused ? { x: 1.1, y: 1.1 } : { x: 1.0, y: 1.0 })
    .animation({ duration: 150, curve: Curve.EaseOut })
    .shadow(this.focused
      ? { radius: 16, color: '#33000000', offsetX: 0, offsetY: 6 }
      : { radius: 4, color: '#11000000', offsetX: 0, offsetY: 2 })
    .border(this.focused ? { width: 2, color: '#1976D2' } : { width: 0 })
    .onFocus(() => { this.focused = true; })
    .onBlur(() => { this.focused = false; })
    .onKeyEvent((e: KeyEvent) => {
      if (e.type === KeyType.Down &&
          (e.keyCode === KeyCode.KEYCODE_ENTER || e.keyCode === KeyCode.KEYCODE_DPAD_CENTER)) {
        this.onActivate();
        return true;
      }
      return false;
    })
    .onClick(() => this.onActivate())
  }
}
