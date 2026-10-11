import { Task } from '../model/Types'
import { Dark } from '../common/Theme'

@Component
export struct TodoPage {
  @Prop tasks: Task[] = []
  @Prop showCompleted: boolean = true
  @Prop isDark: boolean = false
  onAdd?: () => void
  onEdit?: (task: Task) => void
  onTaskToggle?: (task: Task, newDone: boolean) => void

  build() {
    Scroll() {
      Column() {
        // 顶部标题 + 新增按钮
        Row() {
          Text('待办列表')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isDark ? Dark.textPrimary : '#24262B')
          Blank()
          Button('新增')
            .height(34)
            .margin({ right: 4 })
            .backgroundColor(this.isDark ? '#5475A8' : '#5475A8')
            .fontColor('#FFFFFF')
            .borderRadius(18)
            .onClick(() => {
              if (this.onAdd) {
                this.onAdd()
              }
            })
        }
        .margin({ top: 16, left: 20, right: 20, bottom: 8 })

        Column() {
          ForEach(this.getSortedTasks(), (task: Task) => {
            Row() {
              Column() {
                Text(task.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.isDark ? Dark.textPrimary : '#24262B')
                if (task.courseName) {
                  Text(task.courseName)
                    .fontSize(12)
                    .fontColor(this.isDark ? Dark.textSecondary : '#858992')
                }
                Text(`${task.type} ｜ 截止：${task.deadline}`)
                  .fontSize(12)
                  .fontColor(this.isDark ? Dark.textSecondary : '#858992')
                if (task.remindEnabled && task.remindAt) {
                  Text(`提醒：${task.remindAt}${(task.remindAdvanceMinutes ?? 0) > 0 ? `（提前${task.remindAdvanceMinutes}分）` : ''}`)
                    .fontSize(11)
                    .fontColor(this.isDark ? '#A9BEDA' : '#5475A8')
                    .margin({ top: 4 })
                }
              }
              Blank()
              // 右侧小区域：上面是勾选，下面是“编辑”
              Column() {
                Text(task.done ? '✓' : '○')
                  .fontSize(20)
                  .fontColor(task.done ? '#759271' : (this.isDark ? Dark.borderLight : '#D1D5DB'))
                  .onClick(() => {
                    let index = this.tasks.findIndex((t: Task) => t.id === task.id)
                    if (index >= 0) {
                      const newDone = !this.tasks[index].done
                      if (this.onTaskToggle) {
                        this.onTaskToggle(task, newDone)
                      }
                    }
                  })
                Text('编辑')
                  .fontSize(10)
                  .fontColor(this.isDark ? '#A9BEDA' : '#5475A8')
                  .margin({ top: 4 })
                  .onClick(() => {
                    if (this.onEdit) {
                      this.onEdit(task)
                    }
                  })
              }
            }
            .padding(12)
            .margin({ bottom: 8 })
            .backgroundColor(this.isDark ? Dark.bgCard : '#FFFFFF')
            .borderRadius(12)
            .shadow({ radius: 6, color: this.isDark ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 2 })
          })
        }
        .padding({ left: 20, right: 20, bottom: 20 })
      }
    }
  }

  private getSortedTasks(): Task[] {
    let list: Task[] = [...this.tasks]
    if (!this.showCompleted) {
      list = list.filter((t: Task) => !t.done)
    }
    list.sort((a: Task, b: Task) => {
      // 未完成优先
      if (a.done !== b.done) {
        return a.done ? 1 : -1
      }
      // 有提醒的优先，且按提醒时间早的优先（字符串无法可靠比较，简单按字典序：YYYY-MM-DD HH:mm）
      const ar = (a.remindEnabled && a.remindAt) ? a.remindAt : ''
      const br = (b.remindEnabled && b.remindAt) ? b.remindAt : ''
      if (ar && br && ar !== br) {
        return ar < br ? -1 : 1
      }
      if (ar !== br) {
        return ar ? -1 : 1
      }
      return b.id - a.id
    })
    return list
  }
}

