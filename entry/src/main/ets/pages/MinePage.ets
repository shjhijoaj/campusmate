import {
  Course,
  Task,
  UserSettings,
  SettingsPatch,
  ExportData,
  DialogButton,
  DialogResult
} from '../model/Types'
import { Dark } from '../common/Theme'
import { promptAction } from '@kit.ArkUI'
import { CampusSnapshot, validateSnapshot } from '../services/CampusRules'

@Component
export struct MinePage {
  @Link settings: UserSettings
  @Prop courses: Course[] = []
  @Prop tasks: Task[] = []
  onSave?: (s: UserSettings) => Promise<boolean>
  onImportData?: (jsonStr: string) => Promise<boolean>
  onClearData?: () => Promise<boolean>

  @State private nicknameInput: string = ''
  @State private semesterInput: string = ''
  @State private showImportData: boolean = false
  @State private importDataText: string = ''
  @State private showExportData: boolean = false
  @State private exportJsonText: string = ''
  private appVersion: string = '2.1.0'

  aboutToAppear(): void {
    this.nicknameInput = this.settings.nickname
    this.semesterInput = this.settings.semesterStart
  }

  private mergeSettings(patch: SettingsPatch): UserSettings {
    const s = this.settings
    const next: UserSettings = {
      nickname: patch.nickname !== undefined ? patch.nickname : s.nickname,
      semesterStart: patch.semesterStart !== undefined ? patch.semesterStart : s.semesterStart,
      theme: patch.theme !== undefined ? patch.theme : (s.theme ?? 'light'),
      weekStartsOnMonday: patch.weekStartsOnMonday !== undefined ? patch.weekStartsOnMonday : (s.weekStartsOnMonday ?? true),
      defaultRemindAdvanceMinutes: patch.defaultRemindAdvanceMinutes !== undefined ? patch.defaultRemindAdvanceMinutes : (s.defaultRemindAdvanceMinutes ?? 10),
      defaultTodoType: patch.defaultTodoType !== undefined ? patch.defaultTodoType : (s.defaultTodoType ?? '作业'),
      taskListShowCompleted: patch.taskListShowCompleted !== undefined ? patch.taskListShowCompleted : (s.taskListShowCompleted ?? true),
      hapticOn: patch.hapticOn !== undefined ? patch.hapticOn : (s.hapticOn ?? true)
    }
    return next
  }

  private async applySettings(next: UserSettings): Promise<boolean> {
    return this.onSave ? await this.onSave(next) : false
  }

  private async savePersonal(): Promise<void> {
    if (this.semesterInput && !/^\d{4}-\d{2}-\d{2}$/.test(this.semesterInput)) {
      promptAction.showToast({ message: '开学日期应为 YYYY-MM-DD', duration: 2000 })
      return
    }
    const patch: SettingsPatch = { nickname: this.nicknameInput.trim(), semesterStart: this.semesterInput.trim() }
    const next = this.mergeSettings(patch)
    const snapshot: CampusSnapshot = { version: 2, revision: 0, savedAt: Date.now(), courses: this.courses, tasks: this.tasks, settings: next }
    const error = validateSnapshot(snapshot)
    if (error) {
      promptAction.showToast({ message: error, duration: 2500 })
      return
    }
    if (await this.applySettings(next)) promptAction.showToast({ message: '已保存', duration: 1500 })
  }

  private exportData(): void {
    const data: ExportData = {
      version: 2,
      settings: this.settings,
      courses: this.courses,
      tasks: this.tasks,
      exportTime: new Date().toISOString()
    }
    this.exportJsonText = JSON.stringify(data, null, 2)
    this.showExportData = true
  }

