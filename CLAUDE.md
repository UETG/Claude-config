# CLAUDE.md — 논문 찾기 워크플로우 (사용자 레벨)

이 파일은 `~/.claude/CLAUDE.md` 로 배치되며, **모든 Claude Code 세션에서 자동 로드**되는 사용자 전역 지침이에요.
이 셋업의 핵심 가치는 **Chrome 자동화 기반 논문 찾기 워크플로우** — Google Scholar 자동 검색 → 출판사별 PDF 다운로드 → 텍스트 검증 → 정리 보고.

> 💡 본인 정보 (이메일·도메인·언어 선호 등) 는 따로 채우지 않아도 OK. 첫 메시지에서 자연스럽게 드러나면 Claude 가 자동 인식해요.

---

## 🔬 논문 찾기 워크플로우 (이 셋업의 핵심)

사용자가 "논문 찾아줘", "이 주제 관련 논문 N편", "이 가설 뒷받침할 자료" 등을 요청하면 아래 흐름으로 진행해주세요.

### 1. 검색
- **Google Scholar (`scholar.google.com`)** 을 Playwright MCP 브라우저로 조회
  - 키워드 직접 navigate: `https://scholar.google.com/scholar?q=<keywords>&hl=en`
  - 결과 파싱: `browser_evaluate` 로 `div.gs_r.gs_or` 셀렉터에서 title / PDF URL / snippet / citations 추출
  - 페이지 넘김: `start=10`, `start=20` URL 파라미터
- 결과 깔끔하게 보려면 `JSON.stringify(...)` + `filename: 'xxx.json'` 옵션으로 저장 후 `cat` 으로 읽기

### 2. PDF 다운로드 (출판사별 전략 — 검증됨)

| 출판사 | 방법 | 비고 |
|--------|------|------|
| **IEEE Xplore** | `stamp.jsp?arnumber={N}` 먼저 navigate → `getPDF.jsp?tp=&arnumber={N}&ref=` fetch | 소속 IP 있으면 페이월 통과 |
| **MDPI** | 직접 navigate (`/pdf?version=...`) → 자동 다운로드 → `.playwright-mcp/` 에서 가져옴 | OA. navigate 가 가장 안정적 |
| **Nature.com** | navigate → fetch | OA / 페이월 모두 |
| **Springer** | navigate → fetch | Akamai 챌린지는 페이지 로드 후 자동 통과 |
| **IOP / JJAP** | navigate → fetch | |
| **Wiley** (`onlinelibrary.wiley.com`) | `pdfdirect/` URL fetch | |
| **Taylor & Francis** | navigate (5초 대기) → fetch | OA 만 안정적 |
| **University repos** (`*.ac.uk`, `*.edu` 등) | 직접 fetch | 보통 잘 됨 |
| ❌ **ScienceDirect (Elsevier)** | **Cloudflare Turnstile 차단** | 거의 항상 막힘 — 다른 후보로 대체 |
| ❌ **AIP** (`pubs.aip.org`) | **Cloudflare 차단** | 대체 |
| ❌ **ResearchGate** | **Cloudflare 차단** | 대체 |

### 3. PDF fetch 패턴 (검증된 코드)

브라우저 컨텍스트 안에서 fetch → base64 → 파일 저장:
```js
async () => {
  const url = '...';
  const r = await fetch(url, {credentials: 'include'});
  if (!r.ok) return JSON.stringify({status: r.status, error: 'Fetch failed'});
  const buf = await r.arrayBuffer();
  const bytes = new Uint8Array(buf);
  let binary = '';
  const chunk = 8192;
  for (let i = 0; i < bytes.length; i += chunk) binary += String.fromCharCode.apply(null, bytes.slice(i, i + chunk));
  return JSON.stringify({size: bytes.length, contentType: r.headers.get('content-type'), b64: btoa(binary)});
}
```
→ `filename: 'fetch_xxx.txt'` 옵션으로 저장 → Node.js 로 base64 디코드 → PDF 파일 작성.

