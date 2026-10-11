import { Course, Task } from '../model/Types'
import { Dark } from '../common/Theme'
import { activeInWeek } from '../services/CampusRules'

@Component
export struct HomePage {
  @Prop courses: Course[] = []
  @Prop tasks: Task[] = []
  @Prop nickname: string = ''
  @Prop weekNumber: number = 0
  @Prop isDark: boolean = false
  onAddTodo?: () => void
  private taskTypes: string[] = ['作业', '考试', '项目', '其他']

  build() {
    Column() {
      // 今日状态一句文案（小情趣）
      if (this.getTodayStatusLine().length > 0) {
        Text(this.getTodayStatusLine())
          .fontSize(13)
          .fontColor(this.isDark ? Dark.textSecondary : '#6B7280')
          .margin({ top: 12, left: 20, right: 20 })
      }

      // 顶部：学习概览 + 任务类型图表（固定在上方）
      this.buildSummarySection()

      // 快捷添加待办入口
      if (this.onAddTodo) {
        Row() {
          Text('+ 添加待办')
            .fontSize(14)
            .fontColor(this.isDark ? '#7CAAFF' : '#2563EB')
          Text(' 去待办页新增')
            .fontSize(12)
            .fontColor(this.isDark ? Dark.textMuted : '#9CA3AF')
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(this.isDark ? Dark.accentBg : '#E0ECFF')
        .borderRadius(12)
        .margin({ left: 20, right: 20, bottom: 8 })
        .onClick(() => {
          if (this.onAddTodo) {
            this.onAddTodo()
          }
        })
      }

      // 下面内容可适度滚动，保证小屏幕也能看到全部信息
      Scroll() {
        Column() {
          // 中间：今日课程
          this.buildTodayCoursesSection()

          // 底部：最近待办
          this.buildRecentTasksSection()
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  // 今日状态一句动态文案：下一节课 / 剩余待办 / 今日无课无待办
  private getTodayStatusLine(): string {
    const next = this.getNextCourseToday()
    const pending = this.tasks.filter((t: Task) => !t.done).length
    if (next.length > 0) {
      return `下一节：${next}`
    }
    if (pending > 0) {
      return `还有 ${pending} 件待办，加油～`
    }
    const todayCourses = this.getTodayCourses()
    if (todayCourses.length === 0 && this.tasks.length === 0) {
      return '今天没有课也没有待办，放松一下～'
    }
    if (todayCourses.length === 0) {
      return '今天没有课，记得把待办清一清哦'
    }
    return '今天的课都上完啦，休息一下'
  }

  private getNextCourseToday(): string {
    const today = new Date()
    const jsDay = today.getDay()
    const weekday = jsDay === 0 ? 7 : jsDay
    const list = this.courses.filter((c: Course) => c.weekday === weekday)
    if (list.length === 0) {
      return ''
    }
    const nowM = today.getHours() * 60 + today.getMinutes()
    let nextName = ''
    let nextMin = 24 * 60
    list.forEach((c: Course) => {
      const parts = c.time.split('-')
      if (parts.length > 0) {
        const start = parts[0].trim().split(':')
        if (start.length >= 2) {
          const m = Number.parseInt(start[0]) * 60 + Number.parseInt(start[1])
          if (m >= nowM && m < nextMin) {
            nextMin = m
            nextName = c.name
          }
        }
      }
    })
    return nextName
  }

  // 顶部统计模块：总览 + 类型分布放在一个卡片里
  @Builder
  private buildSummarySection() {
    Column() {
      Column() {
        Text('学习概览')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDark ? Dark.textPrimary : '#111827')
          .margin({ bottom: 8 })

        Row() {
          Column() {
            Text(this.getTotalTasks().toString())
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDark ? Dark.textPrimary : '#111827')
            Text('总待办')
              .fontSize(12)
              .fontColor(this.isDark ? Dark.textSecondary : '#6B7280')
          }
          .margin({ right: 24 })

          Column() {
            Text(this.getDoneTasks().toString())
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDark ? Dark.textPrimary : '#111827')
            Text('已完成')
              .fontSize(12)
              .fontColor(this.isDark ? Dark.textSecondary : '#6B7280')
          }
          .margin({ right: 24 })

          Column() {
            Text(`${this.getPercent()}%`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isDark ? Dark.textPrimary : '#111827')
            Text('完成率')
              .fontSize(12)
              .fontColor(this.isDark ? Dark.textSecondary : '#6B7280')
          }
        }
        .margin({ bottom: 12 })

        // 在同一卡片中嵌入任务类型小柱状图
        Row() {
          ForEach(this.taskTypes, (tp: string) => {
            Column() {
              Column() {}
                .width(18)
                .height(this.getTypeBarHeight(tp))
                .backgroundColor(this.isDark ? '#5B8DEF' : '#93C5FD')
                .borderRadius(6)
              Text(tp)
                .fontSize(11)
                .fontColor(this.isDark ? Dark.textMuted : '#6B7280')
                .margin({ top: 4 })
            }
            .margin({ left: 8, right: 8, bottom: 4 })
          })
        }
        .justifyContent(FlexAlign.Center)
      }
      .padding(16)
      .backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF')
      .borderRadius(16)
      .shadow({ radius: this.isDark ? 8 : 10, color: this.isDark ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 4 })
    }
    .padding({ left: 20, right: 20, top: 16, bottom: 4 })
  }

  // 统计计算放到普通方法里，避免在 Builder 里写逻辑语句报错
  private getTotalTasks(): number {
    return this.tasks.length
  }

  private getDoneTasks(): number {
    return this.tasks.filter((t: Task) => t.done).length
  }

  private getPercent(): number {
    const total = this.getTotalTasks()
    const done = this.getDoneTasks()
    if (total === 0) {
      return 0
    }
    return Math.round(done * 100 / total)
  }

  // 今日课程区域
  @Builder
  private buildTodayCoursesSection() {
    Column() {
      Text('今日课程')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isDark ? Dark.textPrimary : '#111827')
        .margin({ bottom: 8 })

      if (this.getTodayCourses().length === 0) {
        Text('今天没有课程，安排一点自己的时间吧～')
          .fontSize(13)
          .fontColor(this.isDark ? Dark.textMuted : '#9CA3AF')
          .margin({ bottom: 8 })
      } else {
        Column() {
          ForEach(this.getTodayCourses(), (course: Course) => {
            Row() {
              Column() {
                Text(course.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isDark ? Dark.textPrimary : '#111827')
                Text(`${course.classroom} ｜ ${course.time}`)
                  .fontSize(12)
                  .fontColor(this.isDark ? Dark.textSecondary : '#6B7280')
              }
            }
            .padding(12)
            .margin({ bottom: 8 })
            .backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF')
            .borderRadius(12)
            .shadow({ radius: this.isDark ? 6 : 6, color: this.isDark ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 2 })
          })
        }
      }
    }
    .padding({ left: 20, right: 20, top: 12 })
  }

  // 最近待办区域
  @Builder
  private buildRecentTasksSection() {
    Column() {
      Text('最近待办')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isDark ? Dark.textPrimary : '#111827')
        .margin({ bottom: 8 })

      if (this.getRecentTasksForHome().length === 0) {
        Text('还没有待办，去课表页安排一点任务吧。')
          .fontSize(13)
          .fontColor(this.isDark ? Dark.textMuted : '#9CA3AF')
          .margin({ bottom: 16 })
      } else {
        if (this.getDoneTasks() === this.getTotalTasks() && this.getTotalTasks() > 0) {
          Text('全部待办都完成啦，给自己点个赞～')
            .fontSize(13)
            .fontColor('#34D399')
            .margin({ bottom: 8 })
        }
        Column() {
          ForEach(this.getRecentTasksForHome(), (task: Task) => {
            Row() {
              Column() {
                Text(task.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isDark ? Dark.textPrimary : '#111827')
                Text(`${task.type} ｜ 截止：${task.deadline}`)
                  .fontSize(12)
                  .fontColor(this.isDark ? Dark.textSecondary : '#6B7280')
              }
              Blank()
              Text(task.done ? '已完成' : '待完成')
                .fontSize(12)
                .fontColor(task.done ? '#34D399' : '#FB923C')
            }
            .padding(12)
            .margin({ bottom: 8 })
            .backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF')
            .borderRadius(12)
            .shadow({ radius: 6, color: this.isDark ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 2 })
          })
        }
      }
    }
    .padding({ left: 20, right: 20, top: 16, bottom: 24 })
  }

  private getTodayCourses(): Course[] {
    const today = new Date().getDay() || 7
    return this.courses.filter((item: Course) => item.weekday === today && activeInWeek(item, this.weekNumber || 1))
  }

  private getRecentTasksForHome(): Task[] {
    const list: Task[] = [...this.tasks]
    return list.slice(0, 5)
  }

  private getTypeCount(tp: string): number {
    return this.tasks.filter((t: Task) => t.type === tp).length
  }

  private getMaxTypeCount(): number {
    let max = 0
    this.taskTypes.forEach((tp: string) => {
      const c = this.getTypeCount(tp)
      if (c > max) {
        max = c
      }
    })
    return max
  }

  private getTypeBarHeight(tp: string): number {
    const max = this.getMaxTypeCount()
    const count = this.getTypeCount(tp)
    if (max === 0) {
      return 16
    }
    // 最小高度 16，最大高度约 80
    return 16 + Math.round(count * 64 / max)
  }
}

