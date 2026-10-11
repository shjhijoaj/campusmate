export const VERSION = 2;
export const clone = value => JSON.parse(JSON.stringify(value));
export const uid = () => Date.now() * 1000 + Math.floor(Math.random() * 1000);
export const dateKey = date => `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
export function localDate(key) { const d = new Date(`${key}T12:00:00`); if (!/^\d{4}-\d{2}-\d{2}$/.test(key) || Number.isNaN(+d) || dateKey(d)!==key) throw new Error('日期格式应为 YYYY-MM-DD'); return d; }
export function weekNumber(key,start) { if(!start)return 0; const day=localDate(key),first=localDate(start);return Math.max(0,Math.floor((Date.UTC(day.getFullYear(),day.getMonth(),day.getDate())-Date.UTC(first.getFullYear(),first.getMonth(),first.getDate()))/604800000)+1); }
export const weekLabel = (key,start) => !start?'设置学期起点':weekNumber(key,start)===0?'学期尚未开始':`第 ${weekNumber(key,start)} 周`;
export function newId(items=[]){let id=uid();const used=new Set(items.map(item=>item.id));while(used.has(id))id++;if(!Number.isSafeInteger(id))throw new Error('无法生成新的项目ID');return id;}
export function activeInWeek(c,week) { return week >= (c.startWeek??1) && week <=(c.endWeek??20) && (c.weekMode==='odd'?week%2===1:c.weekMode==='even'?week%2===0:true); }
export function minutes(value) { if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(value.trim())) throw new Error('时间必须为 HH:mm'); const [h,m]=value.trim().split(':').map(Number); return h*60+m; }
export function courseRange(c) { if (typeof c.time!=='string') throw new Error('时间不能为空'); const range=c.time.split('-'); if(range.length!==2)throw new Error('时间格式应为08:00-09:35'); const [start,end]=range.map(minutes); if(start>=end)throw new Error('结束时间须晚于开始时间'); return [start,end]; }
export function validateCourse(c) {
  if (!c || typeof c!=='object')throw new Error('课程必须为对象');
  if(!Number.isSafeInteger(c.id)||c.id<1)throw new Error('课程ID必须为正整数');
  if(typeof c.name!=='string'||!c.name.trim()||c.name.length>80)throw new Error('课程名不能为空且最多80字');
  if(typeof c.classroom!=='string'||c.classroom.length>100)throw new Error('教室应为文本且最多100字');
  if(!Number.isInteger(c.weekday)||c.weekday<1||c.weekday>7)throw new Error('星期须为1至7');
  courseRange(c);
  const start=c.startWeek??1,end=c.endWeek??20;
  if(!Number.isInteger(start)||!Number.isInteger(end)||start<1||end>30||start>end)throw new Error('周次应为1至30，起始不晚于结束');
  if(!['all','odd','even'].includes(c.weekMode??'all'))throw new Error('单双周应为all/odd/even');
  if(c.color!==undefined&&!/^#[\da-f]{6}$/i.test(c.color))throw new Error('课程颜色须为六位十六进制');
  if(c.teacher!==undefined&&(typeof c.teacher!=='string'||c.teacher.length>50))throw new Error('教师应为文本且最多50字');
  return c;
}
export function conflictWith(c,list) {
  const [a,b]=courseRange(c);
  for(const other of list) {
    if(other.id===c.id||other.weekday!==c.weekday)continue;
    const [x,y]=courseRange(other);
    if(a>=y||x>=b)continue;
    for(let w=1;w<=30;w++)if(activeInWeek(c,w)&&activeInWeek(other,w))return `与「${other.name}」第${w}周时间冲突`;
  }
  return '';
}
export function validateTask(t) {
  if(!t||!Number.isSafeInteger(t.id)||t.id<1)throw new Error('待办ID必须为正整数');
  if(typeof t.title!=='string'||!t.title.trim()||t.title.length>160)throw new Error('待办标题不能为空且最多160字');
  if(typeof t.type!=='string'||typeof t.deadline!=='string'||typeof t.done!=='boolean')throw new Error('待办字段格式无效');
  if(!['作业','项目','考试','其他'].includes(t.type))throw new Error('未知待办类型');
  if(t.courseName!==undefined&&(typeof t.courseName!=='string'||t.courseName.length>80))throw new Error('关联课程应为文本且最多80字');
  if(t.deadline!=='未设置'){
    if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(t.deadline)||Number.isNaN(Date.parse(t.deadline)))throw new Error('截止时间格式无效');
    localDate(t.deadline.slice(0,10)); minutes(t.deadline.slice(11));
  }
  if(t.remindEnabled!==undefined&&typeof t.remindEnabled!=='boolean')throw new Error('提醒开关格式无效');
  if(t.remindAdvanceMinutes!==undefined&&(!Number.isInteger(t.remindAdvanceMinutes)||t.remindAdvanceMinutes<0||t.remindAdvanceMinutes>10080))throw new Error('提前提醒分钟须为0至10080');
  if(t.remindRepeat!==undefined&&!['none','daily','weekly'].includes(t.remindRepeat))throw new Error('重复提醒规则无效');
  if(t.remindAt!==undefined&&typeof t.remindAt!=='string')throw new Error('提醒时间应为文本');
  if(t.remindAt&&(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(t.remindAt)||Number.isNaN(Date.parse(t.remindAt))))throw new Error('提醒时间格式无效');
  if(t.remindAt){localDate(t.remindAt.slice(0,10));minutes(t.remindAt.slice(11));}
  for(const key of ['remindedAt','lastRemindedAt'])if(t[key]!==undefined&&(!Number.isFinite(t[key])||t[key]<0))throw new Error('提醒记录格式无效');
  return t;
}
export function validateData(raw) {
  raw=clone(raw);
  if(Array.isArray(raw?.tasks))for(const task of raw.tasks){
    if(typeof task?.deadline==='string'&&/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(task.deadline))task.deadline=task.deadline.replace(' ','T');
    if(typeof task?.remindAt==='string'&&/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(task.remindAt))task.remindAt=task.remindAt.replace(' ','T');
    if(task?.lastRemindedAt!==undefined&&task.remindedAt===undefined)task.remindedAt=task.lastRemindedAt;
  }
  if(!raw||raw.version!==VERSION||!Array.isArray(raw.courses)||!Array.isArray(raw.tasks)||!raw.settings)throw new Error('不是CampusMate v2完整备份');
  if(raw.courses.length>500||raw.tasks.length>1000)throw new Error('课程/待办超过数量上限');
  for(const [name,list,validator] of [['课程',raw.courses,validateCourse],['待办',raw.tasks,validateTask]]) {
    const ids=new Set();list.forEach((item,i)=>{try{validator(item);if(ids.has(item.id))throw new Error('ID重复');ids.add(item.id);}catch(e){throw new Error(`${name}第${i+1}条：${e.message}`);}});
  }
  if(typeof raw.settings.nickname!=='string'||raw.settings.nickname.length>40)throw new Error('昵称格式无效');
  if(raw.revision!==undefined&&(!Number.isSafeInteger(raw.revision)||raw.revision<0||raw.revision>=Number.MAX_SAFE_INTEGER))throw new Error('修订号格式无效');
  if(raw.savedAt!==undefined&&raw.savedAt!==''&&!(typeof raw.savedAt==='number'&&Number.isFinite(raw.savedAt)&&raw.savedAt>=0)&&!(typeof raw.savedAt==='string'&&Number.isFinite(Date.parse(raw.savedAt))))throw new Error('保存时间格式无效');
  if(typeof raw.settings.semesterStart!=='string')throw new Error('学期开始日期应为文本');
  if(raw.settings.semesterStart)localDate(raw.settings.semesterStart);
  if(raw.settings.theme===undefined)raw.settings.theme='light';
  if(!['light','dark'].includes(raw.settings.theme))throw new Error('主题格式无效');
  for(const c of raw.courses){const conflict=conflictWith(c,raw.courses);if(conflict)throw new Error(`备份课程：${conflict}`);}
  return clone(raw);
}
export class SnapshotStore {
  constructor(storage,key='campusmate-demo-v2'){this.storage=storage;this.key=key;this.currentSlot=null;this.currentRaw=null;this.needsPointerRepair=false;this.revision=0;}
  load(fallback){
    let pointer=null,readError=false;
    try{pointer=this.storage.getItem(`${this.key}:active`);}catch{readError=true;}
    const active=['a','b'].includes(pointer)?pointer:'a';
    for(const slot of [active,active==='a'?'b':'a']){try{
      const raw=this.storage.getItem(`${this.key}:${slot}`);
      if(raw){const data=validateData(JSON.parse(raw));this.currentSlot=slot;this.currentRaw=raw;this.revision=data.revision||0;this.needsPointerRepair=false;
        if(pointer!==slot){try{this.storage.setItem(`${this.key}:active`,slot);}catch{this.needsPointerRepair=true;}}
        return {data,recovered:pointer!==slot,warning:this.needsPointerRepair?'存储暂不可写，已保留有效数据；请先导出备份。':'',persisted:true};}
    }catch(e){if(e.name==='SecurityError')readError=true;}}
    return {data:clone(fallback),recovered:false,warning:readError?'浏览器存储不可用，当前仅显示示例；无法保存时请导出备份。':'',persisted:false};
  }
  save(data){
    const value=validateData(data);let active=this.storage.getItem(`${this.key}:active`)??'a';
    if(this.currentSlot){
      if(['a','b'].includes(active)&&active!==this.currentSlot&&!this.needsPointerRepair)throw new Error('数据已在其他窗口更新，请刷新后重新编辑');
      if(this.storage.getItem(`${this.key}:${this.currentSlot}`)!==this.currentRaw)throw new Error('数据已在其他窗口更新，请刷新后重新编辑');
      if(active!==this.currentSlot||this.needsPointerRepair){this.storage.setItem(`${this.key}:active`,this.currentSlot);active=this.currentSlot;this.needsPointerRepair=false;}
    }else if(this.storage.getItem(`${this.key}:a`)||this.storage.getItem(`${this.key}:b`)){
      for(const slot of ['a','b']){try{validateData(JSON.parse(this.storage.getItem(`${this.key}:${slot}`)));throw new Error('数据已在其他窗口更新，请刷新后重新编辑');}catch(e){if(e.message.includes('其他窗口'))throw e;}}
    }
    const target=active==='a'?'b':'a';
    value.savedAt=new Date().toISOString();value.revision=Math.max(Number(data.revision)||0,this.revision)+1;
    if(!Number.isSafeInteger(value.revision))throw new Error('修订号超出上限，请导出数据');
    const text=JSON.stringify(value);this.storage.setItem(`${this.key}:${target}`,text);
    if(this.storage.getItem(`${this.key}:${target}`)!==text)throw new Error('存储读回失败');
    try{this.storage.setItem(`${this.key}:active`,target);}catch(e){this.needsPointerRepair=!!this.currentSlot;throw e;}
    this.currentSlot=target;this.currentRaw=text;this.revision=value.revision;return value;
  }
  restorePrevious(){const pointer=this.storage.getItem(`${this.key}:active`),active=this.needsPointerRepair?this.currentSlot:pointer;if(!['a','b'].includes(active))throw new Error('没有可恢复的活动快照');if(this.currentSlot&&active!==this.currentSlot&&!this.needsPointerRepair)throw new Error('数据已在其他窗口更新，请刷新后再恢复');const other=active==='a'?'b':'a';const raw=this.storage.getItem(`${this.key}:${other}`);if(!raw)throw new Error('还没有上一版快照');const data=validateData(JSON.parse(raw));this.storage.setItem(`${this.key}:active`,other);this.currentSlot=other;this.currentRaw=raw;this.needsPointerRepair=false;this.revision=Math.max(this.revision,data.revision||0);return data;}
}
export function csvRows(text){
  const rows=[];let row=[],cell='',quote=false,closed=false;
  for(let i=0;i<text.length;i++){const c=text[i];if(c==='"'){if(quote&&text[i+1]==='"'){cell+='"';i++;}else if(quote){quote=false;closed=true;}else if(!cell.trim()&&!closed){cell='';quote=true;}else throw new Error('CSV引号位置无效');}else if(!quote&&(c===','||c==='\t')){row.push(cell);cell='';closed=false;}else if(!quote&&(c==='\n'||c==='\r')){if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell);if(row.some(v=>v.trim()))rows.push(row);row=[];cell='';closed=false;}else if(closed){if(!/\s/.test(c))throw new Error('CSV引号后应为分隔符');}else cell+=c;}
  if(quote)throw new Error('CSV引号未闭合');row.push(cell);if(row.some(v=>v.trim()))rows.push(row);return rows;
}
export function parseCourses(text,existing=[]){
  if(text.length>1000000)throw new Error('导入内容不得超过1MB');
  let rows;
  if(text.trim().startsWith('[')){rows=JSON.parse(text);if(!Array.isArray(rows))throw new Error('JSON须为课程数组');}
  else {let values=csvRows(text.trim());if(!values.length)throw new Error('没有课程');if(['name','课程名','课程名称'].includes(values[0][0].trim()))values=values.slice(1);rows=values.map((r,i)=>{if(r.length<4)throw new Error(`第${i+1}行需要课程名、教室、星期、时间`);return{name:r[0].trim(),classroom:r[1].trim(),weekday:Number(r[2]),time:r[3].trim(),startWeek:r[4]?Number(r[4]):1,endWeek:r[5]?Number(r[5]):20,weekMode:r[6]?.trim()||'all',teacher:r[7]?.trim()||''};});}
  if(!rows.length||rows.length>500||rows.length+existing.length>500)throw new Error('课程总数不得超过500条');
  const combined=clone(existing),result=[];
  rows.forEach((row,i)=>{const c={...row,id:newId(combined),color:row.color||'#e7edf8',startWeek:row.startWeek??1,endWeek:row.endWeek??20,weekMode:row.weekMode??'all'};try{validateCourse(c);const conflict=conflictWith(c,combined);if(conflict)throw new Error(conflict);combined.push(c);result.push(c);}catch(e){throw new Error(`第${i+1}条：${e.message}`);}});
  return result;
}
export function gridPlacement(c){const [start,end]=courseRange(c),from=Math.max(480,start),to=Math.min(1200,end);if(to<=from)return null;return {top:(from-480)/60*49+3,height:Math.max(6,(to-from)/60*49-6)};}
export function advanceReminders(data,now=Date.now()){
  const next=clone(data),deliveries=[];let changed=false;
  for(const t of next.tasks){
    if(t.done||t.remindEnabled===false||!t.remindAt)continue;
    const event=Date.parse(t.remindAt),fire=event-(t.remindAdvanceMinutes||0)*60000,last=t.remindedAt??t.lastRemindedAt??0;
    if(!Number.isFinite(fire)||fire>now||last>=fire)continue;
    if(now-fire<=120000)deliveries.push(clone(t));
    t.remindedAt=now;t.lastRemindedAt=now;changed=true;
    if(['daily','weekly'].includes(t.remindRepeat)){
      const d=new Date(event),days=t.remindRepeat==='daily'?1:7;
      do{d.setDate(d.getDate()+days);}while(d.getTime()-(t.remindAdvanceMinutes||0)*60000<=now);
      t.remindAt=`${dateKey(d)}T${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
    }else t.remindEnabled=false;
  }
  return {next,deliveries,changed};
}
export function coursesForDate(data,key){const d=localDate(key),week=weekNumber(key,data.settings.semesterStart);return data.courses.filter(c=>c.weekday===(d.getDay()||7)&&activeInWeek(c,week)).sort((a,b)=>courseRange(a)[0]-courseRange(b)[0]);}
export function seedData(now=new Date()){
  const day=dateKey(now),tomorrow=dateKey(new Date(+now+86400000));
  const courses=[
    [1,'数据结构与算法','花江 · 11教 305',1,'08:00 - 09:35','#e5ecfa','陈老师'],
    [2,'交互设计基础','花江 · 12教 208',1,'10:00 - 11:35','#f7ebdd','李老师'],
    [3,'操作系统','花江 · 11教 305',1,'14:00 - 15:35','#e7eee5','王老师'],
    [4,'计算机网络','花江 · 11教 402',2,'08:00 - 09:35','#ece7f7','赵老师'],
    [5,'移动应用开发','创新实验室 · 302',2,'14:00 - 15:35','#e5ecfa','刘老师'],
    [6,'软件工程','花江 · 12教 106',3,'10:00 - 11:35','#f7ebdd','陈老师'],
    [7,'数据库系统','花江 · 11教 305',4,'08:00 - 09:35','#e7eee5','王老师'],
    [8,'人机交互实践','创新实验室 · 302',4,'14:00 - 15:35','#ece7f7','李老师'],
    [9,'数据结构实验','创新实验室 · 301',5,'10:00 - 11:35','#e5ecfa','陈老师'],
    [10,'创新项目工作坊','创新实验室 · 302',6,'10:00 - 11:35','#f7ebdd','项目组'],
    [11,'作品集设计讨论','图书馆 · 研讨室',6,'14:00 - 15:35','#e7eee5','项目组']
  ].map(([id,name,classroom,weekday,time,color,teacher])=>({id,name,classroom,weekday,time,color,teacher,startWeek:1,endWeek:20,weekMode:'all'}));
  const tasks=[
    {id:1,title:'完成课表交互原型',courseName:'移动应用开发',type:'项目',deadline:`${day}T18:00`,done:false},
    {id:2,title:'二叉树与图的实验报告',courseName:'数据结构与算法',type:'作业',deadline:`${tomorrow}T23:00`,done:false},
    {id:3,title:'阅读进程调度章节',courseName:'操作系统',type:'其他',deadline:`${tomorrow}T20:00`,done:false},
    {id:4,title:'整理数据库课堂笔记',courseName:'数据库系统',type:'作业',deadline:`${day}T12:00`,done:true},
    {id:5,title:'提交设计选题',courseName:'交互设计基础',type:'项目',deadline:`${day}T10:00`,done:true}
  ];
  return{version:VERSION,revision:0,savedAt:'',courses,tasks,settings:{nickname:'宋浩',semesterStart:'2026-09-07',theme:'light'}};
}
