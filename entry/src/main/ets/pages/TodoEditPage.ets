import { Task } from '../model/Types'

interface RepeatOption {
  k: 'none' | 'daily' | 'weekly'
  t: string
}

@Component
export struct TodoEditPage {
  @Prop task: Task | null = null
  @Prop defaultTodoType: string = '作业'
  @Prop defaultRemindAdvanceMinutes: number = 10
  onCancel?: () => void
  onSave?: (task: Task) => void
  onDelete?: (task: Task) => void

  @State title: string = ''
  @State courseName: string = ''
  @State type: string = '作业'
  @State deadline: string = ''
  @State remindEnabled: boolean = false
  @State remindAt: string = ''
  @State remindAdvance: number = 10
  @State remindRepeat: 'none' | 'daily' | 'weekly' = 'none'
  @State private pickingBaseDate: Date = new Date()
  private repeatOptions: RepeatOption[] = [
    { k: 'none', t: '一次' },
    { k: 'daily', t: '每天' },
    { k: 'weekly', t: '每周' }
  ]

  aboutToAppear() {
    if (this.task != null) {
      this.title = this.task.title
      this.courseName = this.task.courseName ?? ''
      this.type = this.task.type
      this.deadline = this.task.deadline
      this.remindEnabled = this.task.remindEnabled ?? false
      this.remindAt = this.task.remindAt ?? ''
      this.remindAdvance = this.task.remindAdvanceMinutes ?? 10
      this.remindRepeat = this.task.remindRepeat ?? 'none'
    } else {
      this.type = this.defaultTodoType
      this.remindAdvance = this.defaultRemindAdvanceMinutes
    }
  }

  private openDateDialog(onAccept: (d: Date) => void) {
    const opt: DatePickerDialogOptions = {
      selected: this.pickingBaseDate,
      onDateAccept: (d: Date) => {
        onAccept(d)
      }
    }
    DatePickerDialog.show(opt)
  }

  private openDateTimeDialog(onAccept: (d: Date) => void) {
    const opt: DatePickerDialogOptions = {
      selected: this.parseRemindAtToDate() ?? this.pickingBaseDate,
      showTime: true,
      useMilitaryTime: true,
      onDateAccept: (d: Date) => {
        onAccept(d)
      }
    }
    DatePickerDialog.show(opt)
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

  private parseRemindAtToDate(): Date | null {
    const s = this.remindAt.trim()
    if (s.length < 16) {
      return null
    }
    const parts = s.replace('T', ' ').split(' ')
    if (parts.length < 2) {
      return null
    }
    const ymd = parts[0].split('-')
    const hm = parts[1].split(':')
    if (ymd.length < 3 || hm.length < 2) {
      return null
    }
    const y = Number.parseInt(ymd[0])
    const m = Number.parseInt(ymd[1]) - 1
    const d = Number.parseInt(ymd[2])
    const hh = Number.parseInt(hm[0])
    const mm = Number.parseInt(hm[1])
    if ([y, m, d, hh, mm].some((n: number) => Number.isNaN(n))) {
      return null
    }
    return new Date(y, m, d, hh, mm, 0)
  }

  private toYmd(d: Date): string {
    const y = d.getFullYear()
    const m = (d.getMonth() + 1).toString().padStart(2, '0')
    const day = d.getDate().toString().padStart(2, '0')
    return `${y}-${m}-${day}`
  }

  private toHm(hour: number, minute: number): string {
    const hh = hour.toString().padStart(2, '0')
    const mm = minute.toString().padStart(2, '0')
    return `${hh}:${mm}`
  }

  private formatDateTime(d: Date): string {
    return `${this.toYmd(d)} ${this.toHm(d.getHours(), d.getMinutes())}`
  }

  private pickDeadlineDateTime() {
    this.openDateDialog((d: Date) => {
      this.pickingBaseDate = d
      this.openTimeDialog((h: number, m: number) => {
        const dt = `${this.toYmd(d)} ${this.toHm(h, m)}`
        this.deadline = dt
      })
    })
  }

  private pickRemindDateTime() {
    this.openDateTimeDialog((d: Date) => {
      this.pickingBaseDate = d
      this.remindAt = this.formatDateTime(d)
    })
  }

  private handleSave() {
    if (!this.title.trim()) {
      // 简单校验：标题必填
      return
    }
    let result: Task
    if (this.task != null) {
      // 编辑已有任务
      result = {
        id: this.task.id,
        done: this.task.done,
        title: this.title.trim(),
        courseName: this.courseName.trim() || undefined,
        type: this.type,
        deadline: this.deadline.trim() || '未设置',
        remindEnabled: this.remindEnabled,
        remindAt: this.remindEnabled ? (this.remindAt.trim() || '') : '',
        remindAdvanceMinutes: this.remindEnabled ? this.remindAdvance : 0,
        remindRepeat: this.remindEnabled ? this.remindRepeat : 'none',
        notificationIds: this.task.notificationIds
      }
    } else {
      // 新建任务
      result = {
        id: Date.now(),
        title: this.title.trim(),
        courseName: this.courseName.trim() || undefined,
        type: this.type,
        deadline: this.deadline.trim() || '未设置',
        done: false,
        remindEnabled: this.remindEnabled,
        remindAt: this.remindEnabled ? (this.remindAt.trim() || '') : '',
        remindAdvanceMinutes: this.remindEnabled ? this.remindAdvance : 0,
        remindRepeat: this.remindEnabled ? this.remindRepeat : 'none'
      }
    }
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
        Text(this.task != null ? '编辑待办' : '新增待办')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#24262B')
      }
      .padding({ top: 16, left: 20, right: 20, bottom: 8 })

      Scroll() {
        Column() {
          Column() {
            // 标题
            Text('标题')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 4, bottom: 4 })
            TextInput({ text: this.title, placeholder: '例如：提交数据结构实验报告' })
              .onChange((v: string) => this.title = v)
              .width('100%')
              .height(44)
              .border({ width: 0.5, color: '#E5E7EB' })
              .borderRadius(10)
              .padding({ left: 10, right: 10 })

            // 课程名称
            Text('关联课程（可选）')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 14, bottom: 4 })
            TextInput({ text: this.courseName, placeholder: '例如：数据结构' })
              .onChange((v: string) => this.courseName = v)
              .width('100%')
              .height(44)
              .border({ width: 0.5, color: '#E5E7EB' })
              .borderRadius(10)
              .padding({ left: 10, right: 10 })

