import { Course, Task } from '../model/Types'
import { Dark } from '../common/Theme'
import { activeInWeek, minutes } from '../services/CampusRules'

@Component
export struct StudioHomePage {
  @Prop courses: Course[] = []
  @Prop tasks: Task[] = []
  @Prop nickname: string = ''
  @Prop weekNumber: number = 0
  @Prop isDark: boolean = false
  onAddTodo?: () => void

  private todayCourses(): Course[] {
    const today = new Date().getDay() || 7
    return this.courses.filter((c: Course) => c.weekday === today && activeInWeek(c, this.weekNumber))
      .sort((a: Course, b: Course) => minutes(a.time.split('-')[0]) - minutes(b.time.split('-')[0]))
  }
  private pending(): Task[] { return this.tasks.filter((t: Task) => !t.done).slice(0, 3) }
  private progress(): number {
    return this.tasks.length ? Math.round(this.tasks.filter((t: Task) => t.done).length / this.tasks.length * 100) : 0
  }
  private courseColor(id: number): string {
    const colors: string[] = ['#E5ECFA', '#F7EBDD', '#E7EEE5', '#ECE7F7']
    return colors[id % colors.length]
  }

  @Builder
  private statistic(value: string, label: string) {
    Column({ space: 7 }) {
      Text(value).fontSize(28).fontWeight(FontWeight.Medium)
        .fontColor(this.isDark ? Dark.textPrimary : '#24262B')
      Text(label).fontSize(10).fontColor(this.isDark ? Dark.textSecondary : '#858992')
    }.layoutWeight(1).padding({ top: 20, bottom: 20 }).backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF').borderRadius(18)
  }

  build() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 8 }) {
          Text(`${this.weekNumber > 0 ? '第 ' + this.weekNumber.toString() + ' 周' : '学期尚未开始'} · YOUR CAMPUS, SIMPLIFIED`)
            .fontSize(9).letterSpacing(1.3).fontColor(this.isDark ? Dark.textMuted : '#989DA6')
          Text('把今天，安排得刚刚好。')
            .fontSize(26).fontWeight(FontWeight.Bold).fontColor(this.isDark ? Dark.textPrimary : '#24262B')
          Text(`${this.nickname || '同学'}，留一些时间，给真正喜欢的事。`)
            .fontSize(11).fontColor(this.isDark ? Dark.textSecondary : '#858992')
        }.width('100%').alignItems(HorizontalAlign.Start)

        Stack({ alignContent: Alignment.End }) {
          Circle().width(206).height(206).fill('#5B6577').opacity(0.45).offset({ x: 80, y: -15 })
          Circle().width(165).height(165).fill('#78859A').opacity(0.3).offset({ x: 56, y: -34 })
          Column({ space: 11 }) {
            Text('LESS CHAOS. MORE CAMPUS.').fontSize(8).letterSpacing(1.6).fontColor('#ABB3C0')
            Text('校园生活，\n可以再从容一点。').fontSize(25).fontWeight(FontWeight.Medium).fontColor('#FFFFFF').lineHeight(36)
            Text('课程、灵感与小目标，都在这里有条不紊。').fontSize(10).fontColor('#B4BAC4')
            Text(`${this.todayCourses().length} 门课程 · ${this.tasks.filter((t: Task) => !t.done).length} 件待办`)
              .fontSize(10).fontColor('#D0D4DB').padding({ left: 11, right: 11, top: 6, bottom: 6 })
              .border({ width: 0.5, color: '#5A6371' }).borderRadius(20).margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start).width('100%').padding(25)
        }.width('100%').height(218).backgroundColor('#292D34').borderRadius(22).clip(true)

        Row({ space: 10 }) {
          this.statistic(this.todayCourses().length.toString(), '今日课程')
          this.statistic(this.tasks.filter((t: Task) => !t.done).length.toString(), '待完成计划')
          this.statistic(`${this.progress()}%`, '计划完成率')
        }.width('100%')

        Column({ space: 12 }) {
          Row() {
            Text('我的一天').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.isDark ? Dark.textPrimary : '#24262B')
            Blank()
            Text('保持自己的节奏').fontSize(10).fontColor(this.isDark ? Dark.textMuted : '#989DA6')
          }.width('100%')
          ForEach(this.todayCourses(), (c: Course) => {
            Row({ space: 14 }) {
              Column({ space: 6 }) {
                Text(c.time.split('-')[0].trim()).fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.isDark ? Dark.textPrimary : '#24262B')
                Text(c.time.split('-')[1].trim()).fontSize(10).fontColor(this.isDark ? Dark.textSecondary : '#858992')
              }.width(53)
              Column() {}.width(3).height(42).backgroundColor(c.color ?? this.courseColor(c.id)).borderRadius(2)
              Column({ space: 8 }) {
                Text(c.name).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.isDark ? Dark.textPrimary : '#24262B')
                Text(`${c.classroom} · ${c.teacher || '课程安排'}`).fontSize(10).fontColor(this.isDark ? Dark.textSecondary : '#858992')
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%').padding(20).backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF').borderRadius(18)
          }, (c: Course) => c.id.toString())
          if (!this.todayCourses().length) {
            Column({ space: 8 }) {
              Text('这一天，给自己留白。').fontSize(14).fontColor(this.isDark ? Dark.textSecondary : '#858992')
              Text('没有课程，也可以有新的灵感。').fontSize(11).fontColor(this.isDark ? Dark.textMuted : '#989DA6')
            }.width('100%').padding(28).backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF').borderRadius(18)
          }
        }.width('100%')

        Column({ space: 12 }) {
          Row() {
            Text('接下来，专注这些').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.isDark ? Dark.textPrimary : '#24262B')
            Blank()
            Text('+ 新建').fontSize(12).fontColor(this.isDark ? '#A9BEDA' : '#5475A8').onClick(() => { if (this.onAddTodo) this.onAddTodo() })
          }.width('100%')
          ForEach(this.pending(), (t: Task) => {
            Row({ space: 12 }) {
              Text('○').fontSize(21).fontColor(this.isDark ? Dark.textMuted : '#CBD2DD')
              Column({ space: 7 }) {
                Text(t.title).fontSize(13).fontColor(this.isDark ? Dark.textPrimary : '#24262B')
                Text(`${t.type} · ${t.deadline}`).fontSize(10).fontColor(this.isDark ? Dark.textSecondary : '#858992')
              }.alignItems(HorizontalAlign.Start)
            }.width('100%').padding(19).backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF').borderRadius(17)
          }, (t: Task) => t.id.toString())
          if (!this.pending().length) {
            Text('计划都完成了。做得很好。').width('100%').padding(22).fontSize(12)
              .fontColor(this.isDark ? Dark.textSecondary : '#858992').backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF').borderRadius(17)
          }
        }.width('100%')
        Text('MAKE ROOM FOR WHAT MATTERS.').fontSize(8).letterSpacing(1.8).fontColor(this.isDark ? Dark.textMuted : '#A4AAB3').margin({ top: 3, bottom: 10 })
      }.padding({ top: 25, left: 22, right: 22, bottom: 24 }).width('100%')
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }
}
