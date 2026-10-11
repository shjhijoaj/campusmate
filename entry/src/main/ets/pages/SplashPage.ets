/**
 * 开屏页：生动流畅的入场动画 + 有辨识度的 Logo
 * Logo 设计：书本轮廓 + 圆点（完成/伙伴），寓意课表与待办一体
 */
@Component
export struct SplashPage {
  onFinish?: () => void

  @State private logoScale: number = 0.5
  @State private logoOpacity: number = 0
  @State private logoRotate: number = -8
  @State private textOpacity: number = 0
  @State private textTranslateY: number = 28
  @State private taglineOpacity: number = 0
  @State private splashOpacity: number = 1

  aboutToAppear(): void {
    const runAnim = () => {
      // 第一阶段：Logo 弹性入场（缩放 + 淡入 + 微旋转）
      animateTo({ duration: 700, curve: Curve.FastOutSlowIn }, () => {
        this.logoScale = 1
        this.logoOpacity = 1
        this.logoRotate = 0
      })
      // 第二阶段：标题与副标题依次滑入
      setTimeout(() => {
        animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
          this.textOpacity = 1
          this.textTranslateY = 0
        })
      }, 350)
      setTimeout(() => {
        animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
          this.taglineOpacity = 1
        })
      }, 550)
      // 第三阶段：停留后淡出并结束
      setTimeout(() => {
        animateTo({ duration: 450, curve: Curve.EaseInOut }, () => {
          this.splashOpacity = 0
        })
        setTimeout(() => {
          if (this.onFinish) {
            this.onFinish()
          }
        }, 460)
      }, 2400)
    }
    setTimeout(runAnim, 80)
  }

  build() {
    Stack() {
      // 渐变背景：深蓝到浅蓝再到白
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [
            ['#1E3A5F', 0],
            ['#2563EB', 0.35],
            ['#60A5FA', 0.7],
            ['#E0F2FE', 1]
          ]
        })

      Column() {
        Blank().layoutWeight(0.6)

        // Logo 区域：书本 + 圆点（书本寓意课表，圆点寓意待办完成）
        Stack() {
          // 书本主体：双页 + 书脊
          Row() {
            Column()
              .width(36)
              .height(48)
              .borderRadius(12)
              .backgroundColor('#FFFFFF')
              .opacity(0.95)
            Column()
              .width(4)
              .height(48)
              .borderRadius(2)
              .backgroundColor('#1E3A5F')
              .opacity(0.4)
            Column()
              .width(36)
              .height(48)
              .borderRadius(12)
              .backgroundColor('#FFFFFF')
              .opacity(0.95)
          }
          .width(76)
          .height(48)
          .justifyContent(FlexAlign.SpaceBetween)

          // 右上角“完成/伙伴”圆点
          Circle()
            .width(18)
            .height(18)
            .backgroundColor('#34D399')
            .border({ width: 3, color: '#FFFFFF' })
            .margin({ top: -22, left: 52 })
        }
        .width(80)
        .height(52)
        .scale({ x: this.logoScale, y: this.logoScale })
        .opacity(this.logoOpacity)
        .rotate({ angle: this.logoRotate })

        Blank().height(32)

        // 应用名
        Text('CampusMate')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .opacity(this.textOpacity)
          .translate({ y: this.textTranslateY })

        Text('你的校园事务助手')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.88)')
          .margin({ top: 8 })
          .opacity(this.taglineOpacity)

        Blank().layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .opacity(this.splashOpacity)
  }
}