            // 类型
            Text('类型')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 14, bottom: 6 })
            Row() {
              ForEach(['作业', '考试', '项目', '其他'], (t: string) => {
                Column() {
                  Text(t)
                    .fontSize(12)
                    .fontColor(this.type === t ? '#FFFFFF' : '#4B5563')
                }
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .margin({ right: 6 })
                .backgroundColor(this.type === t ? '#5475A8' : '#E5E7EB')
                .borderRadius(16)
                .onClick(() => this.type = t)
              })
            }

            // 截止时间
            Text('截止时间')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 14, bottom: 4 })
            Row() {
              TextInput({ text: this.deadline, placeholder: '可手输，也可点右侧「选择」' })
                .onChange((v: string) => this.deadline = v)
                .layoutWeight(1)
                .height(44)
                .border({ width: 0.5, color: '#E5E7EB' })
                .borderRadius(10)
                .padding({ left: 10, right: 10 })
              Button('选择')
                .height(44)
                .margin({ left: 10 })
                .backgroundColor('#EEF2F8')
                .fontColor('#5475A8')
                .borderRadius(10)
                .onClick(() => this.pickDeadlineDateTime())
            }
            .width('100%')

            // 提醒（上市级必备）
            Text('提醒')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ top: 14, bottom: 6 })

            Row() {
              Text('开启提醒')
                .fontSize(14)
                .fontColor('#24262B')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.remindEnabled })
                .onChange((val: boolean) => {
                  this.remindEnabled = val
                  if (!val) {
                    this.remindAt = ''
                  }
                })
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })

            if (this.remindEnabled) {
              Text('提醒时间（YYYY-MM-DD HH:mm）')
                .fontSize(12)
                .fontColor('#989DA6')
                .margin({ top: 6, bottom: 4 })
              Row() {
                TextInput({ text: this.remindAt, placeholder: '可手输，也可点右侧「选择」' })
                  .onChange((v: string) => this.remindAt = v)
                  .layoutWeight(1)
                  .height(44)
                  .border({ width: 0.5, color: '#E5E7EB' })
                  .borderRadius(10)
                  .padding({ left: 10, right: 10 })
                Button('选择')
                  .height(44)
                  .margin({ left: 10 })
                  .backgroundColor('#EEF2F8')
                  .fontColor('#5475A8')
                  .borderRadius(10)
                  .onClick(() => this.pickRemindDateTime())
              }
              .width('100%')

              Text('提前提醒')
                .fontSize(12)
                .fontColor('#989DA6')
                .margin({ top: 10, bottom: 6 })
              Row() {
                ForEach([0, 10, 30, 60], (m: number) => {
                  Column() {
                    Text(m === 0 ? '准点' : `提前${m}分`)
                      .fontSize(12)
                      .fontColor(this.remindAdvance === m ? '#FFFFFF' : '#4B5563')
                  }
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .margin({ right: 6 })
                  .backgroundColor(this.remindAdvance === m ? '#5475A8' : '#E5E7EB')
                  .borderRadius(16)
                  .onClick(() => this.remindAdvance = m)
                })
              }

              Text('重复')
                .fontSize(12)
                .fontColor('#989DA6')
                .margin({ top: 10, bottom: 6 })
              Row() {
                ForEach(this.repeatOptions, (it: RepeatOption) => {
                  Column() {
                    Text(it.t)
                      .fontSize(12)
                      .fontColor(this.remindRepeat === it.k ? '#FFFFFF' : '#4B5563')
                  }
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .margin({ right: 6 })
                  .backgroundColor(this.remindRepeat === it.k ? '#5475A8' : '#E5E7EB')
                  .borderRadius(16)
                  .onClick(() => this.remindRepeat = it.k)
                })
              }
            }
          }
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .shadow({ radius: 10, color: '#0000000F', offsetX: 0, offsetY: 4 })

          // 保存按钮
          Button(this.task ? '保存修改' : '添加待办')
            .width('100%')
            .height(46)
            .margin({ top: 24 })
            .backgroundColor('#5475A8')
            .fontColor('#FFFFFF')
            .borderRadius(23)
            .onClick(() => this.handleSave())

          // 删除按钮（仅编辑已有任务时显示）
          if (this.task != null) {
            Button('删除此待办')
              .width('100%')
              .height(46)
              .margin({ top: 12, bottom: 24 })
              .backgroundColor('#F97373')
              .fontColor('#FFFFFF')
              .borderRadius(23)
              .onClick(() => {
                if (this.task != null && this.onDelete) {
                  this.onDelete(this.task)
                }
              })
          }
        }
        .padding({ left: 20, right: 20, bottom: 24 })
      }
    }
    .height('100%')
    .width('100%')
  }
}