  private async doImportData(): Promise<void> {
    const s = this.importDataText.trim()
    if (!s) {
      promptAction.showToast({ message: '请先粘贴导出的 JSON 数据', duration: 2000 })
      return
    }
    try {
      const obj = JSON.parse(s) as Record<string, Object>
      if (!obj || !Array.isArray(obj['courses']) || !Array.isArray(obj['tasks'])) {
        promptAction.showToast({ message: '备份缺少courses/tasks；原数据未变更', duration: 2500 })
        return
      }
      const courses = (obj['courses'] as Course[]) ?? []
      const tasks = (obj['tasks'] as Task[]) ?? []
      const snapshot: CampusSnapshot = { version: 2, revision: 0, savedAt: Date.now(), courses: courses, tasks: tasks, settings: this.settings }
      if (obj['version'] !== undefined) snapshot.version = obj['version'] as number
      if (obj['settings']) snapshot.settings = obj['settings'] as UserSettings
      const validationError = validateSnapshot(snapshot)
      if (validationError) {
        promptAction.showToast({ message: validationError + '；原数据未变更', duration: 2500 })
        return
      }
      if (!Array.isArray(courses) || !Array.isArray(tasks)) {
        promptAction.showToast({ message: '数据格式不正确', duration: 2000 })
        return
      }
      if (this.onImportData) {
        if (!(await this.onImportData(s))) return
      }
      this.showImportData = false
      this.importDataText = ''
      promptAction.showToast({ message: '导入成功', duration: 2000 })
    } catch (e) {
      promptAction.showToast({ message: 'JSON 格式错误，请检查', duration: 2000 })
    }
  }

  private confirmClearData(): void {
    const btnCancel: DialogButton = { text: '取消', color: '#858992' }
    const btnConfirm: DialogButton = { text: '清空', color: '#DC2626' }
    const buttons: DialogButton[] = [btnCancel, btnConfirm]
    promptAction.showDialog({
      title: '清空所有数据',
      message: '将清空全部课程与待办，且无法恢复。确定继续？',
      buttons: buttons
    }).then(async (res: DialogResult) => {
      if (res.index === 1 && this.onClearData) {
        if (await this.onClearData()) promptAction.showToast({ message: '已清空', duration: 2000 })
      }
    })
  }

