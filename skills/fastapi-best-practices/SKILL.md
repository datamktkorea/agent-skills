---
name: fastapi-best-practices
description: A skill for following best practices when developing FastAPI applications. It covers guidelines for project structure, code organization, and common patterns to ensure maintainable and scalable FastAPI projects.
---

Use this skill when you are developing a FastAPI application and want to ensure that you are following best practices for project structure, code organization, and common patterns. This skill can help you create maintainable and scalable FastAPI projects by providing guidelines and recommendations.

# Skill: FastAPI DDD & Hexagonal Architecture Standard Guide

이 가이드는 FastAPI 프레임워크 기반 프로젝트에서 도메인 주도 설계(DDD) 및 헥사고날 아키텍처(Hexagonal Architecture)를 일관성 있게 적용하기 위한 표준 가이드라인을 제공합니다.

## 0. 프로젝트 구조 (Standard Project Structure)

```text
app/
├── main.py
├── settings.py                 # pydantic-settings 기반 환경 설정
├── libs/                       # [SHARED] 공통 의존성 (DI Container, Global Exceptions)
│   ├── containers.py           # Dependency Injection (dependency-injector) 설정
│   └── exceptions.py           # 전역 예외 및 에러 핸들러
└── routes/                     # [DOMAINS] 도메인 기반 API 라우트
    └── {domain_name}/          # 개별 도메인 단위 (예: users, orders, products)
        ├── interface/          # [IN] Entry Points (Controller, Request/Response Schema)
        │   ├── controller.py
        │   ├── schema.py
        │   └── dependencies.py # FastAPI Depends 팩토리 함수 (Native DI 방식 사용 시)
        ├── application/        # [CORE] Use-Cases & Orchestration
        │   ├── service.py
        │   └── core/           # 순수 비즈니스 로직 분리 (계산, 분석 등)
        ├── domain/             # [RULES] Pure Business Rules & Interfaces
        │   ├── entity.py       # 엔티티 및 값 객체 정의
        │   ├── exceptions.py   # 도메인 예외 클래스
        │   └── repository.py   # Repository 인터페이스 (ABC)
        └── infra/              # [OUT] Technical Implementation
            ├── models.py       # ORM 모델 (SQLAlchemy 등)
            └── repository.py   # Repository 구현체
packages/                       # [EXTERNAL] 재사용 가능한 공통 패키지 (DB, Auth, 외부 서비스 래퍼)
├── database/                   # DB 연결 및 기초 연동
├── auth/                       # 인증/인가 공통 모듈
└── {service_name}/             # 외부 서비스 래퍼 (예: aws/, email/, sms/)
tests/
└── {domain_name}/
    ├── unit/                   # Application 계층 단위 테스트
    └── integration/            # Infrastructure 계층 통합 테스트
```

## 1. 아키텍처 원칙 (Architecture Principles)

### 의존성 규칙 (Dependency Rule)

- 모든 의존성은 외부에서 내부(고수준 정책)로 흘러야 합니다.
- **Infrastructure**는 **Domain**의 인터페이스를 구현하며, 직접적인 상위 레이어 참조를 금지합니다.
- **Application**은 비즈니스 규칙을 조합하여 유스케이스를 완성하며, 프레임워크 종속성을 최소화합니다.

### 포트와 어댑터 (Ports & Adapters)

헥사고날 아키텍처의 핵심은 애플리케이션 코어를 외부 기술로부터 격리하는 것입니다.

| 구분                           | 역할                    | 해당 계층                    |
| ------------------------------ | ----------------------- | ---------------------------- |
| **Driving Adapter** (Primary)  | 외부에서 앱을 호출      | `interface/controller.py`    |
| **Port** (Interface)           | 어댑터가 따라야 할 규격 | `domain/repository.py` (ABC) |
| **Driven Adapter** (Secondary) | 앱이 외부 시스템을 호출 | `infra/repository.py`        |

```
[HTTP Client] → [Controller] → [Service] → [Repository ABC] ← [Repository Impl] → [DB]
   (Driving)     (Adapter)     (Core)         (Port)              (Driven Adapter)
```

### 도메인 순수성 원칙 (Domain Purity)

- `domain/` 계층은 **어떤 프레임워크도 import해서는 안 됩니다.** FastAPI, SQLAlchemy, Pydantic 모두 금지.
- 순수 Python 타입(`dataclass`, `str`, `int`, `Optional` 등)만 사용합니다.
- `application/` 계층 역시 `HTTPException` 등 HTTP 개념을 포함해서는 안 됩니다. 대신 도메인 예외를 raise하고, 변환은 `interface/` 또는 전역 핸들러가 담당합니다.

