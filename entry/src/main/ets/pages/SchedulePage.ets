import { Course } from '../model/Types'
import { Dark } from '../common/Theme'
import { activeInWeek } from '../services/CampusRules'

@Component
export struct SchedulePage {
  @Prop courses: Course[] = []
  @Prop weekNumber: number = 0
  @Prop isDark: boolean = false
  onAddCourse?: () => void
  onEditCourse?: (course: Course) => void
  onImportCourse?: () => void

  private weekdays: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
  @State private selectedWeekday: number = this.getTodayWeekday()

  build() {
    Column() {
      // 顶部标题 + 第X周 + 新增按钮
      Row() {
        Column() {
          Row() {
            Text('本周课表')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isDark ? Dark.textPrimary : '#24262B')
            if (this.weekNumber > 0) {
              Text(`  第 ${this.weekNumber} 周`)
                .fontSize(14)
                .fontColor(this.isDark ? '#A9BEDA' : '#5475A8')
            }
          }
          Text('点击上方星期切换查看不同天的课程')
            .fontSize(11)
            .fontColor(this.isDark ? Dark.textMuted : '#989DA6')
        }
        Blank()
        Row() {
          Button('导入')
            .height(34)
            .backgroundColor(this.isDark ? Dark.accentBg : '#EEF2F8')
            .fontColor(this.isDark ? '#A9BEDA' : '#5475A8')
            .borderRadius(18)
            .onClick(() => {
              if (this.onImportCourse) {
                this.onImportCourse()
              }
            })
          Button('新增课程')
            .height(34)
            .margin({ left: 8 })
            .backgroundColor(this.isDark ? '#5475A8' : '#5475A8')
            .fontColor('#FFFFFF')
            .borderRadius(18)
            .onClick(() => {
              if (this.onAddCourse) {
                this.onAddCourse()
              }
            })
        }
      }
      .margin({ top: 16, left: 20, right: 20, bottom: 8 })

      // 星期选择条
      Scroll() {
        Row() {
        ForEach(this.weekdays, (label: string, index: number) => {
          Column() {
            Text(label)
              .fontSize(13)
              .fontColor(this.selectedWeekday === index + 1 ? (this.isDark ? '#A9BEDA' : '#5475A8') : (this.isDark ? Dark.textSecondary : '#858992'))
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .margin({ right: 6 })
          .backgroundColor(this.selectedWeekday === index + 1 ? (this.isDark ? Dark.accentBg : '#EEF2F8') : (this.isDark ? Dark.bgCard : '#F2F4F7'))
          .borderRadius(16)
          .onClick(() => {
            this.selectedWeekday = index + 1
          })
        })
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        .width('100%').padding({ left: 20, right: 20, bottom: 8 })

      // 当天课程列表，可滚动
      Scroll() {
        Column() {
          ForEach(this.getCoursesForDaySorted(this.selectedWeekday), (course: Course) => {
            Column() {
              Text(course.name)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isDark ? Dark.textPrimary : '#24262B')
                .margin({ bottom: 6 })
              Text(`${course.classroom}`)
                .fontSize(13)
                .fontColor(this.isDark ? Dark.textSecondary : '#858992')
              Text(`${course.time}`)
                .fontSize(13)
                .fontColor(this.isDark ? Dark.textSecondary : '#858992')
                .margin({ top: 4 })
            }
            .padding({ left: 18, right: 18, top: 14, bottom: 14 })
            .margin({ left: 20, right: 20, top: 10, bottom: 10 })
            .backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF')
            .borderRadius(18)
            .shadow({ radius: 12, color: this.isDark ? Dark.cardShadow : '#00000014', offsetX: 0, offsetY: 4 })
            .onClick(() => {
              if (this.onEditCourse) {
                this.onEditCourse(course)
              }
            })
          })

          if (this.getCoursesForDaySorted(this.selectedWeekday).length === 0) {
            Column() {
              Text('这一天还没有安排课程')
                .fontSize(14)
                .fontColor(this.isDark ? Dark.textMuted : '#989DA6')
              Text('点击右上角「新增课程」添加吧～')
                .fontSize(12)
                .fontColor(this.isDark ? Dark.borderLight : '#D1D5DB')
                .margin({ top: 6 })
            }
            .margin({ top: 24 })
          }
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  private getTodayWeekday(): number {
    const now = new Date()
    const jsDay = now.getDay() // 0-6, 周日=0
    if (jsDay === 0) {
      return 7
    }
    return jsDay
  }

  private getCoursesForDaySorted(day: number): Course[] {
    const list: Course[] = this.courses.filter((c: Course) => c.weekday === day && activeInWeek(c, this.weekNumber || 1))
    list.sort((a: Course, b: Course) => {
      return this.getStartMinutes(a.time) - this.getStartMinutes(b.time)
    })
    return list
  }

  private getStartMinutes(time: string): number {
    // 期望格式：'HH:MM - HH:MM'
    const parts = time.split('-')
    if (parts.length === 0) {
      return 0
    }
    const start = parts[0].trim()
    const hm = start.split(':')
    if (hm.length < 2) {
      return 0
    }
    const h = Number.parseInt(hm[0])
    const m = Number.parseInt(hm[1])
    if (Number.isNaN(h) || Number.isNaN(m)) {
      return 0
    }
    return h * 60 + m
  }
}