### 4. PDF → 텍스트 추출
- 도구: **`pdf-parse` v2** (Node.js 패키지)
- 재사용 스크립트: `~/paper-research/download_tmp/extract.js` (bootstrap 시 자동 배치됨)
- 사용법: `node extract.js input.pdf output.txt` → 페이지별 `===== PAGE N =====` 마커로 구분된 텍스트
- ⚠️ 일부 PDF 는 폰트 CMap 이 비표준 (Caesar shift +3 등) 이라 깨질 수 있어요. 그땐 다른 후보로 대체

### 5. 검증 (Verification — 중요)
- `Grep` 툴로 핵심 키워드 매칭 (사용자가 요청한 도구/재료/메커니즘/방법론 키워드)
- snippet 에서 보이는 내용과 본문이 실제로 일치하는지 확인
- **검증 실패하면 즉시 제외하고 다른 후보 찾기** — 사용자 요청 개수 채울 때까지 반복

### 6. 거부 룰 (일반 패턴)
사용자가 명시한 기준에 안 맞으면 즉시 제외:
- **off-topic 거부**: 사용자가 원한 키워드와 결과가 다른 토픽
- **대상/재료 mismatch**: 사용자가 A 대상 작업 중인데 결과가 B 대상
- **방법/도구 mismatch**: 특정 도구·방법론 요구했는데 다른 것 사용한 논문
- **메커니즘 mismatch**: 사용자가 원한 메커니즘과 다른 현상 다룬 논문

### 7. 저장 위치 컨벤션
- 첫 검색: `~/paper-research/download_tmp/`
- 주제별 분리: `~/paper-research/download_tmp_<topic>/` (예: `download_tmp_traps/`, `download_tmp_attention/`)
- 폴더 안에 `extract.js` + `node_modules/pdf-parse` 한 번 깔면 재사용 가능 (bootstrap 이 자동으로)

### 8. 보고 형식
- 한눈에 보는 표 (저자/연도, 저널, 핵심 도구/방법, 핵심 포인트)
- 각 논문별: 제목 + 인용수 + PDF 링크 + **본문 라인 번호와 함께 인용문 직접 발췌**
- 사용자 작업과 연관성 섹션 (있으면)

---

## 🛠️ 도구 셋업 (bootstrap.ps1 이 자동 설치하는 것들)

| 도구 | 용도 |
|------|------|
| **Node.js** v20+ | Playwright / pdf-parse 실행 환경 |
| **Playwright MCP** | Chrome 브라우저 자동화 (Scholar 접속, PDF 다운로드, fetch) — 22개 도구 |
| **pdf-parse v2** | PDF → 텍스트 변환 (`extract.js` 가 wrapper) |
| **Chromium** | Playwright 가 띄우는 헤드리스 브라우저 (~200MB) |
| `~/.claude/settings.local.json` | 권한 화이트리스트 (Bash, PowerShell, MCP 도구 등) — Allow prompt 최소화 |

세부 설정은 repo 의 `bootstrap.ps1` / `mcp-servers.json` / `settings.local.json` 참고.

---

## 📋 협업 규칙 (기본값 — 본인 선호로 조정 가능)

1. **자율 진행**: 권한 묻지 말고 알아서 진행. 정말 결정 필요한 경우만 확인.
2. **검증 → 제외 → 재검색 룰**: 후보 검증해서 부적합하면 즉시 제외, 사용자가 원한 개수 채울 때까지 계속 찾는다.
3. **응답은 짧게, 본질 위주**: 불필요한 서론·결론·과정 narration 최소화.
4. **파일 참조는 markdown 링크로**: `[filename.ext](relative/path)` — VSCode 에서 클릭 가능.
5. **이모지는 사용자가 요청 안 했으면 자제** (단 표·리포트 가독성용 ✅⭐ 같은 건 OK).

본인 작업 스타일에 맞게 위 항목 수정·추가하세요.

---

## 📦 다른 컴퓨터로 옮길 때

이 환경을 다른 머신에서 복원하려면 GitHub repo 의 bootstrap 스크립트 한 줄:

```powershell
irm https://raw.githubusercontent.com/UETG/Claude-config/main/bootstrap.ps1 | iex
```

자세한 셋업 절차는 [repo README](https://github.com/UETG/Claude-config) 참고.