### 의존성 주입 방식 선택 (DI Strategy)

프로젝트 규모와 팀 선호에 따라 두 가지 방식 중 하나를 선택합니다. **방식은 프로젝트 시작 시 하나로 통일**하며, 혼용하지 않습니다.

|                 | dependency-injector                       | FastAPI Native DI                                          |
| --------------- | ----------------------------------------- | ---------------------------------------------------------- |
| **적합한 규모** | 중대형 (도메인 5개 이상)                  | 소형 (도메인 3개 이하)                                     |
| **장점**        | 중앙 집중식 배선, 컨테이너 단위 Mock 교체 | 외부 라이브러리 없음, Python 타입 시스템과 자연스러운 통합 |
| **단점**        | `@inject` + `Provide[...]` 보일러플레이트 | 의존성 그래프가 복잡해지면 팩토리 함수 분산                |

#### dependency-injector 방식 (중대형 프로젝트)

```python
# libs/containers.py — 의존성 관계를 한 파일에서 중앙 관리
from dependency_injector import containers, providers

class Container(containers.DeclarativeContainer):
    wiring_config = containers.WiringConfiguration(packages=["app.routes"])

    resource_repo = providers.Factory(ResourceRepositoryImpl)
    resource_service = providers.Factory(ResourceService, repo=resource_repo)

# interface/controller.py
from dependency_injector.wiring import Provide, inject

@router.get("/{resource_id}")
@inject
async def get_resource(
    resource_id: str,
    service: ResourceService = Depends(Provide[Container.resource_service]),
):
    return await service.get_resource(resource_id)
```

#### FastAPI Native DI 방식 (소형 프로젝트)

팩토리 함수는 반드시 `interface/dependencies.py`에 모읍니다. `application/`이나 `domain/` 계층이 FastAPI의 `Depends`에 오염되는 것을 방지합니다.

```python
# interface/dependencies.py — FastAPI Depends 팩토리만 모아두는 파일
from fastapi import Depends
from typing import Annotated

def get_resource_repo() -> ResourceRepository:
    return ResourceRepositoryImpl()

def get_resource_service(
    repo: Annotated[ResourceRepository, Depends(get_resource_repo)],
) -> ResourceService:
    return ResourceService(repo=repo)

# interface/controller.py — 팩토리 함수는 dependencies.py에서 import
from .dependencies import get_resource_service

@router.get("/{resource_id}")
async def get_resource(
    resource_id: str,
    service: Annotated[ResourceService, Depends(get_resource_service)],
):
    return await service.get_resource(resource_id)
```

## 2. 계층별 역할 및 코드 컨벤션 (Code Convention)

### 📂 Interface Layer (`controller.py`, `schema.py`)

- **Controller**: FastAPI `APIRouter`를 정의하며, `@inject`를 통해 필요한 서비스를 주입받습니다. 예외 변환은 전역 핸들러에 위임하고, **컨트롤러는 성공 케이스에만 집중합니다.**
- **Schema**: Pydantic v2를 사용하여 API 규격을 정의합니다. `Field(description=...)`을 통해 API 문서를 자동화합니다. **Request와 Response 스키마는 반드시 분리합니다.**

```python
# schema.py — Request / Response 분리
class CreateResourceRequest(BaseModel):
    name: str = Field(..., description="리소스 이름")

class ResourceResponse(BaseModel):
    id: str
    name: str

# controller.py — 전역 핸들러 표준 사용 시, 성공 케이스에만 집중
@router.get("/{resource_id}", status_code=200, response_model=ResourceResponse)
@inject
async def get_resource(
    resource_id: str,
    service: ResourceService = Depends(Provide[Container.resource_service]),
):
    return await service.get_resource(resource_id)
    # ResourceNotFoundException → libs/exceptions.py 전역 핸들러가 자동으로 404 반환
```

> **표준 권장**: `libs/exceptions.py`에 전역 핸들러를 등록하여 예외 변환 로직을 한 곳에서 관리합니다. 동일 예외에 대해 엔드포인트마다 다른 응답이 필요한 예외적인 경우에 한해 컨트롤러 수준의 try/except를 허용합니다. (Section 3 참고)

### 📂 Application Layer (`service.py`)

