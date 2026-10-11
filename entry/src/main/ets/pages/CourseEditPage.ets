import { Course } from '../model/Types'

@Component
export struct CourseEditPage {
  @Prop course: Course | null = null
  onCancel?: () => void
  onSave?: (course: Course) => void
  onDelete?: (course: Course) => void

  @State name: string = ''
  @State classroom: string = ''
  @State weekday: number = 1
  @State time: string = ''
  @State startWeek: number = 1
  @State endWeek: number = 20
  @State weekMode: 'all' | 'odd' | 'even' = 'all'
  @State private startHour: number = 8
  @State private startMinute: number = 0
  @State private endHour: number = 9
  @State private endMinute: number = 35
  @State private pickingBaseDate: Date = new Date()

  aboutToAppear() {
    if (this.course != null) {
      this.name = this.course.name
      this.classroom = this.course.classroom
      this.weekday = this.course.weekday
      this.time = this.course.time
      this.startWeek = this.course.startWeek ?? 1
      this.endWeek = this.course.endWeek ?? 20
      this.weekMode = this.course.weekMode ?? 'all'
    }
    this.parseTimeRangeToState()
    if (!this.time) this.refreshTimeText()
  }

  private parseTimeRangeToState() {
    // 期望格式：'HH:MM - HH:MM'
    const parts = this.time.split('-')
    if (parts.length < 2) {
      return
    }
    const s = parts[0].trim().split(':')
    const e = parts[1].trim().split(':')
    if (s.length < 2 || e.length < 2) {
      return
    }
    const sh = Number.parseInt(s[0])
    const sm = Number.parseInt(s[1])
    const eh = Number.parseInt(e[0])
    const em = Number.parseInt(e[1])
    if ([sh, sm, eh, em].some((n: number) => Number.isNaN(n))) {
      return
    }
    this.startHour = sh
    this.startMinute = sm
    this.endHour = eh
    this.endMinute = em
  }

  private toHm(hour: number, minute: number): string {
    const hh = hour.toString().padStart(2, '0')
    const mm = minute.toString().padStart(2, '0')
    return `${hh}:${mm}`
  }

  private refreshTimeText() {
    this.time = `${this.toHm(this.startHour, this.startMinute)} - ${this.toHm(this.endHour, this.endMinute)}`
  }

  private openTimeDialog(onAccept: (hour: number, minute: number) => void) {
    const opt: TimePickerDialogOptions = {
      selected: this.pickingBaseDate,
      onAccept: (res: TimePickerResult) => {
        onAccept(res.hour, res.minute)
      }
    }
    TimePickerDialog.show(opt)
  }

  private pickStartTime() {
    this.openTimeDialog((h: number, m: number) => {
      this.startHour = h
      this.startMinute = m
      this.refreshTimeText()
    })
  }

  private pickEndTime() {
    this.openTimeDialog((h: number, m: number) => {
      this.endHour = h
      this.endMinute = m
      this.refreshTimeText()
    })
  }

  private handleSave() {
    if (!this.name.trim()) {
      return
    }
    let result: Course
    if (this.course != null) {
      result = {
        id: this.course.id,
        name: this.name.trim(),
        classroom: this.classroom.trim() || '未设置教室',
        weekday: this.weekday,
        time: this.time.trim() || '时间待定'
      }
    } else {
      result = {
        id: Date.now(),
        name: this.name.trim(),
        classroom: this.classroom.trim() || '未设置教室',
        weekday: this.weekday,
        time: this.time.trim() || '时间待定'
      }
    }
    result.startWeek = this.startWeek
    result.endWeek = this.endWeek
    result.weekMode = this.weekMode
    result.teacher = this.course?.teacher
    result.color = this.course?.color
    if (this.onSave) {
      this.onSave(result)
    }
  }

