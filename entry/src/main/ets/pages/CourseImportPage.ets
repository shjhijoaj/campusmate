import { Course } from '../model/Types'
import { courseError, conflictWith } from '../services/CampusRules'

/**
 * 课程导入页：支持从粘贴的 JSON / CSV（表格）一键导入，无需逐条输入。
 * 学校导出的课表复制到 Excel 再复制，或直接粘贴 CSV/JSON 即可。
 */
@Component
export struct CourseImportPage {
  onConfirm?: (courses: Course[]) => void
  onCancel?: () => void

  @State private pasteText: string = ''
  @State private parsedCourses: Course[] = []
  @State private parseError: string = ''

  private parseInput(): void {
    this.parseError = ''
    const raw = this.pasteText.trim()
    if (raw.length === 0) {
      this.parsedCourses = []
      return
    }
    if (raw.startsWith('[')) {
      const jsonResult = this.tryParseJson(raw)
      this.parsedCourses = jsonResult
      return
    }
    const csvResult = this.tryParseCsv(raw)
    this.parsedCourses = csvResult
    if (csvResult.length === 0 && !this.parseError) {
      this.parseError = '未能识别为 CSV/表格，请确保每行：课程名,教室,星期,时间'
    }
  }

  private tryParseJson(raw: string): Course[] {
    try {
      const arr = JSON.parse(raw) as Record<string, Object>[]
      if (!Array.isArray(arr) || arr.length > 500) {
        this.parseError = 'JSON须为不超过500条的课程数组'
        return []
      }
      const list: Course[] = []
      for (let i = 0; i < arr.length; i++) {
        const row = arr[i]
        const name = this.getStr(row, 'name', 'courseName', '课程名', '课程名称')
        if (!name) {
          this.parseError = `第${i + 1}条：缺少课程名称`
          return []
        }
        const classroom = this.getStr(row, 'classroom', 'room', '教室', '地点') ?? ''
        const weekday = this.getWeekday(row)
        const time = this.getStr(row, 'time', 'section', '时间', '节次') ?? ''
        const course: Course = {
          id: Date.now() + i,
          name: name,
          classroom: classroom,
          weekday: weekday,
          time: time,
          startWeek: Number(row['startWeek'] ?? 1),
          endWeek: Number(row['endWeek'] ?? 20),
          weekMode: (this.getStr(row, 'weekMode') || 'all') as 'all' | 'odd' | 'even',
          teacher: this.getStr(row, 'teacher'),
          color: this.getStr(row, 'color') || '#E5ECFA'
        }
        const error = courseError(course) || conflictWith(course, list)
        if (error) {
          this.parseError = `第${i + 1}条：${error}`
          return []
        }
        list.push(course)
      }
      return list
    } catch (e) {
      this.parseError = 'JSON 格式错误，请检查括号与逗号'
      return []
    }
  }

  private getStr(row: Record<string, Object>, ...keys: string[]): string {
    for (let k = 0; k < keys.length; k++) {
      const v = row[keys[k]]
      if (v !== undefined && v !== null && typeof v === 'string') {
        return (v as string).trim()
      }
      if (typeof v === 'number') {
        return String(v)
      }
    }
    return ''
  }

  private getWeekday(row: Record<string, Object>): number {
    const keys = ['weekday', 'day', 'dayOfWeek', '星期', '周']
    for (let ki = 0; ki < keys.length; ki++) {
      const v = row[keys[ki]]
      if (v === undefined || v === null) {
        continue
      }
      if (typeof v === 'number' && v >= 1 && v <= 7) {
        return v
      }
      if (typeof v === 'string') {
        const s = (v as string).trim()
        const map: Record<string, number> = {
          '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7,
          '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7,
          '周一': 1, '周二': 2, '周三': 3, '周四': 4, '周五': 5, '周六': 6, '周日': 7,
          '星期一': 1, '星期二': 2, '星期三': 3, '星期四': 4, '星期五': 5, '星期六': 6, '星期日': 7
        }
        if (map[s] !== undefined) {
          return map[s]
        }
        const num = Number.parseInt(s)
        if (!Number.isNaN(num) && num >= 1 && num <= 7) {
          return num
        }
      }
    }
    return 0
  }