- **Service**: 비즈니스 유스케이스를 구현합니다. Repository 인터페이스를 생성자로 주입받으며, **HTTP 개념(`HTTPException` 등)을 포함하지 않습니다.**
- 비즈니스 규칙 위반 시 `domain/exceptions.py`에 정의된 도메인 예외를 raise합니다.
- **Separation**: 복잡한 계산이나 분석 로직은 `core/` 디렉토리의 순수 클래스로 분리하여 테스트 용이성을 확보합니다.

```python
# application/service.py
class ResourceService:
    def __init__(self, repo: ResourceRepository):  # 인터페이스 타입으로 주입
        self._repo = repo

    async def get_resource(self, resource_id: str) -> ResourceEntity:
        entity = await self._repo.find_by_id(resource_id)
        if entity is None:
            raise ResourceNotFoundException(resource_id)  # 도메인 예외, HTTPException 아님
        return entity

    async def create_resource(self, name: str) -> ResourceEntity:
        entity = ResourceEntity(id=str(uuid4()), name=name)
        return await self._repo.save(entity)
```

### 📂 Domain Layer (`entity.py`, `exceptions.py`, `repository.py`)

- **Entity**: 고유 식별자(`id`)를 가지며 가변적인 객체입니다.
- **Value Object**: 식별자 없이 속성 값 자체가 동일성을 정의하는 불변 객체입니다. `@dataclass(frozen=True)`로 불변성을 강제합니다.
- **Repository Interface**: `ABC`를 사용하여 저장소 규격을 정의합니다. DB 종류(SQL, NoSQL, S3 등)에 구애받지 않아야 합니다.
- **Domain Exceptions**: HTTP 상태 코드와 무관한 순수 비즈니스 예외를 정의합니다.

```python
# domain/entity.py
from dataclasses import dataclass

@dataclass
class ResourceEntity:
    id: str
    name: str
    email: str

@dataclass(frozen=True)  # Value Object — 불변, 동등성은 값으로 판단
class Email:
    value: str

    def __post_init__(self):
        if "@" not in self.value:
            raise ValueError(f"Invalid email: {self.value}")
```

```python
# domain/exceptions.py — HTTP 개념 없이 순수 비즈니스 예외만 정의
class ResourceNotFoundException(Exception):
    def __init__(self, resource_id: str):
        self.resource_id = resource_id
        super().__init__(f"Resource '{resource_id}' not found")

class DuplicateResourceException(Exception):
    def __init__(self, name: str):
        self.name = name
        super().__init__(f"Resource '{name}' already exists")
```

```python
# domain/repository.py
from abc import ABC, abstractmethod

class ResourceRepository(ABC):
    @abstractmethod
    async def find_by_id(self, id: str) -> Optional[ResourceEntity]:
        pass

    @abstractmethod
    async def save(self, entity: ResourceEntity) -> ResourceEntity:
        pass
```

### 📂 Infrastructure Layer (`models.py`, `repository.py` - Implementation)

- **ORM Model**: `models.py`에 SQLAlchemy 등 ORM 모델을 정의합니다. Domain Entity와 분리된 별도 클래스입니다.
- **Mapping**: Repository 구현체가 ORM Model ↔ Domain Entity 변환을 전담합니다. 이 매핑 로직이 Infrastructure 계층의 핵심 책임입니다.

```python
# infra/models.py — ORM 모델 (프레임워크 종속)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

class Base(DeclarativeBase):
    pass

class ResourceModel(Base):
    __tablename__ = "resources"
    id: Mapped[str] = mapped_column(primary_key=True)
    name: Mapped[str]
    email: Mapped[str]
```

```python
# infra/repository.py — 도메인 인터페이스 구현 + ORM ↔ Entity 매핑
from sqlalchemy.ext.asyncio import AsyncSession

class ResourceRepositoryImpl(ResourceRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    async def find_by_id(self, id: str) -> Optional[ResourceEntity]:
        row = await self._session.get(ResourceModel, id)
        if row is None:
            return None
        return self._to_entity(row)  # ORM → Domain 변환

    async def save(self, entity: ResourceEntity) -> ResourceEntity:
        model = self._to_model(entity)  # Domain → ORM 변환
        self._session.add(model)
        await self._session.flush()
        return entity

    def _to_entity(self, row: ResourceModel) -> ResourceEntity:
        return ResourceEntity(id=row.id, name=row.name, email=row.email)

    def _to_model(self, entity: ResourceEntity) -> ResourceModel:
        return ResourceModel(id=entity.id, name=entity.name, email=entity.email)
```