  build() {
    Column() {
      // 顶部返回+标题
      Row() {
        Text('〈 返回')
          .fontSize(16)
          .fontColor('#5475A8')
          .onClick(() => {
            if (this.onCancel) {
              this.onCancel()
            }
          })
        Blank()
        Text(this.course != null ? '编辑课程' : '新增课程')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#24262B')
      }
      .padding({ top: 16, left: 20, right: 20, bottom: 8 })

      Scroll() {
        Column() {
          // 表单卡片
          Column() {
            // 课程名称
            Text('课程名称')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 4, bottom: 4 })
            TextInput({ text: this.name, placeholder: '例如：高等数学' })
              .onChange((v: string) => this.name = v)
              .width('100%')
              .height(44)
              .border({ width: 0.5, color: '#E5E7EB' })
              .borderRadius(10)
              .padding({ left: 10, right: 10 })

            // 教室
            Text('上课教室（可选）')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 14, bottom: 4 })
            TextInput({ text: this.classroom, placeholder: '例如：教一-301' })
              .onChange((v: string) => this.classroom = v)
              .width('100%')
              .height(44)
              .border({ width: 0.5, color: '#E5E7EB' })
              .borderRadius(10)
              .padding({ left: 10, right: 10 })

            // 上课星期
            Text('上课星期')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 14, bottom: 6 })
            Row() {
              ForEach(['一', '二', '三', '四', '五', '六', '日'], (label: string, index: number) => {
                Column() {
                  Text(label)
                    .fontSize(12)
                    .fontColor(this.weekday === index + 1 ? '#FFFFFF' : '#4B5563')
                }
                .width(28)
                .height(28)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .margin({ right: 6 })
                .backgroundColor(this.weekday === index + 1 ? '#5475A8' : '#E5E7EB')
                .borderRadius(14)
                .onClick(() => {
                  this.weekday = index + 1
                })
              })
            }

            // 上课时间（选择器）
            Text('学期周次与单双周').fontSize(13).fontColor('#858992').margin({ top: 14, bottom: 8 })
            Row({ space: 12 }) {
              TextInput({ text: this.startWeek.toString(), placeholder: '起始周' }).type(InputType.Number).layoutWeight(1)
                .onChange((v: string) => { this.startWeek = Number(v) })
              Text('至').fontSize(12)
              TextInput({ text: this.endWeek.toString(), placeholder: '结束周' }).type(InputType.Number).layoutWeight(1)
                .onChange((v: string) => { this.endWeek = Number(v) })
            }
            Row({ space: 8 }) {
              Button('每周').fontSize(12).backgroundColor(this.weekMode === 'all' ? '#292D34' : '#EEF1F5').fontColor(this.weekMode === 'all' ? '#FFFFFF' : '#858992').onClick(() => { this.weekMode = 'all' })
              Button('单周').fontSize(12).backgroundColor(this.weekMode === 'odd' ? '#292D34' : '#EEF1F5').fontColor(this.weekMode === 'odd' ? '#FFFFFF' : '#858992').onClick(() => { this.weekMode = 'odd' })
              Button('双周').fontSize(12).backgroundColor(this.weekMode === 'even' ? '#292D34' : '#EEF1F5').fontColor(this.weekMode === 'even' ? '#FFFFFF' : '#858992').onClick(() => { this.weekMode = 'even' })
            }.margin({ top: 10 })
            Text('上课时间')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 14, bottom: 4 })
            Row() {
              Column() {
                Text(this.time && this.time.trim().length > 0 ? this.time : '未设置')
                  .fontSize(14)
                  .fontColor('#24262B')
              }
              .layoutWeight(1)
              Row() {
                Button('开始')
                  .height(36)
                  .backgroundColor('#EEF2F8')
                  .fontColor('#5475A8')
                  .borderRadius(10)
                  .onClick(() => this.pickStartTime())
                Button('结束')
                  .height(36)
                  .margin({ left: 8 })
                  .backgroundColor('#EEF2F8')
                  .fontColor('#5475A8')
                  .borderRadius(10)
                  .onClick(() => this.pickEndTime())
              }
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .border({ width: 0.5, color: '#E5E7EB' })
            .borderRadius(10)
          }
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .shadow({ radius: 10, color: '#0000000F', offsetX: 0, offsetY: 4 })

          // 保存
          Button(this.course ? '保存课程' : '添加课程')
            .width('100%')
            .height(46)
            .margin({ top: 24 })
            .backgroundColor('#5475A8')
            .fontColor('#FFFFFF')
            .borderRadius(23)
            .onClick(() => this.handleSave())

          // 删除按钮（仅编辑已有课程时显示）
          if (this.course != null) {
            Button('删除此课程')
              .width('100%')
              .height(46)
              .margin({ top: 12, bottom: 24 })
              .backgroundColor('#F97373')
              .fontColor('#FFFFFF')
              .borderRadius(23)
              .onClick(() => {
                if (this.course != null && this.onDelete) {
                  this.onDelete(this.course)
                }
              })
          }
        }
        .padding({ left: 20, right: 20, bottom: 16 })
      }
    }
    .height('100%')
    .width('100%')
  }
}