  private tryParseCsv(raw: string): Course[] {
    const lines = raw.split(/\r?\n/)
    const list: Course[] = []
    let startIndex = 0
    const firstLine = lines[0].trim()
    if (['课程名', '课程名称', 'name'].includes(firstLine.split(/[\t,]/)[0].trim())) {
      startIndex = 1
    }
    for (let i = startIndex; i < lines.length; i++) {
      const line = lines[i].trim()
      if (line.length === 0) {
        continue
      }
      const parts = line.split(/[\t,]/)
      if (parts.length < 4 || line.includes('"')) {
        this.parseError = `第${i + 1}行：需要课程名,教室,星期,时间；含引号的CSV请转JSON`
        return []
      }
      const name = parts[0].trim()
      if (!name) {
        continue
      }
      const classroom = parts.length >= 2 ? parts[1].trim() : ''
      const weekdayRaw = parts.length >= 4 ? parts[2].trim() : '1'
      const timeRaw = parts.length >= 4 ? parts[3].trim() : (parts.length >= 3 ? parts[2].trim() : '')
      let weekday = 0
      const wMap: Record<string, number> = {
        '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6, '日': 7,
        '周一': 1, '周二': 2, '周三': 3, '周四': 4, '周五': 5, '周六': 6, '周日': 7
      }
      if (wMap[weekdayRaw] !== undefined) {
        weekday = wMap[weekdayRaw]
      } else {
        const num = Number.parseInt(weekdayRaw)
        if (!Number.isNaN(num) && num >= 1 && num <= 7) {
          weekday = num
        }
      }
      let time = timeRaw
      if (!time && parts.length > 2) {
        const p2 = parts[1].trim()
        if (/^\d{1,2}:\d{2}/.test(p2) || /^\d{1,2}-\d{1,2}/.test(p2)) {
          time = p2
        }
      }
      if (!time) {
        time = '时间待定'
      }
      if (!/^\d{1,2}:\d{2}/.test(time) && time !== '时间待定') {
        time = time.replace(/-/g, ' - ')
      }
      const course: Course = {
        id: Date.now() + i,
        name: name,
        classroom: classroom,
        weekday: weekday,
        time: time,
        startWeek: parts[4] ? Number(parts[4]) : 1,
        endWeek: parts[5] ? Number(parts[5]) : 20,
        weekMode: (parts[6]?.trim() || 'all') as 'all' | 'odd' | 'even'
      }
      const error = courseError(course) || conflictWith(course, list)
      if (error) {
        this.parseError = `第${i + 1}行：${error}`
        return []
      }
      list.push(course)
    }
    return list
  }

  build() {
    Column() {
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
        Text('导入课程')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#24262B')
      }
      .width('100%')
      .padding({ top: 16, left: 20, right: 20, bottom: 12 })

      Text('从学校导出的课表可复制到此处，支持 JSON 或 CSV（表格）')
        .fontSize(12)
        .fontColor('#858992')
        .margin({ left: 20, right: 20, bottom: 8 })

      TextArea({ text: this.pasteText, placeholder: '示例 CSV：\n课程名,教室,星期,时间\n高等数学,教一-301,1,08:00-09:35\n\n或 JSON：[{"name":"高等数学","classroom":"教一-301","weekday":1,"time":"08:00-09:35"}]' })
        .width('100%')
        .height(160)
        .fontSize(13)
        .placeholderColor('#989DA6')
        .onChange((v: string) => {
          this.pasteText = v
          this.parseInput()
        })
        .margin({ left: 20, right: 20 })
        .border({ width: 0.5, color: '#E5E7EB' })
        .borderRadius(12)

      Button('解析预览')
        .margin({ top: 12 })
        .backgroundColor('#EEF2F8')
        .fontColor('#5475A8')
        .onClick(() => this.parseInput())

      if (this.parseError.length > 0) {
        Text(this.parseError)
          .fontSize(12)
          .fontColor('#DC2626')
          .margin({ top: 8 })
      }

      if (this.parsedCourses.length > 0) {
        Text(`已识别 ${this.parsedCourses.length} 门课程，确认后将追加到当前课表`)
          .fontSize(13)
          .fontColor('#059669')
          .margin({ top: 12 })
        Button('确认导入')
          .margin({ top: 12 })
          .width('80%')
          .height(44)
          .backgroundColor('#5475A8')
          .fontColor('#FFFFFF')
          .borderRadius(22)
          .onClick(() => {
            if (this.onConfirm) {
              this.onConfirm(this.parsedCourses)
            }
          })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7F9')
  }
}
