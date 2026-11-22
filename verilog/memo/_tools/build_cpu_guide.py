from pathlib import Path
import re, json, hashlib, html
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.pagesizes import A5
from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, PageBreak, CondPageBreak
from reportlab.platypus.tableofcontents import TableOfContents

ROOT=Path(__file__).resolve().parents[3]
MEMO=ROOT/'verilog/memo'
MD=MEMO/'CPU_Module_Guide.md'
OUT=ROOT/'output/pdf/CPU_Module_Guide.pdf'
raw=MD.read_text(encoding='utf-8')
raw=re.sub(r'^> 소스: .*\n\n?', '', raw, flags=re.M)
raw=re.sub(r'<!-- AUTO_INVENTORY -->[\s\S]*','<!-- AUTO_INVENTORY -->',raw)
def clean(s): return re.sub(r'/\*.*?\*/|//[^\n]*','',s,flags=re.S)
inv=[];manifest={}
for project in ['Project10_mini_CPU','Project11_Upgrade_CPU']:
    root=ROOT/'verilog'/project;mods={}
    for p in sorted((root/'src_mini_CPU').rglob('*.v')):
        s=p.read_text(encoding='utf-8-sig');match=re.search(r'^\s*module\s+(\w+)',s,re.M)
        assert match,p
        mods[match[1]]={'text':s,'rel':p.relative_to(root/'src_mini_CPU').as_posix(),'line':s[:match.start()].count('\n')+1,'end':len(s.splitlines())}
        manifest[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    for n,m in mods.items():
        s=clean(m['text']);m['children']=[c for c in mods if c!=n and re.search(r'\b'+re.escape(c)+r'\s*(?:#\s*\([\s\S]*?\)\s*)?\w+\s*\(',s)]
    active=set()
    def visit(n):
        if n in active:return
        active.add(n)
        for c in mods[n]['children']:visit(c)
    visit('Pipeline_CPU')
    build=(root/'F_file/CPU.f').read_text(encoding='utf-8-sig').replace('\\','/')
    for n,m in mods.items():m.update(active=n in active,compiled='src_mini_CPU/'+m['rel'] in build)
    inv.append(mods)
p10,p11=inv
roles=dict(re.findall(r'^### (\w+) → (.+)$',raw,re.M))
assert set(p10)<=set(roles),set(p10)-set(roles)
changes={
 'FPU':'상위 재구성: special 패킷·valid·NV/NX·ISOLATE 추가. 산술/특수 결과를 최종 등록에서 선택.',
 'FADD_core':'hidden bit·유효 지수·0 부호 보완, 최종 처리를 FP_rounding으로 교체.',
 'FMUL_core':'12비트 signed 지수·subnormal 유효숫자·새 정규화·공통 반올림·flags 지연.',
 'FPU_classifier':'P10의 미완성 미사용 초안에서 실제 특수값 분류기로 완성·연결.',
 'FP_special':'신규. NaN/Inf/zero와 미지원 요청의 결과·flags·illegal 생성.',
 'FP_rounding':'신규. 다섯 반올림 모드·OF/UF/NX·subnormal 패킹 공통 처리.',
 'Final_MUX':'신규. 일반 산술값과 지연된 특수 결과 선택.',
 'barrel_shifter':'오른쪽 이동 시 버려지는 비트 OR를 sticky로 보존.',
 'Normalization_Controller':'EXPO_in 추가. 왼쪽 정규화를 최소 유효 지수 1에서 제한.',
 'Normalization_MUL':'선행 1 탐색·signed 지수·subnormal 우측 이동 후 FP_rounding에 전달.',
 'FPU_Control':'기본 op=3으로 미지원 요청 구분, fmt와 rm≤4 검사.',
 'FPU_unpack':'EXPO를 [30:23]으로 명시. W=32 동작은 동일.',
 'Register_file':'ZERO_REGISTER 추가. 정수 x0는 고정, FP f0는 일반 저장 가능.',
 'Pipeline_CPU':'FP Register_file에 ZERO_REGISTER(0). 새 NV/NX/valid_out은 CPU 외부에 미연결.',
 'Instruction_Memory':'초기 파일 경로를 ./runtime/memo/program.txt로 변경.',
 'Data_Memory':'초기 파일 경로를 ./runtime/memo/data.mem으로 변경.',
 'FPU_Hazard':'FPU_6clk wire 명시. 주요 해저드 알고리즘은 유지.'}
for n,to in {'EXPO_MUX':'FP_rounding','Exception_Handler_ADD':'FP_special·FP_rounding','Exception_Handler':'FP_special·FP_rounding','MUL_EXPO':'FMUL_core·FP_rounding','MUL_EXPO_ADD':'FMUL_core','MUL_SIGN':'FMUL_core 내부 XOR','MUX':'FPU 상위 선택 논리·Final_MUX','Rounding':'FP_rounding'}.items():
    changes[n]='파일 보존·활성 경로 제외. '+to+'으로 역할 이동.'
for n in p11:
    if n not in changes:
        assert re.sub(r'\s+','',clean(p10[n]['text']))==re.sub(r'\s+','',clean(p11[n]['text'])),n
        changes[n]='P10 핵심 RTL 동작 유지.' if p11[n]['active'] else 'P10과 같이 활성 CPU 연결에서 미사용.'
lines=[]
for line in raw.splitlines():
    lines.append(line);m=re.match(r'^### (P11 )?(\w+) →',line)
    if m and m[2] in inv[1 if m[1] else 0]:
        idx=1 if m[1] else 0;i=inv[idx][m[2]];state='활성 연결' if i['active'] else '현재 top 미연결'
        lines+=['',f"> 소스: P{10+idx}/src_mini_CPU/{i['rel']} · L{i['line']}-{i['end']} · {state}"]
lines+=['','### 파일 수와 활성 연결 수','','P10: 설계 모듈 정의 70개, 활성 62개. P11: 정의 73개, 활성 58개. 인스턴스 수나 플립플롭 수가 아니라 모듈 정의 종류 수다.','','### P10 전체 목록: 이름과 역할','']
for n,m in p10.items():lines.append(f"- **{n}** → {roles[n]} / {'활성' if m['active'] else '미연결'} / `{m['rel']}`.")
lines+=['','### P11 전체 목록: 유지·추가·대체 대조','']
for n,m in p11.items():
    status='활성' if m['active'] else ('빌드 포함·미연결' if m['compiled'] else '빌드 제외·미연결')
    lines.append(f"- **{n}** / {status} / `{m['rel']}`. {changes[n]}")
lines+=['','### 소스 위치와 범위','','P10은 verilog/Project10_mini_CPU, P11은 verilog/Project11_Upgrade_CPU다. 경로와 줄 번호는 작성 당시 로컬 소스 기준이며 이후 수정되면 바뀔 수 있다.','','RTL과 각 F_file/CPU.f, P11 README.md, docs/results.json, tb·tools를 참고했다. 테스트벤치는 16장에 별도로 정리했다. 작성 시 RTL 해시는 CPU_Module_Guide.sources.json에 남겼다.','']
source='\n'.join(lines);MD.write_text(source,encoding='utf-8')
(MEMO/'CPU_Module_Guide.sources.json').write_text(json.dumps({'date':'2026-10-28','scope':'local working tree','rtl_sha256':manifest,'module_count':[len(x) for x in inv],'active_count':[sum(m['active'] for m in x.values()) for x in inv]},ensure_ascii=False,indent=2),encoding='utf-8')
def blocks(s):
    out=[]
    for c in re.split(r'\n\s*\n',s):
        c=c.strip()
        if not c or c.startswith('<!--'):continue
        if re.match(r'^#{1,3} ',c):a,b=c.split(' ',1);out.append(('h'+str(len(a)),b))
        elif c.startswith('> '):out.append(('source',c[2:]))
        elif c.startswith('- '):out.extend(('li',l[2:]) for l in c.splitlines())
        elif re.match(r'^\d+\. ',c):out.extend(('ol',l) for l in c.splitlines())
        else:out.append(('p',c.replace('\n',' ')))
    return out
parsed=blocks(source)
def inline(s,pdf=False):
    if pdf:s=s.replace('−','-').replace('≈','~')  # Malgun has no glyph for these
    s=html.escape(s,quote=False)
    s=re.sub(r'`([^`]+)`',r'<font color="#225e79">\1</font>' if pdf else r'<code>\1</code>',s)
    return re.sub(r'\*\*([^*]+)\*\*',r'<b>\1</b>',s)
chapters=[];sections=[];cards=[];current=[];chapter_no=0
def finish_card():
    global current
    if current:cards.append('<article class="card">'+''.join(current)+'</article>');current=[]
def finish_section():
    global cards
    finish_card()
    if cards:sections.append(f'<section class="chapter" id="c{chapter_no}">'+''.join(cards)+'</section>');cards=[]
for kind,text in parsed:
    if kind=='h1':continue
    if kind=='h2':
        finish_section();chapter_no+=1;chapters.append((chapter_no,text));cards.append('<h2>'+inline(text)+'</h2>');continue
    if kind=='h3':finish_card();current.append('<h3>'+inline(text)+'</h3>')
    else:current.append(f'<p class="{kind}">'+('• ' if kind=='li' else '')+inline(text)+'</p>')
finish_section()
nav=''.join(f'<a href="#c{n}">{html.escape(t)}</a>' for n,t in chapters)
flow=''.join(f'<div class="stage"><b>{a}</b><span>{b}</span><small>{c}</small></div>' for a,b,c in [('IF','가져오기','PC · 명령어 메모리'),('ID','해석하기','디코더 · 레지스터 읽기'),('EX','실행하기','ALU · FPU · 분기'),('MEM','메모리 접근','load · store'),('WB','되쓰기','결과 선택 · Rd 기록')])
css='''
:root{--text:17px;--navy:#123e50;--teal:#126f75;--ink:#233642;--muted:#617480;--line:#d8e2e5;--paper:#f2f6f7}*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:118px}body{margin:0;background:var(--paper);color:var(--ink);font-family:system-ui,-apple-system,'Malgun Gothic',sans-serif;font-size:var(--text);line-height:1.85;overflow-wrap:anywhere}.hero{background:var(--navy);color:white;padding:48px max(22px,calc((100% - 840px)/2))}.eyebrow{font-size:12px;letter-spacing:2px;color:#9dd6d8}.hero h1{font-size:clamp(27px,5vw,42px);line-height:1.35;margin:14px 0}.hero p{color:#d4e4e9;max-width:650px}.badges{display:flex;gap:8px;flex-wrap:wrap}.badges span{border:1px solid #61909d;border-radius:30px;padding:4px 12px;font-size:13px}.toolbar{position:sticky;top:0;z-index:5;background:#fff;border-bottom:1px solid var(--line);padding:10px max(14px,calc((100% - 840px)/2));display:flex;gap:8px;align-items:center;flex-wrap:wrap}.toolbar input{flex:1;min-width:150px;font:inherit;font-size:16px;border:1px solid #b7cbd1;border-radius:8px;padding:9px 12px}.toolbar button,.toolbar a{border:1px solid #b7cbd1;border-radius:7px;padding:8px 10px;background:white;color:var(--navy);font:inherit;font-size:14px;text-decoration:none;cursor:pointer}.toolbar small{font-size:12px;line-height:1.3;color:var(--muted)}main{max-width:884px;margin:auto;padding:20px 20px 70px}.toc{background:white;border:1px solid var(--line);border-radius:12px;margin-bottom:22px;padding:18px}.toc summary{cursor:pointer;font-weight:700;color:var(--navy)}.toc nav{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin-top:16px}.toc a{font-size:14px;text-decoration:none;color:var(--teal);padding:5px}.chapter{margin:32px 0}.chapter h2{font-size:25px;line-height:1.45;color:var(--navy);padding:14px 0;border-top:3px solid var(--teal)}.card{background:white;border:1px solid var(--line);border-radius:12px;padding:24px;margin:15px 0;box-shadow:0 2px 3px #123e5005}.card h3{font-size:21px;line-height:1.5;margin:0 0 18px;color:var(--navy)}p{margin:12px 0}.li,.ol{padding-left:15px;text-indent:-15px}.source{font-size:12px;color:var(--muted);line-height:1.7;border-left:3px solid #a9c5cc;padding-left:10px}.card code{font-size:.91em;background:#edf4f6;border-radius:4px;padding:2px 4px;color:#145c76;white-space:normal}.flow{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin:24px 0}.stage{background:#e5f0f1;border-top:3px solid var(--teal);padding:12px;border-radius:7px}.stage b,.stage span,.stage small{display:block}.stage b{color:var(--teal)}.stage span{font-size:15px}.stage small{font-size:11px;color:var(--muted)}[hidden]{display:none!important}.empty{padding:22px;text-align:center}footer{border-top:1px solid var(--line);padding:20px;font-size:13px;color:var(--muted)}
@media(max-width:550px){main{padding:12px 12px 60px}.card{padding:20px 17px}.card h3{font-size:20px}.chapter h2{font-size:23px}.toc nav{grid-template-columns:1fr}.flow{grid-template-columns:1fr}.stage{display:grid;grid-template-columns:45px 1fr;gap:0 8px;padding:9px 13px}.stage small{grid-column:2}.hero{padding:30px 20px}.toolbar small{display:none}}
@media print{.toolbar,.toc{display:none}.hero{background:white;color:#123e50;padding:0}.hero p{color:#233642}.card{box-shadow:none;break-inside:auto}.source{font-size:9px}.chapter{break-before:page}body{font-size:11pt;background:white}main{max-width:none}}
'''
js='''const q=document.getElementById('search'),cards=[...document.querySelectorAll('.card')],chapters=[...document.querySelectorAll('.chapter')],counter=document.getElementById('count');function filter(){const term=q.value.trim().toLowerCase();let n=0;cards.forEach(c=>{c.hidden=term&&!c.textContent.toLowerCase().includes(term);if(!c.hidden)n++});chapters.forEach(s=>s.hidden=![...s.querySelectorAll('.card')].some(c=>!c.hidden));counter.textContent=term?n+'개 항목':'';document.getElementById('empty').hidden=n!==0;}q.addEventListener('input',filter);let size=17;function zoom(d){size=Math.max(15,Math.min(23,size+d));document.documentElement.style.setProperty('--text',size+'px')}document.getElementById('plus').onclick=()=>zoom(1);document.getElementById('minus').onclick=()=>zoom(-1);document.getElementById('toclink').onclick=()=>{document.getElementById('contents').open=true;q.value='';filter()};document.querySelectorAll('.toc a').forEach(a=>a.addEventListener('click',()=>{q.value='';filter()}));'''
js=js.replace("let n=0;cards.forEach(c=>{c.hidden=term&&!c.textContent.toLowerCase().includes(term);", "const exact=cards.filter(c=>{const h=c.querySelector('h3');return h&&h.textContent.toLowerCase().split(' →')[0].replace(/^p11 /,'')===term});document.querySelector('.hero').hidden=!!term;document.querySelector('.flow').hidden=!!term;document.querySelector('.toc').hidden=!!term;let n=0;cards.forEach(c=>{c.hidden=!!term&&(exact.length?!exact.includes(c):!c.textContent.toLowerCase().includes(term));")
page='''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#123e50"><title>Project10 → Project11 CPU 모듈 해설</title><style>'''+css+'''</style></head><body><header class="hero"><div class="eyebrow">RTL STUDY GUIDE · 2026.10.28</div><h1>Project10에서<br>Project11까지</h1><p>모듈 이름으로 찾고, 한 줄 역할로 이해한 뒤,<br>실제 연결·원리·변경점까지 읽는 CPU 안내서</p><div class="badges"><span>P10 정의 70개</span><span>P11 정의 73개</span><span>오프라인 읽기</span></div></header><div class="toolbar"><input id="search" type="search" aria-label="모듈명 또는 개념 검색" placeholder="PC_Adder, f0, sticky 검색"><button id="minus" aria-label="글자 작게">가−</button><button id="plus" aria-label="글자 크게">가+</button><a href="#contents" id="toclink">목차</a><small id="count" aria-live="polite"></small></div><main><details class="toc" id="contents"><summary>'''+str(len(chapters))+'''개 장 목차 펼치기</summary><nav>'''+nav+'''</nav></details><div class="flow">'''+flow+'''</div><p id="empty" class="empty" hidden>일치하는 내용이 없습니다. 다른 검색어를 입력해 보세요.</p>'''+''.join(sections)+'''<footer>로컬 RTL 기준 학습 문서 · RTL 변경 없음 · P11 회귀 2026-10-28 재실행 PASS<br>HTML 하나로 열 수 있으며 외부 폰트·스크립트·인터넷 연결이 필요하지 않습니다.</footer></main><script>'''+js+'''</script></body></html>'''
(MEMO/'CPU_Module_Guide.html').write_text(page,encoding='utf-8')

pdfmetrics.registerFont(TTFont('Malgun','C:/Windows/Fonts/malgun.ttf'))
pdfmetrics.registerFont(TTFont('MalgunBold','C:/Windows/Fonts/malgunbd.ttf'))
pdfmetrics.registerFontFamily('Malgun',normal='Malgun',bold='MalgunBold',italic='Malgun',boldItalic='MalgunBold')
NAVY=colors.HexColor('#123e50');TEAL=colors.HexColor('#126f75');INK=colors.HexColor('#233642')
def style(name,size,leading,bold=False,**kw):return ParagraphStyle(name,fontName='MalgunBold' if bold else 'Malgun',fontSize=size,leading=leading,textColor=INK,wordWrap='CJK',spaceAfter=8,**kw)
styles={'p':style('Body',10.2,16.5),'source':style('Source',7.1,11),'h2':style('Chapter',20,28,True,keepWithNext=True),'h3':style('Module',13.4,20,True,spaceBefore=17,keepWithNext=True),'li':style('Bullet',10,16.4,leftIndent=11,firstLineIndent=-9),'cover':style('Cover',29,43,True),'sub':style('Sub',12,21)}
styles['h2'].textColor=NAVY;styles['h3'].textColor=TEAL;styles['source'].textColor=colors.HexColor('#617480')
styles['source'].keepWithNext=True
styles['h2'].spaceBefore=16
PW,PH=A5
class GuideDoc(BaseDocTemplate):
    def __init__(self,path):
        super().__init__(str(path),pagesize=A5,leftMargin=30,rightMargin=30,topMargin=40,bottomMargin=36,title='Project10에서 Project11까지: CPU 모듈 해설',author='RTL Study Guide')
        self.addPageTemplates(PageTemplate(id='Guide',frames=[Frame(30,36,PW-60,PH-76,id='body',leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0)],onPage=self.decorate))
    def decorate(self,c,d):
        c.saveState()
        if d.page>1:
            c.setStrokeColor(colors.HexColor('#d8e2e5'));c.line(30,PH-27,PW-30,PH-27);c.setFont('Malgun',7);c.setFillColor(TEAL);c.drawString(30,PH-20,'CPU MODULE GUIDE | PROJECT10 + PROJECT11')
        c.setFont('Malgun',7);c.setFillColor(colors.HexColor('#617480'));c.drawString(30,19,'2026.10.28 · 로컬 RTL 기준');c.drawRightString(PW-30,19,str(d.page));c.restoreState()
    def afterFlowable(self,f):
        if hasattr(f,'bookmark'):
            self.canv.bookmarkPage(f.bookmark);self.canv.addOutlineEntry(f.getPlainText(),f.bookmark,f.level,False)
            if f.level==0:self.notify('TOCEntry',(0,f.getPlainText(),self.page,f.bookmark))
OUT.parent.mkdir(parents=True,exist_ok=True)
story=[Spacer(1,54),Paragraph('Project10에서<br/>Project11까지',styles['cover']),Spacer(1,16),Paragraph('CPU 모듈 해설<br/>역할 · 동작 원리 · 연결 · 변경점',styles['sub']),Spacer(1,25),Paragraph('PC_Adder → 현재 PC에 4를 더해<br/>순차 실행할 다음 명령어 주소를 만든다.',styles['h3']),Spacer(1,18),Paragraph('모듈 이름과 한 줄 역할로 시작해<br/>정수 파이프라인과 FPU의 흐름을 따라가는<br/>휴대폰용 학습·면담 준비 문서',styles['p']),Spacer(1,20),Paragraph('P10: 70개 정의 / 62개 활성<br/>P11: 73개 정의 / 58개 활성<br/>소스 위치 · 전체 모듈 대조표 포함',styles['p']),PageBreak(),Paragraph('읽는 길잡이',styles['h2']),Paragraph('처음에는 각 모듈의 제목만 읽고 큰 흐름을 잡으세요. 다음에는 원리와 예시를 읽으며 소스 신호를 따라가세요. P11은 14장부터 21장까지 변경 이유, 새 FP32 개념, 7단 시간축, 모듈별 변경, 계산 예시, CPU 연결 범위, 검증 환경을 차례로 설명하고, 24장에서 모든 파일을 대조합니다.',styles['p']),Paragraph('목차의 장 제목을 누르면 해당 페이지로 이동합니다. PDF 앱의 책갈피에서는 개별 모듈도 찾을 수 있습니다. 같은 내용의 HTML은 모듈명 검색과 글자 크기 조절을 지원합니다.',styles['p']),Spacer(1,12)]
toc=TableOfContents();toc_style=style('TOC',8.8,12,spaceBefore=1);toc_style.spaceAfter=0;toc.levelStyles=[toc_style];story.append(toc)
head_id=0;has_chapter=False
for kind,text in parsed:
    if kind=='h1':continue
    if not has_chapter and kind!='h2':continue
    if kind=='h2':
        has_chapter=True
        story.append(PageBreak() if text.startswith(('01.','14.','24.')) else CondPageBreak(190))
        head_id+=1;p=Paragraph(inline(text,True),styles['h2']);p.bookmark=f'h-{head_id}';p.level=0;story.append(p)
    elif kind=='h3':
        head_id+=1;p=Paragraph(inline(text,True),styles['h3']);p.bookmark=f'h-{head_id}';p.level=1;story.append(p)
    elif kind in ('li','ol'):story.append(Paragraph(('• ' if kind=='li' else '')+inline(text,True),styles['li']))
    else:story.append(Paragraph(inline(text,True),styles.get(kind,styles['p'])))
GuideDoc(OUT).multiBuild(story)
print(json.dumps({'markdown':str(MD),'html':str(MEMO/'CPU_Module_Guide.html'),'pdf':str(OUT),'modules':len(manifest),'blocks':len(parsed),'chapters':len(chapters)},ensure_ascii=False))
