from __future__ import annotations

from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .launch_api import _ensure_shadow_user, init_launch_db
from .main import connect, decode_json, encode_json, make_id, now_iso

router = APIRouter(prefix="/v2/front-office", tags=["front-office"])

SourceStatus = Literal["modeled", "uploaded", "verified"]
RecordStatus = Literal["active", "inactive", "superseded", "archived"]


class ContractYear(BaseModel):
    season: str
    salary: float = Field(ge=0)
    guaranteed_amount: float = Field(default=0, ge=0)
    likely_incentives: float = Field(default=0, ge=0)
    unlikely_incentives: float = Field(default=0, ge=0)
    dead_money: float = Field(default=0, ge=0)
    option_type: str = "none"
    option_deadline: str = ""
    guarantee_date: str = ""
    cap_charge_override: float | None = Field(default=None, ge=0)

    @property
    def cap_charge(self) -> float:
        if self.cap_charge_override is not None:
            return self.cap_charge_override
        return self.salary + self.likely_incentives + self.dead_money


class PlayerContractRecord(BaseModel):
    id: str = ""
    player_id: str
    player_name: str
    team_id: str
    season: str
    contract_type: str = "standard"
    years: list[ContractYear] = Field(default_factory=list)
    no_trade_clause: bool = False
    trade_bonus_percent: float = Field(default=0, ge=0, le=100)
    bird_rights: str = "unknown"
    two_way: bool = False
    source_status: SourceStatus = "modeled"
    source_label: str = ""
    source_url: str = ""
    source_document_id: str = ""
    as_of_date: str = ""
    notes: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class ExceptionBalance(BaseModel):
    name: str
    amount: float = Field(ge=0)
    expires_on: str = ""
    hard_cap_trigger: str = ""
    notes: str = ""


class TeamFinancialPositionRecord(BaseModel):
    id: str = ""
    team_id: str
    season: str
    salary_cap: float = Field(ge=0)
    luxury_tax: float = Field(ge=0)
    first_apron: float = Field(ge=0)
    second_apron: float = Field(ge=0)
    active_salary: float = Field(default=0, ge=0)
    cap_holds: float = Field(default=0, ge=0)
    dead_money: float = Field(default=0, ge=0)
    incomplete_roster_charges: float = Field(default=0, ge=0)
    hard_cap: float = Field(default=0, ge=0)
    cash_sent: float = Field(default=0, ge=0)
    cash_received: float = Field(default=0, ge=0)
    exceptions: list[ExceptionBalance] = Field(default_factory=list)
    source_status: SourceStatus = "modeled"
    source_label: str = ""
    source_url: str = ""
    source_document_id: str = ""
    as_of_date: str = ""
    notes: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class DraftProtection(BaseModel):
    year: int
    condition: str
    fallback: str = ""


class DraftAssetRecord(BaseModel):
    id: str = ""
    current_team_id: str
    original_team_id: str
    draft_year: int = Field(ge=2020, le=2045)
    round: int = Field(ge=1, le=2)
    asset_type: str = "pick"
    description: str = ""
    protections: list[DraftProtection] = Field(default_factory=list)
    swap_terms: str = ""
    conveyance_chain: list[str] = Field(default_factory=list)
    encumbered: bool = False
    stepien_eligible: bool = True
    source_status: SourceStatus = "modeled"
    source_label: str = ""
    source_url: str = ""
    source_document_id: str = ""
    as_of_date: str = ""
    notes: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class SalaryMovement(BaseModel):
    team_id: str
    player_id: str = ""
    label: str
    direction: Literal["incoming", "outgoing", "retained", "waived"]
    amount: float = Field(ge=0)
    season: str = ""


