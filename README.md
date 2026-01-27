# 데이터마케팅코리아 Agent Skills

AI 에이전트 툴(Claude Code, Gemini CLI 등)을 위한 표준화된 스킬 저장소

## 📋 Table of Contents

- [Overview](#-overview)
- [Directory Structure](#-directory-structure)
- [Quick Start](#-quick-start)
- [Contributing](#-contributing)
- [Documentation](#-documentation)

## 📘 Overview

### 배경

AI 에이전트 툴이 발전함에 따라, 특정 도메인이나 작업에 특화된 절차적 지식(Skill)을 에이전트에게 제공해야 할 필요성이 증가했습니다.

### 해결하려는 문제

- 에이전트 간 스킬 정의 방식의 파편화
- 반복적인 프롬프트 작성의 비효율성
- 조직 내 에이전트 활용 노하우의 공유 부족

### 목표

데이터마케팅코리아의 개발자들이 공통적으로 활용할 수 있는 스킬을 표준화하고 중앙에서 관리합니다.

### 주요 기능

- **표준화된 스킬 정의**: Markdown 기반의 스킬 명세
- **멀티 에이전트 지원**: Claude, Gemini 등 다양한 에이전트 환경 지원 구조
- **스킬 템플릿**: 손쉬운 새 스킬 생성을 위한 템플릿 제공

## 📁 Directory Structure

```text
agent-skills/
├── skills/             # 공용 스킬 소스 (Source of Truth)
│   └── my-new-skill/   # README 작성 스킬
├── template/           # 스킬 생성 템플릿
├── spec/               # 스킬 명세 문서
├── AGENTS.md           # 에이전트 스킬 가이드
└── README.md
```

### 폴더별 상세 설명

| 폴더        | 역할                                  | 주요 파일              |
| :---------- | :------------------------------------ | :--------------------- |
| `skills/`   | 실제 사용 가능한 스킬들이 정의된 폴더 | `SKILL.md`             |
| `template/` | 새로운 스킬을 만들 때 사용하는 템플릿 | `SKILL.md`             |
| `spec/`     | 에이전트 스킬 작성에 대한 기술 명세   | `agent-spec-skills.md` |

## ⚡ Quick Start

### 스킬 추가 방법

새로운 스킬을 추가하려면 다음 절차를 따르십시오.

#### 1. **저장소 클론**

```bash
git clone https://github.com/datamktkorea/agent-skills.git
cd agent-skills
```

#### 2. **스킬 생성**

템플릿을 복사하여 새로운 스킬을 생성합니다.

```bash
mkdir -p skills/my-new-skill
cp template/SKILL.md skills/my-new-skill/SKILL.md
```

#### 3. **스킬 작성**

`skills/my-new-skill/SKILL.md` 파일을 편집하여 스킬의 이름, 설명, 지시사항을 작성합니다.

```markdown
---
name: my-new-skill
description: 이 스킬이 수행하는 작업에 대한 설명
---

# Instructions

여기에 에이전트가 수행해야 할 구체적인 지시사항을 작성합니다.
```

## 🤝 Contributing

새로운 스킬을 제안하거나 기존 스킬을 개선하려면 다음 절차를 따라주세요.

1. `spec/agent-spec-skills.md`를 참고하여 스킬 작성 규칙을 확인합니다.
2. Feature 브랜치를 생성합니다 (`git checkout -b feat/add-new-skill`).
3. 변경사항을 커밋합니다 (`git commit -m 'feat: Add new skill'`).
4. Pull Request를 생성합니다.

## 📚 Documentation

| 링크                                | 설명                       |
| :---------------------------------- | :------------------------- |
| [Vercel Skills](https://skills.sh/) | The Agent Skills Directory |
| [SkillsMP](https://skillsmp.com)    | Agent Skills Marketplace   |