  build() {
    Column() {
      Text('偏好设置')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.settings.theme === 'dark' ? Dark.textPrimary : '#24262B')
        .margin({ top: 16, bottom: 20 })

      Scroll() {
        Column() {
          // 个性化
          Column() {
            Text('个性化')
              .fontSize(14)
              .fontColor((this.settings.theme === 'dark' ? Dark.textSecondary : '#858992'))
              .margin({ bottom: 12 })
            Row() {
              Text('昵称')
                .fontSize(15)
                .fontColor('#374151')
                .width(72)
              TextInput({ text: this.nicknameInput, placeholder: '首页显示 Hi，昵称' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .onChange((val: string) => { this.nicknameInput = val })
            }
            .width('100%')
            .margin({ bottom: 12 })
            Row() {
              Text('开学日')
                .fontSize(15)
                .fontColor('#374151')
                .width(72)
              TextInput({ text: this.semesterInput, placeholder: '如 2025-09-01，用于第几周' })
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .onChange((val: string) => { this.semesterInput = val })
            }
            .width('100%')
            Button('保存')
              .width('100%')
              .height(40)
              .fontSize(15)
              .backgroundColor('#5475A8')
              .fontColor('#FFFFFF')
              .borderRadius(12)
              .margin({ top: 8 })
              .onClick(() => this.savePersonal())
          }
          .padding(20)
          .width('100%')
          .backgroundColor((this.settings.theme === 'dark' ? Dark.bgCard : '#FFFFFF'))
          .borderRadius(16)
          .shadow({ radius: 10, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 4 })
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 显示与列表
          Column() {
            Text('显示与列表')
              .fontSize(14)
              .fontColor((this.settings.theme === 'dark' ? Dark.textSecondary : '#858992'))
              .margin({ bottom: 12 })
            Row() {
              Text('深色模式')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.settings.theme === 'dark' })
                .onChange((v: boolean) => {
                  const patch: SettingsPatch = { theme: v ? 'dark' : 'light' }
                  this.applySettings(this.mergeSettings(patch))
                })
            }
            .width('100%')
            .margin({ bottom: 10 })
            Row() {
              Text('周一为一周开始')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.settings.weekStartsOnMonday !== false })
                .onChange((v: boolean) => {
                  const patch: SettingsPatch = { weekStartsOnMonday: v }
                  this.applySettings(this.mergeSettings(patch))
                })
            }
            .width('100%')
            .margin({ bottom: 10 })
            Row() {
              Text('待办列表显示已完成')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.settings.taskListShowCompleted !== false })
                .onChange((v: boolean) => {
                  const patch: SettingsPatch = { taskListShowCompleted: v }
                  this.applySettings(this.mergeSettings(patch))
                })
            }
            .width('100%')
          }
          .padding(20)
          .width('100%')
          .backgroundColor((this.settings.theme === 'dark' ? Dark.bgCard : '#FFFFFF'))
          .borderRadius(16)
          .shadow({ radius: 10, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 4 })
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 提醒默认
          Column() {
            Text('提醒默认')
              .fontSize(14)
              .fontColor((this.settings.theme === 'dark' ? Dark.textSecondary : '#858992'))
              .margin({ bottom: 12 })
            Text('新建待办默认提前提醒（分钟）')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ bottom: 8 })
            Row() {
              ForEach([0, 5, 10, 15, 30, 60], (m: number) => {
                Text(m === 0 ? '准点' : `${m}`)
                  .fontSize(12)
                  .fontColor((this.settings.defaultRemindAdvanceMinutes ?? 10) === m ? '#FFFFFF' : '#4B5563')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor((this.settings.defaultRemindAdvanceMinutes ?? 10) === m ? '#5475A8' : '#E5E7EB')
                  .borderRadius(16)
                  .margin({ right: 6 })
                  .onClick(() => {
                    const patch: SettingsPatch = { defaultRemindAdvanceMinutes: m }
                    this.applySettings(this.mergeSettings(patch))
                  })
              })
            }
            .width('100%')
            .margin({ bottom: 12 })
            Text('新建待办默认类型')
              .fontSize(13)
              .fontColor('#858992')
              .margin({ bottom: 8 })
            Row() {
              ForEach(['作业', '考试', '项目', '其他'], (t: string) => {
                Text(t)
                  .fontSize(12)
                  .fontColor((this.settings.defaultTodoType ?? '作业') === t ? '#FFFFFF' : '#4B5563')
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor((this.settings.defaultTodoType ?? '作业') === t ? '#5475A8' : '#E5E7EB')
                  .borderRadius(16)
                  .margin({ right: 6 })
                  .onClick(() => {
                    const patch: SettingsPatch = { defaultTodoType: t }
                    this.applySettings(this.mergeSettings(patch))
                  })
              })
            }
            .width('100%')
          }
          .padding(20)
          .width('100%')
          .backgroundColor((this.settings.theme === 'dark' ? Dark.bgCard : '#FFFFFF'))
          .borderRadius(16)
          .shadow({ radius: 10, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 4 })
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 数据
          Column() {
            Text('数据')
              .fontSize(14)
              .fontColor((this.settings.theme === 'dark' ? Dark.textSecondary : '#858992'))
              .margin({ bottom: 12 })
            Row() {
              Text('导出数据')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Text('查看并复制 JSON 备份')
                .fontSize(12)
                .fontColor('#858992')
                .margin({ right: 8 })
              Button('导出')
                .height(32)
                .fontSize(13)
                .backgroundColor('#EEF2F8')
                .fontColor('#5475A8')
                .borderRadius(16)
                .onClick(() => this.exportData())
            }
            .width('100%')
            .margin({ bottom: 12 })
            Row() {
              Text('导入数据')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Button('从粘贴导入')
                .height(32)
                .fontSize(13)
                .backgroundColor('#EEF2F8')
                .fontColor('#5475A8')
                .borderRadius(16)
                .onClick(() => { this.showImportData = true })
            }
            .width('100%')
            .margin({ bottom: 12 })
            Row() {
              Text('清空所有数据')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Button('清空')
                .height(32)
                .fontSize(13)
                .backgroundColor('#FEE2E2')
                .fontColor('#DC2626')
                .borderRadius(16)
                .onClick(() => this.confirmClearData())
            }
            .width('100%')
          }
          .padding(20)
          .width('100%')
          .backgroundColor((this.settings.theme === 'dark' ? Dark.bgCard : '#FFFFFF'))
          .borderRadius(16)
          .shadow({ radius: 10, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 4 })
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 其他
          Column() {
            Text('其他')
              .fontSize(14)
              .fontColor((this.settings.theme === 'dark' ? Dark.textSecondary : '#858992'))
              .margin({ bottom: 12 })
            Row() {
              Text('震动反馈')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.settings.hapticOn !== false })
                .onChange((v: boolean) => {
                  const patch: SettingsPatch = { hapticOn: v }
                  this.applySettings(this.mergeSettings(patch))
                })
            }
            .width('100%')
          }
          .padding(20)
          .width('100%')
          .backgroundColor((this.settings.theme === 'dark' ? Dark.bgCard : '#FFFFFF'))
          .borderRadius(16)
          .shadow({ radius: 10, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 4 })
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 关于与支持
          Column() {
            Text('关于与支持')
              .fontSize(14)
              .fontColor((this.settings.theme === 'dark' ? Dark.textSecondary : '#858992'))
              .margin({ bottom: 12 })
            Row() {
              Text('应用名称')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Text('CampusMate')
                .fontSize(15)
                .fontColor('#24262B')
            }
            .width('100%')
            .margin({ bottom: 10 })
            Row() {
              Text('版本')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Text(this.appVersion)
                .fontSize(15)
                .fontColor('#858992')
            }
            .width('100%')
            .margin({ bottom: 10 })
            Row() {
              Text('隐私说明')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Text('数据仅存于本机')
                .fontSize(12)
                .fontColor('#858992')
            }
            .width('100%')
            .margin({ bottom: 10 })
            Row() {
              Text('用户协议')
                .fontSize(15)
                .fontColor('#374151')
              Blank()
              Text('使用即表示同意')
                .fontSize(12)
                .fontColor('#858992')
            }
            .width('100%')
          }
          .padding(20)
          .width('100%')
          .backgroundColor((this.settings.theme === 'dark' ? Dark.bgCard : '#FFFFFF'))
          .borderRadius(16)
          .shadow({ radius: 10, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#0000000F', offsetX: 0, offsetY: 4 })
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          Blank().height(24)
        }
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 导入数据浮层
      if (this.showImportData) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#80000000')
            .onClick(() => {
              this.showImportData = false
              this.importDataText = ''
            })
          Column() {
            Text('粘贴导出的 JSON 数据')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.settings.theme === 'dark' ? Dark.textPrimary : '#24262B')
              .margin({ bottom: 12 })
            TextArea({ text: this.importDataText, placeholder: '将导出的 JSON 粘贴到此处' })
              .width('100%')
              .height(200)
              .fontSize(13)
              .onChange((v: string) => { this.importDataText = v })
              .margin({ bottom: 12 })
            Row() {
              Button('取消')
                .layoutWeight(1)
                .height(40)
                .fontSize(15)
                .backgroundColor(this.settings.theme === 'dark' ? Dark.borderLight : '#E5E7EB')
                .fontColor(this.settings.theme === 'dark' ? Dark.textSecondary : '#374151')
                .borderRadius(12)
                .onClick(() => {
                  this.showImportData = false
                  this.importDataText = ''
                })
              Button('确认导入')
                .layoutWeight(1)
                .height(40)
                .margin({ left: 12 })
                .fontSize(15)
                .backgroundColor(this.settings.theme === 'dark' ? '#5475A8' : '#5475A8')
                .fontColor('#FFFFFF')
                .borderRadius(12)
                .onClick(() => this.doImportData())
            }
            .width('100%')
          }
          .padding(24)
          .width('90%')
          .backgroundColor(this.settings.theme === 'dark' ? Dark.surfaceElevated : '#FFFFFF')
          .borderRadius(20)
          .shadow({ radius: 20, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#00000030', offsetX: 0, offsetY: 4 })
        }
        .width('100%')
        .height('100%')
      }

      // 导出数据浮层（展示 JSON，用户可长按复制）
      if (this.showExportData) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#80000000')
            .onClick(() => { this.showExportData = false })
          Column() {
            Text('导出数据（可长按选中复制）')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.settings.theme === 'dark' ? Dark.textPrimary : '#24262B')
              .margin({ bottom: 12 })
            Scroll() {
              Text(this.exportJsonText)
                .fontSize(12)
                .fontColor(this.settings.theme === 'dark' ? Dark.textSecondary : '#374151')
                .width('100%')
            }
            .height(280)
            .width('100%')
            .scrollBar(BarState.Auto)
            .margin({ bottom: 12 })
            Button('关闭')
              .width('100%')
              .height(40)
              .fontSize(15)
              .backgroundColor(this.settings.theme === 'dark' ? '#5475A8' : '#5475A8')
              .fontColor('#FFFFFF')
              .borderRadius(12)
              .onClick(() => { this.showExportData = false })
          }
          .padding(24)
          .width('90%')
          .backgroundColor(this.settings.theme === 'dark' ? Dark.surfaceElevated : '#FFFFFF')
          .borderRadius(20)
          .shadow({ radius: 20, color: (this.settings.theme === 'dark') ? Dark.cardShadow : '#00000030', offsetX: 0, offsetY: 4 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.settings.theme === 'dark' ? Dark.bgContent : '#F6F7F9')
  }
}
