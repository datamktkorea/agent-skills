# agent-skills

데이터마케팅코리아 팀을 위한 Claude Code 플러그인 및 스킬 저장소

## Structure

```text
agent-skills/
├── .claude-plugin/
│   └── marketplace.json     # 팀 마켓플레이스 진입점
├── dmk-pipeline/                # Pipeline 플러그인
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── skills/
└── skills/                  # 개별 스킬 (미분류)
```

## Installation

### 1. 마켓플레이스 등록

Claude Code에서 외부 도구를 사용하기 위해 **팀 프로젝트 루트 디렉토리**에서 다음 설정을 진행합니다.

#### **Step 1: 설정 디렉토리 생성**

먼저 프로젝트 루트에 `.claude` 디렉토리가 있는지 확인하고, 없으면 생성합니다.

```bash
mkdir -p .claude
```

#### **Step 2: settings.json 설정**

`.claude/settings.json` 파일을 생성하거나 기존 파일에 아래 내용을 추가합니다. 이 설정을 통해 `datamktkorea`의 에이전트 스킬을 마켓플레이스로 등록할 수 있습니다.

**파일명:** `.claude/settings.json`

```json
{
  "extraKnownMarketplaces": {
    "datamktkorea-tools": {
      "source": {
        "source": "github",
        "repo": "datamktkorea/agent-skills"
      }
    }
  }
}
```

> [!TIP]
> 설정을 마친 후 해당 디렉토리에서 **Claude Code**를 실행하면 마켓플레이스가 자동으로 인식되어 등록된 도구들을 사용할 수 있습니다.

### 2. 플러그인 설치

```shell
/plugin install dmk-pipeline
```
