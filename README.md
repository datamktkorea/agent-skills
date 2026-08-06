# agent-skills

데이터마케팅코리아 데이터엔지니어링팀의 Claude Code 워크플로 자동화 스킬 묶음.

## Prerequisites

스킬 대부분(SDLC·노션 API 관련)은 팀 공용 설정을 참조합니다.

```bash
# 1. 팀 설정 레포를 홈 디렉토리에 클론
git clone <.datamktkorea 레포 URL> ~/.datamktkorea

# 2. 템플릿을 복사하고 본인 Notion Integration 키를 기입
cp ~/.datamktkorea/config.template.json ~/.datamktkorea/config.json
$EDITOR ~/.datamktkorea/config.json   # notion_token 값만 본인 키로 채움

# 3. 노션 API 스크립트 의존성 설치
brew install jq
```

`~/.datamktkorea/config.json`에는 노션 토큰과 DB ID가 저장됩니다.

> **이 파일은 절대 커밋하지 마세요.**

## Installation

마켓플레이스를 추가하고, 필요한 플러그인만 골라 설치합니다. 플러그인은 설치 시점에 **User**(`~/.claude`) 또는 **Project**(`.claude`) 스코프를 선택할 수 있습니다.

```shell
/plugin marketplace add datamktkorea/agent-skills

/plugin install dmk-oneteam@datamktkorea-agent-skills
/plugin install dmk-sdlc@datamktkorea-agent-skills
/plugin install dmk-stack@datamktkorea-agent-skills
```

## Claude Code 외 다른 에이전트에서 사용하기

Claude Code 플러그인 마켓플레이스 구조라 `/plugin install`은 Claude Code 전용입니다. Codex CLI, Cursor 등 SKILL.md 호환 에이전트에서 쓰려면 [`npx skills`](https://github.com/vercel-labs/skills)로 설치하면 됩니다. 별도 등록/제출 절차는 없습니다 — public 저장소라 바로 됩니다.

루트의 `skills/`는 각 플러그인의 `plugins/<plugin>/skills/<name>/`를 가리키는 symlink 모음입니다. `npx skills`는 저장소 루트의 정해진 경로(`skills/`, `.claude/skills/` 등)만 스캔하기 때문에, `plugins/` 아래에만 있으면 인식하지 못해 이 symlink 레이어를 추가했습니다.

```bash
# 전체 스킬을 한 번에 설치
npx skills add datamktkorea/agent-skills --skill '*' -a <agent>

# 특정 스킬만 설치
npx skills add datamktkorea/agent-skills --skill git-commit -a <agent>
```

`<agent>`는 `codex`, `cursor` 등 설치 대상 에이전트 이름입니다. 기본은 project 스코프(`./<agent>/skills/`)이며 `-g`를 붙이면 global(`~/<agent>/skills/`)에 설치됩니다.

> 새 스킬을 추가할 때는 `plugins/<plugin>/skills/<name>/` 아래에 만든 뒤, `skills/<name>`에 상대경로 symlink(`ln -s ../plugins/<plugin>/skills/<name> skills/<name>`)를 함께 추가해야 `npx skills`에서 보입니다.

## Plugins & Skills

### `dmk-oneteam` — 모든 프로젝트가 함께 쓰는 범용 개발자 툴킷

- **bootstrap** — 신규 스킬 온보딩 가이드
- **git-commit** — Conventional Commits + Gitmoji 커밋 메시지 작성
- **git-pull-request** — PR 제목/본문 자동 생성
- **format-code-comments** — TS/Python에 한국어 주석·docstring 자동 작성
- **format-and-commit** — format-code-comments → git-commit 순차 실행 (PR 직전 한 번에 처리)

### `dmk-sdlc` — 소프트웨어 개발 라이프사이클과 지식 작업 자동화

- **notion-api** — 노션 API(2026-03-11) curl 래퍼. 다른 스킬의 공용 레이어
- **task-writer** — Notion Requests DB에 태스크 작성 (간결/보통/상세 티어 자동 판단, 검토 흡수)
- **write-sdlc-trigger** — 요청 기반 트리거 페이지 작성
- **write-sdlc-spec** — 트리거 기반 스펙 페이지 작성
- **decompose-sdlc-trigger** — 트리거를 하위 요청으로 분해
- **write-meeting-notes** — 회의록 작성 및 노션 업로드

### `dmk-stack` — 기술 스택별 엔지니어링 플레이북과 코드 리뷰 가이드

- **fastapi-best-practices** — FastAPI 코드 리뷰 기준
- **react-state-orchestration** — React 상태 관리 패턴

## Development

로컬 수정분을 테스트할 때 플러그인 디렉토리를 직접 지정:

```bash
claude --plugin-dir ./
```

스킬 수정 후 Claude Code 내에서 `/reload-plugins`로 반영.

## Contributing

내부 저장소입니다. 신규 스킬 추가와 기존 스킬 수정은 반드시 `/skill-creator` 스킬을 사용하고 영어로 작성해주세요.