class TransactionLedgerRecord(BaseModel):
    id: str = ""
    organization_id: str = ""
    case_id: str = ""
    season: str
    transaction_type: str
    effective_date: str = ""
    status: str = "modeled"
    teams: list[str] = Field(default_factory=list)
    summary: str
    contract_ids: list[str] = Field(default_factory=list)
    draft_asset_ids: list[str] = Field(default_factory=list)
    salary_movements: list[SalaryMovement] = Field(default_factory=list)
    assumptions: list[str] = Field(default_factory=list)
    approvals: list[dict[str, Any]] = Field(default_factory=list)
    source_status: SourceStatus = "modeled"
    source_label: str = ""
    source_url: str = ""
    source_document_id: str = ""
    as_of_date: str = ""
    notes: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)


class RecordUpsert(BaseModel):
    actor_user_id: str
    record: dict[str, Any]
    record_status: RecordStatus = "active"


class LedgerEventCreate(BaseModel):
    actor_user_id: str
    event_type: str
    message: str
    payload: dict[str, Any] = Field(default_factory=dict)


def init_front_office_db() -> None:
    init_launch_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS front_office_records (
              id TEXT PRIMARY KEY,
              record_type TEXT NOT NULL,
              season TEXT NOT NULL,
              team_id TEXT,
              player_id TEXT,
              organization_id TEXT,
              source_status TEXT NOT NULL DEFAULT 'modeled',
              record_status TEXT NOT NULL DEFAULT 'active',
              payload_json TEXT NOT NULL,
              validation_json TEXT NOT NULL DEFAULT '{}',
              version INTEGER NOT NULL DEFAULT 1,
              created_by_user_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS front_office_record_versions (
              id TEXT PRIMARY KEY,
              record_id TEXT NOT NULL REFERENCES front_office_records(id) ON DELETE CASCADE,
              record_type TEXT NOT NULL,
              version INTEGER NOT NULL,
              actor_user_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              validation_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS transaction_ledger_events (
              id TEXT PRIMARY KEY,
              ledger_id TEXT NOT NULL REFERENCES front_office_records(id) ON DELETE CASCADE,
              actor_user_id TEXT NOT NULL,
              event_type TEXT NOT NULL,
              message TEXT NOT NULL,
              payload_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_front_office_type_season
              ON front_office_records(record_type, season, record_status, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_front_office_team
              ON front_office_records(team_id, season, record_type, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_front_office_player
              ON front_office_records(player_id, season, record_type, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_front_office_org
              ON front_office_records(organization_id, record_type, updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_front_office_versions
              ON front_office_record_versions(record_id, version DESC);
            CREATE INDEX IF NOT EXISTS idx_ledger_events
              ON transaction_ledger_events(ledger_id, created_at DESC);
            """
        )
        connection.commit()


def _source_validation(record: BaseModel) -> list[str]:
    source_status = str(getattr(record, "source_status", "modeled"))
    if source_status != "verified":
        return []
    source_label = str(getattr(record, "source_label", "")).strip()
    source_url = str(getattr(record, "source_url", "")).strip()
    source_document_id = str(getattr(record, "source_document_id", "")).strip()
    if not source_label:
        return ["Verified records require a source label."]
    if not source_url and not source_document_id:
        return ["Verified records require a source URL or source document ID."]
    return []


def _validate_contract(record: PlayerContractRecord) -> dict[str, Any]:
    errors = _source_validation(record)
    warnings: list[str] = []
    seasons = [year.season for year in record.years]
    if not record.years:
        errors.append("A contract must include at least one contract year.")
    if len(seasons) != len(set(seasons)):
        errors.append("Contract years must use unique seasons.")
    for year in record.years:
        if year.guaranteed_amount > year.salary:
            errors.append(f"{year.season}: guaranteed amount exceeds salary.")
        if year.option_type not in {"none", "player", "team", "early_termination", "qualifying_offer", "two_way"}:
            warnings.append(f"{year.season}: option type is not a recognized launch value.")
    if record.season and record.season not in seasons:
        warnings.append("The record season is not present in the contract-year schedule.")
    return _validation(errors, warnings)


def _validate_position(record: TeamFinancialPositionRecord) -> dict[str, Any]:
    errors = _source_validation(record)
    warnings: list[str] = []
    if not (record.salary_cap <= record.luxury_tax <= record.first_apron <= record.second_apron):
        errors.append("Cap, tax, first-apron and second-apron thresholds must be monotonic.")
    calculated = record.active_salary + record.cap_holds + record.dead_money + record.incomplete_roster_charges
    if abs(calculated - record.active_salary) < 0.01 and not record.exceptions:
        warnings.append("No cap holds, dead money, roster charges or exceptions are recorded.")
    if record.hard_cap and record.hard_cap < record.salary_cap:
        errors.append("A hard cap cannot be below the salary cap.")
    return _validation(errors, warnings, {"modeled_team_salary": calculated})


def _validate_draft_asset(record: DraftAssetRecord) -> dict[str, Any]:
    errors = _source_validation(record)
    warnings: list[str] = []
    if record.asset_type not in {"pick", "swap", "conditional", "second_round_pool"}:
        warnings.append("Draft asset type is outside the recognized launch values.")
    protection_years = [item.year for item in record.protections]
    if protection_years != sorted(protection_years):
        errors.append("Protection years must be in ascending order.")
    if len(protection_years) != len(set(protection_years)):
        errors.append("Protection years must be unique.")
    if record.encumbered and record.stepien_eligible:
        warnings.append("An encumbered first-round asset should be rechecked before treating it as Stepien-eligible.")
    return _validation(errors, warnings)


def _validate_ledger(record: TransactionLedgerRecord) -> dict[str, Any]:
    errors = _source_validation(record)
    warnings: list[str] = []
    if not record.teams:
        errors.append("A ledger transaction must include at least one team.")
    if len(record.teams) != len(set(record.teams)):
        errors.append("Ledger teams must be unique.")
    if not record.summary.strip():
        errors.append("A ledger transaction requires a summary.")
    if not record.effective_date:
        warnings.append("Effective date is missing; timing restrictions cannot be finalized.")
    if record.status == "approved" and record.source_status != "verified":
        warnings.append("An approved transaction is not backed by verified source status.")
    totals: dict[str, dict[str, float]] = {}
    for movement in record.salary_movements:
        team = totals.setdefault(movement.team_id, {"incoming": 0.0, "outgoing": 0.0, "retained": 0.0, "waived": 0.0})
        team[movement.direction] += movement.amount
    return _validation(errors, warnings, {"salary_totals": totals})


def _validation(errors: list[str], warnings: list[str], computed: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "status": "fail" if errors else ("warning" if warnings else "pass"),
        "errors": errors,
        "warnings": warnings,
        "computed": computed or {},
    }


def _parse(record_type: str, payload: dict[str, Any]) -> BaseModel:
    try:
        if record_type == "contract":
            return PlayerContractRecord(**payload)
        if record_type == "team_position":
            return TeamFinancialPositionRecord(**payload)
        if record_type == "draft_asset":
            return DraftAssetRecord(**payload)
        if record_type == "ledger":
            return TransactionLedgerRecord(**payload)
    except Exception as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    raise HTTPException(status_code=400, detail=f"Unsupported front-office record type: {record_type}")


def _validate(record_type: str, record: BaseModel) -> dict[str, Any]:
    if record_type == "contract":
        return _validate_contract(record)  # type: ignore[arg-type]
    if record_type == "team_position":
        return _validate_position(record)  # type: ignore[arg-type]
    if record_type == "draft_asset":
        return _validate_draft_asset(record)  # type: ignore[arg-type]
    return _validate_ledger(record)  # type: ignore[arg-type]


def _record_dimensions(record_type: str, record: BaseModel) -> tuple[str, str, str, str]:
    payload = record.model_dump()
    season = str(payload.get("season") or "")
    if not season:
        raise HTTPException(status_code=422, detail="A season is required")
    team_id = str(payload.get("team_id") or payload.get("current_team_id") or "")
    player_id = str(payload.get("player_id") or "")
    organization_id = str(payload.get("organization_id") or "")
    if record_type == "ledger" and not team_id:
        teams = payload.get("teams") or []
        team_id = str(teams[0]) if teams else ""
    return season, team_id, player_id, organization_id


def _serialize(row: Any) -> dict[str, Any]:
    payload = decode_json(row["payload_json"], {})
    payload["id"] = row["id"]
    return {
        "id": row["id"],
        "record_type": row["record_type"],
        "season": row["season"],
        "team_id": row["team_id"] or "",
        "player_id": row["player_id"] or "",
        "organization_id": row["organization_id"] or "",
        "source_status": row["source_status"],
        "record_status": row["record_status"],
        "record": payload,
        "validation": decode_json(row["validation_json"], {}),
        "version": row["version"],
        "created_by_user_id": row["created_by_user_id"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def upsert_front_office_record(record_type: str, record_id: str, payload: RecordUpsert) -> dict[str, Any]:
    init_front_office_db()
    parsed = _parse(record_type, {**payload.record, "id": record_id})
    validation = _validate(record_type, parsed)
    season, team_id, player_id, organization_id = _record_dimensions(record_type, parsed)
    timestamp = now_iso()
    clean_payload = parsed.model_dump()
    clean_payload["id"] = record_id
    source_status = str(clean_payload.get("source_status") or "modeled")
    with connect() as connection:
        _ensure_shadow_user(connection, payload.actor_user_id, payload.actor_user_id, "analyst")
        existing = connection.execute("SELECT version, created_at, created_by_user_id FROM front_office_records WHERE id = ?", (record_id,)).fetchone()
        version = 1 if existing is None else int(existing["version"]) + 1
        created_at = timestamp if existing is None else existing["created_at"]
        created_by = payload.actor_user_id if existing is None else existing["created_by_user_id"]
        connection.execute(
            """
            INSERT INTO front_office_records (
              id, record_type, season, team_id, player_id, organization_id,
              source_status, record_status, payload_json, validation_json,
              version, created_by_user_id, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET record_type = excluded.record_type,
              season = excluded.season, team_id = excluded.team_id,
              player_id = excluded.player_id, organization_id = excluded.organization_id,
              source_status = excluded.source_status, record_status = excluded.record_status,
              payload_json = excluded.payload_json, validation_json = excluded.validation_json,
              version = excluded.version, updated_at = excluded.updated_at
            """,
            (
                record_id,
                record_type,
                season,
                team_id or None,
                player_id or None,
                organization_id or None,
                source_status,
                payload.record_status,
                encode_json(clean_payload),
                encode_json(validation),
                version,
                created_by,
                created_at,
                timestamp,
            ),
        )
        connection.execute(
            "INSERT INTO front_office_record_versions (id, record_id, record_type, version, actor_user_id, payload_json, validation_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (f"{record_id}:v{version}", record_id, record_type, version, payload.actor_user_id, encode_json(clean_payload), encode_json(validation), timestamp),
        )
        connection.execute(
            """
            DELETE FROM front_office_record_versions
            WHERE record_id = ? AND version NOT IN (
              SELECT version FROM front_office_record_versions
              WHERE record_id = ? ORDER BY version DESC LIMIT 100
            )
            """,
            (record_id, record_id),
        )
        connection.commit()
        row = connection.execute("SELECT * FROM front_office_records WHERE id = ?", (record_id,)).fetchone()
        assert row is not None
        return _serialize(row)


def list_front_office_records(
    record_type: str,
    season: str = "",
    team_id: str = "",
    player_id: str = "",
    organization_id: str = "",
    source_status: str = "",
    record_status: str = "active",
    limit: int = 250,
) -> list[dict[str, Any]]:
    init_front_office_db()
    clauses = ["record_type = ?"]
    values: list[Any] = [record_type]
    for column, value in (
        ("season", season),
        ("team_id", team_id),
        ("player_id", player_id),
        ("organization_id", organization_id),
        ("source_status", source_status),
        ("record_status", record_status),
    ):
        if value:
            clauses.append(f"{column} = ?")
            values.append(value)
    values.append(max(1, min(limit, 1000)))
    with connect() as connection:
        rows = connection.execute(
            f"SELECT * FROM front_office_records WHERE {' AND '.join(clauses)} ORDER BY updated_at DESC LIMIT ?",
            values,
        ).fetchall()
        return [_serialize(row) for row in rows]


def front_office_reconciliation(team_id: str, season: str) -> dict[str, Any]:
    contracts = list_front_office_records("contract", season=season, team_id=team_id, limit=1000)
    positions = list_front_office_records("team_position", season=season, team_id=team_id, limit=10)
    assets = list_front_office_records("draft_asset", team_id=team_id, limit=1000)
    ledgers = list_front_office_records("ledger", season=season, team_id=team_id, record_status="active", limit=1000)
    contract_total = 0.0
    guaranteed_total = 0.0
    contract_rows = 0
    for item in contracts:
        for year in item["record"].get("years", []):
            if str(year.get("season")) != season:
                continue
            contract_rows += 1
            salary = float(year.get("cap_charge_override") if year.get("cap_charge_override") is not None else year.get("salary", 0))
            salary += float(year.get("likely_incentives", 0)) + float(year.get("dead_money", 0))
            contract_total += salary
            guaranteed_total += float(year.get("guaranteed_amount", 0))
    position = positions[0] if positions else None
    position_record = position["record"] if position else {}
    reported_active_salary = float(position_record.get("active_salary", 0))
    variance = reported_active_salary - contract_total
    blockers: list[str] = []
    if not contracts:
        blockers.append("No contract records are registered for this team and season.")
    if position is None:
        blockers.append("No team financial position is registered for this team and season.")
    if position and abs(variance) > 1:
        blockers.append("Registered contract charges do not reconcile to the reported active salary.")
    unverified = [item["id"] for item in contracts + assets + ledgers if item["source_status"] != "verified"]
    if unverified:
        blockers.append("One or more records are modeled or uploaded rather than verified.")
    return {
        "team_id": team_id,
        "season": season,
        "contract_count": len(contracts),
        "contract_year_rows": contract_rows,
        "contract_cap_charge": contract_total,
        "guaranteed_amount": guaranteed_total,
        "reported_active_salary": reported_active_salary,
        "active_salary_variance": variance,
        "draft_asset_count": len(assets),
        "ledger_transaction_count": len(ledgers),
        "unverified_record_ids": unverified,
        "blockers": blockers,
        "status": "pass" if not blockers else "review",
        "position": position,
    }


@router.on_event("startup")
def startup_front_office_api() -> None:
    init_front_office_db()


@router.put("/contracts/{record_id}")
def upsert_contract(record_id: str, payload: RecordUpsert) -> dict[str, Any]:
    return upsert_front_office_record("contract", record_id, payload)


@router.get("/contracts")
def list_contracts(
    season: str = "",
    team_id: str = "",
    player_id: str = "",
    source_status: str = "",
    record_status: str = "active",
    limit: int = Query(default=250, ge=1, le=1000),
) -> list[dict[str, Any]]:
    return list_front_office_records("contract", season, team_id, player_id, "", source_status, record_status, limit)


@router.put("/team-positions/{record_id}")
def upsert_team_position(record_id: str, payload: RecordUpsert) -> dict[str, Any]:
    return upsert_front_office_record("team_position", record_id, payload)


@router.get("/team-positions")
def list_team_positions(
    season: str = "",
    team_id: str = "",
    source_status: str = "",
    record_status: str = "active",
    limit: int = Query(default=100, ge=1, le=1000),
) -> list[dict[str, Any]]:
    return list_front_office_records("team_position", season, team_id, "", "", source_status, record_status, limit)


@router.put("/draft-assets/{record_id}")
def upsert_draft_asset(record_id: str, payload: RecordUpsert) -> dict[str, Any]:
    return upsert_front_office_record("draft_asset", record_id, payload)


@router.get("/draft-assets")
def list_draft_assets(
    team_id: str = "",
    source_status: str = "",
    record_status: str = "active",
    limit: int = Query(default=250, ge=1, le=1000),
) -> list[dict[str, Any]]:
    return list_front_office_records("draft_asset", "", team_id, "", "", source_status, record_status, limit)


@router.put("/ledger/{record_id}")
def upsert_ledger(record_id: str, payload: RecordUpsert) -> dict[str, Any]:
    return upsert_front_office_record("ledger", record_id, payload)


@router.get("/ledger")
def list_ledger(
    season: str = "",
    team_id: str = "",
    organization_id: str = "",
    source_status: str = "",
    record_status: str = "active",
    limit: int = Query(default=250, ge=1, le=1000),
) -> list[dict[str, Any]]:
    return list_front_office_records("ledger", season, team_id, "", organization_id, source_status, record_status, limit)


@router.post("/ledger/{record_id}/events")
def add_ledger_event(record_id: str, payload: LedgerEventCreate) -> dict[str, Any]:
    init_front_office_db()
    timestamp = now_iso()
    event_id = make_id("ledger_event")
    with connect() as connection:
        _ensure_shadow_user(connection, payload.actor_user_id, payload.actor_user_id, "analyst")
        exists = connection.execute("SELECT 1 FROM front_office_records WHERE id = ? AND record_type = 'ledger'", (record_id,)).fetchone()
        if exists is None:
            raise HTTPException(status_code=404, detail="Ledger transaction not found")
        connection.execute(
            "INSERT INTO transaction_ledger_events (id, ledger_id, actor_user_id, event_type, message, payload_json, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (event_id, record_id, payload.actor_user_id, payload.event_type[:80], payload.message[:2000], encode_json(payload.payload), timestamp),
        )
        connection.commit()
    return {"id": event_id, "ledger_id": record_id, "actor_user_id": payload.actor_user_id, "event_type": payload.event_type, "message": payload.message, "payload": payload.payload, "created_at": timestamp}


@router.get("/ledger/{record_id}/events")
def list_ledger_events(record_id: str) -> list[dict[str, Any]]:
    init_front_office_db()
    with connect() as connection:
        rows = connection.execute("SELECT * FROM transaction_ledger_events WHERE ledger_id = ? ORDER BY created_at DESC LIMIT 500", (record_id,)).fetchall()
        return [
            {
                "id": row["id"],
                "ledger_id": row["ledger_id"],
                "actor_user_id": row["actor_user_id"],
                "event_type": row["event_type"],
                "message": row["message"],
                "payload": decode_json(row["payload_json"], {}),
                "created_at": row["created_at"],
            }
            for row in rows
        ]


@router.get("/records/{record_id}/versions")
def list_record_versions(record_id: str) -> list[dict[str, Any]]:
    init_front_office_db()
    with connect() as connection:
        rows = connection.execute("SELECT * FROM front_office_record_versions WHERE record_id = ? ORDER BY version DESC LIMIT 100", (record_id,)).fetchall()
        return [
            {
                "id": row["id"],
                "record_id": row["record_id"],
                "record_type": row["record_type"],
                "version": row["version"],
                "actor_user_id": row["actor_user_id"],
                "record": decode_json(row["payload_json"], {}),
                "validation": decode_json(row["validation_json"], {}),
                "created_at": row["created_at"],
            }
            for row in rows
        ]


@router.get("/reconcile/{team_id}/{season}")
def reconcile_team(team_id: str, season: str) -> dict[str, Any]:
    return front_office_reconciliation(team_id.upper(), season)


@router.get("/summary")
def front_office_summary(season: str = "", organization_id: str = "") -> dict[str, Any]:
    init_front_office_db()
    clauses: list[str] = []
    values: list[Any] = []
    if season:
        clauses.append("season = ?")
        values.append(season)
    if organization_id:
        clauses.append("organization_id = ?")
        values.append(organization_id)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    with connect() as connection:
        rows = connection.execute(
            f"SELECT record_type, source_status, record_status, COUNT(*) AS count FROM front_office_records {where} GROUP BY record_type, source_status, record_status",
            values,
        ).fetchall()
        return {
            "season": season,
            "organization_id": organization_id,
            "counts": [dict(row) for row in rows],
            "generated_at": now_iso(),
        }
