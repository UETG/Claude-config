# Claude-config — 논문 찾기 워크플로우 셋업

**한 줄 요약**: Chrome 자동화 + Google Scholar + PDF 다운로드 + 텍스트 검증을 통한
"논문 찾기" 작업을 Claude Code 가 수행하도록 만드는 Windows 환경 셋업.

이 환경이 설치되면, Claude 에게 *"이 주제 관련 논문 N편 찾아서 정리해줘"* 라고 하면:
1. **Google Scholar 자동 검색**
2. **출판사별 전략으로 PDF 직접 다운로드** (IEEE Xplore, MDPI, Nature, Springer, Wiley 등)
3. **PDF → 텍스트 추출**
4. **핵심 키워드로 검증** (off-topic / mismatch 자동 제외)
5. **표 + 인용문 발췌 형식으로 보고**

…를 자동으로 진행해줍니다.

---

## 🚀 새 컴퓨터에 셋업 (한 줄 명령)

PowerShell 열고:

```powershell
irm https://raw.githubusercontent.com/UETG/Claude-config/main/bootstrap.ps1 | iex
```

---

## ⚙️ bootstrap.ps1 가 자동으로 하는 것 (7단계)

| Step | 작업 | 동의 prompt | 비고 |
|------|------|----------|------|
| 1 | Node.js / Git / VSCode 자동 설치 (winget) | ✅ 각각 묻기 | 이미 깔려있으면 스킵 |
| 2 | 이 repo 를 `~/claude-config\` 에 clone | (이미 있으면 git pull) | |
| 3 | VSCode 에 Claude Code 확장 자동 설치 + 로그인 대기 | ✅ | 본인 Anthropic 계정으로 |
| 4 | `CLAUDE.md` / `settings.local.json` / `mcp-servers.json` 배치 | 자동 | 기존 파일 자동 백업 |
| 5 | 작업 폴더 `~/paper-research/download_tmp/` 생성 + `extract.js` 복사 | 자동 | |
| 6 | Playwright Chromium (~200MB) 다운로드 | ✅ | Chrome 자동화의 핵심 |
| 7 | `pdf-parse` npm 패키지 설치 | ✅ | PDF → 텍스트 변환용 |

각 도구는 **이미 설치되어 있으면 자동 스킵**, 없을 때만 동의 prompt 띄움.

---

## 📦 포함된 파일

| 파일 | 용도 | 배치 위치 |
|------|------|---------|
| `bootstrap.ps1` | **자동 셋업 스크립트** (7단계) | repo 루트 |
| `CLAUDE.md` | 사용자 전역 지침 — 논문 찾기 워크플로우, 출판사별 다운로드 전략, 협업 규칙 | `~/.claude/CLAUDE.md` |
| `settings.local.json` | Claude Code 권한 화이트리스트 (Allow prompt 최소화) | `~/.claude/settings.local.json` |
| `mcp-servers.json` | Playwright MCP 서버 등록 정보 | `~/.claude.json` 에 머지 |
| `extract.js` | PDF → 텍스트 변환 Node 스크립트 (pdf-parse v2 wrapper) | `~/paper-research/download_tmp/extract.js` |

---

## 🔬 실제 사용 예시

셋업 후 VSCode 에서 Claude Code 새 대화 → 첫 메시지:

```
오가닉 태양전지 효율 25% 이상 달성 관련 논문 5편 찾아서 표로 정리해줘.
```

Claude 가:
1. Google Scholar 자동 접속 (`browser_navigate`)
2. 결과 파싱 (제목, PDF URL, snippet, citation)
3. 출판사별 전략으로 PDF 직접 다운로드
4. `extract.js` 로 텍스트 추출
5. 키워드 검증 (`효율`, `25%` 등) → 부적합한 거 제외
6. 결과를 표로 정리 + 본문 인용문 직접 발췌

…까지 자동 진행해요.

---

## 🛠 수동 셋업 (스크립트 없이)

`bootstrap.ps1` 가 안 돌아가면 수동:

1. **Node.js v20+**: https://nodejs.org
2. **Git**: https://git-scm.com
3. **VSCode**: https://code.visualstudio.com
4. **Claude Code 확장**: VSCode 마켓플레이스 → 검색 → 설치 → 로그인
5. **이 repo clone**:
   ```powershell
   git clone https://github.com/UETG/Claude-config.git $env:USERPROFILE\claude-config
   ```
6. **파일 배치**: `bootstrap.ps1` 의 Step 4-5 참고
7. **Playwright**:
   ```powershell
   npx -y playwright install chromium
   ```
8. **pdf-parse**:
   ```powershell
   mkdir $env:USERPROFILE\paper-research\download_tmp
   Copy-Item $env:USERPROFILE\claude-config\extract.js $env:USERPROFILE\paper-research\download_tmp\
   cd $env:USERPROFILE\paper-research\download_tmp
   npm install pdf-parse
   ```

---

## 🔄 업데이트

워크플로우 (CLAUDE.md 등) 가 갱신되면 다른 머신에서:

```powershell
cd $env:USERPROFILE\claude-config
git pull
.\bootstrap.ps1
```

---

## ⚠️ 주의

- **Private vs Public**: 이 repo 는 **Public** 으로 운영 중. 인증 토큰·개인 식별자 없음.
- **본인 `~/.claude.json`** (Anthropic 인증 토큰 포함) 은 **절대 commit 금지**. 이 repo 는 `mcpServers` 부분만 분리해서 `mcp-servers.json` 으로 관리.
- **소속 IP**: IEEE Xplore 등 페이월 논문은 학교/회사 IP 에서만 자동 통과. VPN 사용 시 효과 있음.