> **Pragmatic DDD Trade-off**: Entity ↔ ORM Model ↔ Pydantic Schema 사이의 3중 변환은 필드가 많아질수록 유지보수 부담(매핑 세금)이 커집니다. 비즈니스 로직이 단순하거나 팀 규모가 작은 경우, Domain Entity로 Pydantic `BaseModel`을 사용하여 변환 계층을 줄이는 실용적 접근법도 선택지입니다. 단, 이 경우 Domain 계층이 Pydantic에 종속되므로 팀이 명시적으로 합의하고 일관성 있게 적용해야 합니다.
>
> 이 접근법을 선택했다면 `model_config = ConfigDict(from_attributes=True)`를 설정하세요. ORM 객체의 속성을 직접 읽어 `_to_entity` 변환 메서드가 한 줄로 축약됩니다.
>
> ```python
> # domain/entity.py — Pragmatic DDD: Pydantic BaseModel 사용
> from pydantic import BaseModel, ConfigDict
>
> class ResourceEntity(BaseModel):
>     model_config = ConfigDict(from_attributes=True)  # ORM 객체 속성 직접 읽기
>     id: str
>     name: str
>     email: str
>
> # infra/repository.py — _to_entity 메서드가 한 줄로 축약
> async def find_by_id(self, id: str) -> Optional[ResourceEntity]:
>     row = await self._session.get(ResourceModel, id)
>     if row is None:
>         return None
>     return ResourceEntity.model_validate(row)  # ← 수동 매핑 불필요
> ```

## 3. 핵심 실무 가이드 (Best Practices)

### 🛠 에러 처리 전략 (Error Handling)

계층별 예외 책임을 명확히 분리합니다.

1. **Infrastructure**: DB/외부 API 예외를 도메인 예외로 래핑하거나 `None`을 반환합니다.
2. **Domain**: 비즈니스 규칙 위반 시 `domain/exceptions.py`의 순수 예외를 raise합니다.
3. **Application**: 도메인 예외를 그대로 전파합니다. `HTTPException`을 직접 raise하지 않습니다.
4. **Interface**: 도메인 예외를 catch하여 `HTTPException`으로 변환합니다.

전역 핸들러를 활용하면 컨트롤러 코드를 간결하게 유지할 수 있습니다.

```python
# libs/exceptions.py — 전역 예외 핸들러 등록
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(ResourceNotFoundException)
    async def not_found_handler(request: Request, exc: ResourceNotFoundException):
        return JSONResponse(status_code=404, content={"detail": str(exc)})

    @app.exception_handler(DuplicateResourceException)
    async def conflict_handler(request: Request, exc: DuplicateResourceException):
        return JSONResponse(status_code=409, content={"detail": str(exc)})
```

### 🧪 테스트 전략 (Testing Pyramid)

- **Unit Test**: `Application` 계층의 서비스 로직을 테스트합니다. Repository는 `AsyncMock`으로 고립시킵니다.
- **Integration Test**: `Infrastructure` 계층과 실제 DB를 연결하여 Repository 구현체를 검증합니다. `testcontainers`를 사용하면 실제 PostgreSQL 컨테이너를 테스트 중 자동으로 띄울 수 있어, Mock을 작성하는 비용보다 저렴하게 높은 신뢰도를 확보할 수 있습니다.
- **End-to-End (E2E)**: `httpx.AsyncClient`를 사용하여 실제 API 호출부터 응답까지의 흐름을 검증합니다. (비동기 엔드포인트에는 `TestClient` 대신 `AsyncClient` 사용)

```python
# tests/unit/test_resource_service.py
import pytest
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_get_resource_not_found():
    mock_repo = AsyncMock(spec=ResourceRepository)
    mock_repo.find_by_id.return_value = None  # AsyncMock은 await 가능

    service = ResourceService(repo=mock_repo)

    with pytest.raises(ResourceNotFoundException):
        await service.get_resource("non-existent-id")
```

```python
# tests/integration/test_resource_repository.py — Testcontainers 활용
import pytest
from testcontainers.postgres import PostgresContainer
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession

@pytest.fixture(scope="session")
def postgres():
    with PostgresContainer("postgres:16") as pg:
        yield pg

@pytest.mark.asyncio
async def test_find_by_id_returns_none_when_not_found(postgres):
    engine = create_async_engine(postgres.get_connection_url())
    async with AsyncSession(engine) as session:
        repo = ResourceRepositoryImpl(session)
        result = await repo.find_by_id("non-existent")
        assert result is None
```

### ⚡ 성능 및 캐싱 (Caching Pattern)

