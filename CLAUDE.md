# CLAUDE.md — READCORE 코드베이스 가이드

## 프로젝트 개요

**READCORE**는 수능 국어 문해력 훈련을 위한 싱글 페이지 웹 앱입니다.
외부 프레임워크 없이 순수 HTML/CSS/JavaScript 단일 파일로 구성되어 있으며,
Claude API(Anthropic)를 활용해 지문 분석·채점·오답 선지 생성을 수행합니다.

---

## 파일 구조

```
/home/user/Readcore/
└── readcore_v3-1.html   # 앱 전체 (HTML + CSS + JS 통합, 약 1,250줄)
```

- **단일 파일 구조**: HTML, `<style>`, `<script>` 모두 한 파일에 존재
- 외부 의존: Google Fonts(Noto Serif KR), Anthropic Claude API
- 빌드 도구 없음 (npm, webpack 등 불필요)

---

## 화면 구조 (Screen 시스템)

화면 전환은 CSS `display:none` / `.on` 클래스 토글 방식으로 동작합니다.

| 화면 ID     | 역할                                         |
|-------------|----------------------------------------------|
| `sc-home`   | 홈 — 영역 선택, 내장 지문/지문함/지문 추가 탭 |
| `sc-preview`| 붙여넣기 지문 단락 구분 미리보기              |
| `sc-load`   | AI 분석/채점 중 로딩 스피너                   |
| `sc-read`   | 읽기 — 캔버스 손글씨 기호 표시 + 타이머       |
| `sc-result` | 결과 — 점수/등급 + 정답 오버레이 + AI 피드백  |

화면 전환 함수: `showScreen(id)` — 모든 `[id^=sc-]` 요소에서 `.on` 제거 후 대상 요소에 추가.

---

## 핵심 기능 및 코드 위치

### 1. Claude API 호출 (`callAPI`)

```javascript
async function callAPI(msgs, maxTok=1500) {
  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: maxTok,
      system: '수능 국어 전문가. 순수 JSON만 출력. 마크다운 절대 금지.',
      messages: msgs
    })
  });
}
```

- **모델**: `claude-sonnet-4-20250514`
- 브라우저에서 API를 직접 호출 (서버 없음)
- 응답은 항상 순수 JSON (마크다운 금지)
- API 키는 코드에 하드코딩되어 있지 않음 — 실행 시 입력 또는 별도 관리 필요

### 2. AI 호출 3가지 용도

| 함수 | 역할 |
|------|------|
| `analyzePassage()` | 붙여넣기 지문 → circleWords / underlineWords / triangleWords / parenWords / keyword 자동 추출 |
| `submitWork()` - OCR | 핵심 주장 캔버스(base64 PNG) → 텍스트 인식 |
| `submitWork()` - 채점 | OCR 텍스트 + 정답 keyword → score / grade / feedback |
| `generateTwists()` | 밑줄 구절 → 수능 오답 선지 패턴 생성 |

### 3. 캔버스 손글씨 시스템

단락마다 캔버스 2개 사용:
- `pcvs-{i}`: 지문 텍스트 위 기호(○, 밑줄, △, 괄호) 표시
- `kwcvs-{i}`: 핵심 주장 손글씨 입력

마우스/터치 이벤트 통합 지원. 펜/지우개 모드 전환, Undo, 전체 삭제 기능 포함.

### 4. 정답 오버레이 (`drawAnswers`)

제출 후 `rcvs-ans-{i}` 캔버스에 정답 기호를 자동 렌더링:
- `getBoundingClientRect()`로 DOM 내 단어 위치를 추적해 캔버스에 도형 그림
- 동그라미(파란 `#007aff`), 세모(주황 `#ff9500`), 밑줄(빨간 `#ff3b30`), 괄호(회색 `#3a3a3c`)

### 5. 지문함 파일 저장 (`saveFile`)

```javascript
function saveFile() {
  let html = document.documentElement.outerHTML;
  html = html.replace(
    'const USER_PASSAGES = [];',
    `const USER_PASSAGES = ${JSON.stringify(USER_PASSAGES, null, 2)};`
  );
  // Blob → 다운로드
}
```

HTML 파일 자체를 수정해서 다운로드합니다. 지문함 데이터를 파일 안에 영속 저장하는 방식이므로,
**`const USER_PASSAGES = [];` 마커 문자열이 반드시 유지**되어야 합니다.

---

## 기호 체계 (읽기 규칙)

