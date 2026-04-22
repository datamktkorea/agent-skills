# agent-skills

데이터마케팅코리아 팀의 Claude Code 워크플로 자동화 스킬 묶음. 요청 관리(SDLC), 회의록, 노션 연동을 Claude가 대화 맥락에서 자동으로 처리합니다.

## How it works

팀원이 Claude Code에 "이 요청을 트리거로 분해해줘" 같은 지시를 내리면 해당 스킬(`write-sdlc-trigger`, `decompose-sdlc-trigger` 등)이 발동해 노션 Requests/Triggers DB를 읽고 새 페이지를 생성합니다. 모든 노션 API 호출은 `notion-api` 스킬이 제공하는 공용 bash 스크립트(curl + jq)를 통해 이루어지며, 팀원은 `~/.datamktkorea/config.json`에 본인의 Notion Integration 키만 두면 됩니다.

## Prerequisites

스킬 대부분(SDLC·노션 API 관련)은 팀 공용 설정을 참조합니다.

```bash
# 1. 팀 설정 레포를 홈 디렉토리에 클론
git clone <datamktkorea/.datamktkorea 레포 URL> ~/.datamktkorea

# 2. 템플릿을 복사하고 본인 Notion Integration 키를 기입
cp ~/.datamktkorea/config.template.json ~/.datamktkorea/config.json
$EDITOR ~/.datamktkorea/config.json   # notion_token 값만 본인 키로 채움

# 3. 노션 API 스크립트 의존성 설치
brew install jq
```

`~/.datamktkorea/config.json`에는 노션 토큰과 DB ID가 저장됩니다. **이 파일은 절대 커밋하지 마세요.**

## Installation

```shell
/plugin marketplace add datamktkorea/agent-skills
/plugin install datamktkorea@datamktkorea
```

## Skills

### Notion 연동
- **notion-api** — 노션 API(2026-03-11) curl 래퍼. 다른 스킬의 공용 레이어
- **write-meeting-notes** — 회의록 작성 및 노션 업로드

### SDLC
- **write-sdlc-trigger** — 요청 기반 트리거 페이지 작성
- **write-sdlc-spec** — 트리거 기반 스펙 페이지 작성
- **decompose-sdlc-trigger** — 트리거를 하위 요청으로 분해

### Task
- **task-writer** — 로컬 마크다운 태스크 작성
- **task-reviewer** — 태스크 리뷰 및 개선

### Git
- **git-commit** — Conventional Commits + Gitmoji 커밋 메시지 작성
- **git-pull-request** — PR 제목/본문 자동 생성

### Code review
- **fastapi-best-practices** — FastAPI 코드 리뷰 기준
- **react-state-orchestration** — React 상태 관리 패턴

### Meta
- **bootstrap** — 신규 스킬 온보딩 가이드

## Development

로컬 수정분을 테스트할 때 플러그인 디렉토리를 직접 지정:

```bash
claude --plugin-dir ./
```

스킬 수정 후 Claude Code 내에서 `/reload-plugins`로 반영.

## Contributing

내부 저장소입니다. 신규 스킬 추가와 기존 스킬 수정은 반드시 `/skill-creator` 스킬을 사용하고 영어로 작성해주세요.