- **Cache-Aside 패턴**: 데이터 조회 시 캐시 저장소(Redis 등)를 먼저 확인하고, 없을 경우에만 DB를 조회한 뒤 캐시를 갱신합니다.
- **Side-Effect**: 데이터 변경(`CUD`)이 발생할 경우 반드시 관련 캐시를 무효화(Invalidate)해야 합니다.

### 📝 로깅 규칙 (Observability)

- **Contextual Logging**: 로그 메시지에 `request_id`, `user_id` 등의 컨텍스트를 포함하여 추적성을 높입니다.
- **Log Levels**: 주요 흐름은 `INFO`, 비정상적이나 복구 가능한 상황은 `WARNING`, 장애 추적은 `ERROR`, 상세 데이터 디버깅은 `DEBUG` 레벨을 엄격히 준수합니다.
- **민감 데이터 마스킹**: 비밀번호, 토큰, 개인정보(이메일, 전화번호 등)는 절대 로그에 포함하지 않습니다.

## 4. 설정 관리 (Configuration Management)

`pydantic-settings`를 사용하여 환경 변수를 타입 안전하게 관리합니다. `.env` 파일과 환경 변수를 동시에 지원합니다.

```python
# settings.py
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str
    redis_url: str
    secret_key: str
    debug: bool = False

settings = Settings()
```

- `settings` 인스턴스는 모듈 수준에서 싱글턴으로 생성합니다.
- DI Container(`containers.py`)에서 `settings`를 참조하여 인프라 컴포넌트를 초기화합니다.
- 테스트 환경에서는 `.env.test` 파일 또는 환경 변수 오버라이드로 설정을 분리합니다.

## 5. 데이터베이스 세션 관리 (DB Session Management)

트랜잭션 경계를 어디서 관리할지에 대한 두 가지 접근법이 있습니다.

### 방법 A — 세션 직접 전달 (Session-per-Request)

FastAPI의 `Depends`로 세션을 생성하고, Controller → Service → Repository로 인자를 통해 전달합니다.
구조가 단순하고 직관적이며, FastAPI 생태계에서 가장 일반적인 패턴입니다.

> ⚠️ **아키텍처 트레이드오프**: `AsyncSession`을 Service까지 직접 전달하면 Application 계층이 SQLAlchemy에 종속됩니다. 헥사고날 원칙을 엄격히 준수해야 하는 프로젝트라면 방법 B(UoW 패턴)를 선택하세요.

```python
# packages/database/session.py
async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        async with session.begin():
            yield session

# interface/controller.py
@router.post("/", status_code=201)
@inject
async def create_resource(
    body: CreateResourceRequest,
    service: ResourceService = Depends(Provide[Container.resource_service]),
    db: AsyncSession = Depends(get_session),  # 요청당 세션 생성
):
    return await service.create_resource(db=db, name=body.name)
```

### 방법 B — Unit of Work 패턴

트랜잭션 경계를 명시적인 `UnitOfWork` 객체로 캡슐화합니다.
여러 Repository에 걸친 복잡한 트랜잭션을 일관되게 관리할 때 유리합니다.

```python
# domain/unit_of_work.py — 추상 인터페이스 (Domain 계층, SQLAlchemy 미포함)
class AbstractUnitOfWork(ABC):
    resources: ResourceRepository

    @abstractmethod
    async def commit(self): pass

    @abstractmethod
    async def rollback(self): pass

    async def __aenter__(self): return self
    async def __aexit__(self, *args): await self.rollback()

# infra/unit_of_work.py — 구현체 (Infrastructure 계층)
class SqlAlchemyUnitOfWork(AbstractUnitOfWork):
    def __init__(self, session_factory):
        self._session_factory = session_factory

    async def __aenter__(self):
        self._session = self._session_factory()
        self.resources = ResourceRepositoryImpl(self._session)
        return self

    async def commit(self):
        await self._session.commit()

    async def rollback(self):
        await self._session.rollback()

    async def __aexit__(self, *args):
        await super().__aexit__(*args)
        await self._session.close()

# application/service.py — Application은 AbstractUnitOfWork만 의존, SQLAlchemy 미포함
class ResourceService:
    def __init__(self, uow: AbstractUnitOfWork):
        self._uow = uow

    async def create_resource(self, name: str) -> ResourceEntity:
        async with self._uow:
            entity = ResourceEntity(id=str(uuid4()), name=name)
            await self._uow.resources.save(entity)
            await self._uow.commit()
            return entity
```

> **선택 기준**: 단일 도메인 내 단순 CRUD는 **방법 A**, 여러 Aggregate에 걸친 트랜잭션이 빈번하면 **방법 B**를 선택합니다.