| 기호 | 색상 | 의미 |
|------|------|------|
| ○ 동그라미 | 파란색 | 핵심 키워드 / 문학: 인물·화자 |
| 밑줄 | 빨간색 | 핵심 주장·결론 문장 |
| △ 세모 | 주황색 | 역접·전환어 (그러나, 반면, 하지만) |
| ( ) 괄호 | 회색 | 부연·연결어 → 스킵 (따라서, 즉, 예를 들어) |

---

## 주요 전역 상태 변수

```javascript
let topic = '과학·기술';    // 선택된 영역
let passage = null;          // 현재 지문 객체
let isPastedPassage = false; // 지문함 지문 여부
let paraStrokes = [];        // 단락별 기호 스트로크
let paraKwArr = [];          // 단락별 핵심주장 스트로크
let timerVal = 90;           // 타이머 (초)
let penMode = 'pen';         // 'pen' | 'eraser'
const USER_PASSAGES = [];    // 지문함 (인메모리)
```

---

## 데이터 흐름

```
[홈 - 영역 선택]
       ↓
startBuiltin() 또는 analyzePassage()
       ↓
[sc-read] 타이머 90초 + 캔버스 손글씨
       ↓
submitWork() 클릭
       ↓
  ① kwcvs 캔버스 → base64 PNG → Claude API (OCR)
  ② OCR 결과 + 정답 keyword → Claude API (채점)
  ③ renderResult() → 점수/등급 표시
  ④ generateTwists() → 오답 선지 (비동기)
       ↓
[sc-result] 정답 오버레이 + 피드백
```

---

## 내장 지문 구성 (`PASSAGES`)

총 9개 영역, 각 1~2개 지문:

| 영역 | 지문 수 | 예시 주제 |
|------|---------|----------|
| 과학·기술 | 2 | 빅데이터/알고리즘, 양자역학 |
| 인문·예술 | 2 | 자유의지/결정론, 숭고/칸트 |
| 사회·문화 | 1 | 필터버블/미디어리터러시 |
| 법·경제 | 2 | 외부효과/시장실패, 죄형법정주의 |
| 현대시 | 1 | 진달래꽃(김소월) |
| 현대소설 | 1 | 날개(이상) |
| 고전시가 | 1 | 청산리 벽계수야(황진이) |
| 고전소설 | 1 | 춘향전 |
| 향가·속요 | 1 | 청산별곡 |

나머지 영역(수필, 희곡, 화법, 작문, 매체 등)은 UI 탭은 있으나 내장 지문 없음 → 지문함에서 직접 추가 필요.

---

## 개발 규칙 및 주의사항

### 코드 수정 시

1. **단일 파일 원칙**: 별도 JS/CSS 파일 분리 없이 `readcore_v3-1.html` 한 파일 안에서 작업
2. **마커 문자열 보존**: `const USER_PASSAGES = [];` 문자열을 절대 수정하지 말 것 (파일 저장 기능 파괴)
3. **화면 전환**: `showScreen('sc-xxx')` 함수를 통해서만 화면 변경
4. **캔버스 ID 규칙**: `pcvs-{인덱스}`, `kwcvs-{인덱스}`, `rcvs-ans-{인덱스}` 패턴 유지

### API 관련

- API 키는 코드에 직접 삽입하지 않을 것 (보안)
- 브라우저 직접 호출이므로 Anthropic API의 CORS 정책 확인 필요
- Rate limit 에러 발생 시 `type: "exceeded_limit"` JSON 응답 처리 필요 (스크린샷에서 확인된 이슈)

### UI/UX

- 모바일 우선 설계: `max-width: 680px`, `user-scalable=no`
- 터치 이벤트와 마우스 이벤트 모두 지원해야 함
- 타이머는 90초 기본값, `timerVal` 변수로 조정 가능

### AI 프롬프트 규칙

- 시스템 프롬프트: `'수능 국어 전문가. 순수 JSON만 출력. 마크다운 절대 금지.'`
- 모든 API 응답은 JSON 파싱 전 마크다운 코드 블록 제거 처리 필요
- `generateTwists()` 등 비동기 AI 호출은 결과 화면 렌더링 후 추가 로드

---

## 개발/실행 방법

```bash
# 별도 빌드 불필요 — 브라우저에서 직접 열기
open readcore_v3-1.html

# 또는 로컬 서버 (API CORS 문제 대비)
python3 -m http.server 8080
# → http://localhost:8080/readcore_v3-1.html
```

---

## 알려진 이슈 (스크린샷 기준)

- **Rate Limit 에러**: `{"type":"exceeded_limit","resetsAt":...}` 형태로 API 응답 오는 경우 사용자에게 명확한 안내 필요
- 에러 메시지가 현재 raw JSON으로 노출되고 있음 → UI 개선 필요
