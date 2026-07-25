from __future__ import annotations

import os
import tempfile
import traceback
from pathlib import Path


def checkpoint(label: str) -> None:
    print(f"PLATFORM_COMPLETION_CHECKPOINT: {label}", flush=True)


try:
    with tempfile.TemporaryDirectory(prefix="sports-terminal-completion-") as temp_dir:
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(temp_dir) / "completion.sqlite")
        os.environ["SPORTS_TERMINAL_BLOCKED_TERMS"] = "configured-prohibited-test-term"

        from app.front_office_api import (
            LedgerEventCreate,
            RecordUpsert,
            add_ledger_event,
            front_office_reconciliation,
            init_front_office_db,
            list_front_office_records,
            list_ledger_events,
            upsert_front_office_record,
        )
        from app.python_runtime_api import PythonExecutionRequest, execute_python_notebook, validate_python_code
        from app.trust_safety_api import (
            CommunityCommentCreate,
            CommunityPostCreate,
            ConversationCreate,
            MessageCreate,
            ModerationActionCreate,
            ReactionToggle,
            RelationshipUpdate,
            ReportCreate,
            apply_moderation_action,
            block_user,
            create_community_post,
            create_conversation,
            create_report,
            init_trust_safety_db,
            list_community_posts,
            list_messages,
            list_moderation_queue,
            send_message,
            toggle_reaction,
        )

        checkpoint("initialize completion databases")
        init_front_office_db()
        init_trust_safety_db()

        checkpoint("canonical player contract")
        contract = upsert_front_office_record(
            "contract",
            "contract-player-1",
            RecordUpsert(
                actor_user_id="analyst-one",
                record={
                    "player_id": "player-1",
                    "player_name": "Launch Player",
                    "team_id": "CHI",
                    "season": "2025-26",
                    "years": [
                        {
                            "season": "2025-26",
                            "salary": 25_000_000,
                            "guaranteed_amount": 25_000_000,
                            "likely_incentives": 500_000,
                            "option_type": "none",
                        },
                        {
                            "season": "2026-27",
                            "salary": 27_000_000,
                            "guaranteed_amount": 15_000_000,
                            "option_type": "team",
                        },
                    ],
                    "source_status": "verified",
                    "source_label": "Contract test source",
                    "source_document_id": "document-1",
                    "as_of_date": "2026-07-24",
                },
            ),
        )
        assert contract["validation"]["status"] == "pass"
        assert contract["version"] == 1

        checkpoint("team position and draft asset")
        position = upsert_front_office_record(
            "team_position",
            "position-chi-2025",
            RecordUpsert(
                actor_user_id="analyst-one",
                record={
                    "team_id": "CHI",
                    "season": "2025-26",
                    "salary_cap": 154_647_000,
                    "luxury_tax": 187_895_000,
                    "first_apron": 195_945_000,
                    "second_apron": 207_824_000,
                    "active_salary": 25_500_000,
                    "source_status": "verified",
                    "source_label": "Team position test source",
                    "source_document_id": "document-2",
                    "as_of_date": "2026-07-24",
                },
            ),
        )
        assert position["validation"]["status"] in {"pass", "warning"}
        asset = upsert_front_office_record(
            "draft_asset",
            "asset-chi-2029-1",
            RecordUpsert(
                actor_user_id="analyst-one",
                record={
                    "current_team_id": "CHI",
                    "original_team_id": "CHI",
                    "draft_year": 2029,
                    "round": 1,
                    "asset_type": "pick",
                    "description": "CHI 2029 first-round pick",
                    "protections": [],
                    "source_status": "uploaded",
                    "source_label": "Internal pick ledger",
                },
            ),
        )
        assert asset["record"]["draft_year"] == 2029

        checkpoint("transaction ledger and immutable events")
        ledger = upsert_front_office_record(
            "ledger",
            "ledger-1",
            RecordUpsert(
                actor_user_id="analyst-one",
                record={
                    "organization_id": "org-test",
                    "case_id": "case-test",
                    "season": "2025-26",
                    "transaction_type": "trade",
                    "effective_date": "2026-02-05",
                    "status": "review",
                    "teams": ["CHI", "BOS"],
                    "summary": "Modeled contract and pick transaction.",
                    "contract_ids": ["contract-player-1"],
                    "draft_asset_ids": ["asset-chi-2029-1"],
                    "salary_movements": [
                        {
                            "team_id": "CHI",
                            "player_id": "player-1",
                            "label": "Launch Player",
                            "direction": "outgoing",
                            "amount": 25_500_000,
                            "season": "2025-26",
                        }
                    ],
                    "source_status": "modeled",
                },
            ),
        )
        assert ledger["validation"]["status"] in {"pass", "warning"}
        event = add_ledger_event(
            "ledger-1",
            LedgerEventCreate(
                actor_user_id="reviewer-one",
                event_type="review_requested",
                message="Requested CBA and pick review.",
            ),
        )
        assert event["ledger_id"] == "ledger-1"
        assert len(list_ledger_events("ledger-1")) == 1
        assert len(list_front_office_records("contract", season="2025-26", team_id="CHI")) == 1
        reconciliation = front_office_reconciliation("CHI", "2025-26")
        assert reconciliation["contract_cap_charge"] == 25_500_000
        assert reconciliation["active_salary_variance"] == 0

        checkpoint("moderated community publishing")
        post = create_community_post(
            CommunityPostCreate(
                actor_user_id="community-author",
                board="NBA General",
                title="Launch discussion",
                body="A sourced basketball discussion without spam patterns.",
            )
        )
        assert post["status"] == "published"
        reaction = toggle_reaction(
            post["id"],
            ReactionToggle(actor_user_id="community-reader"),
        )
        assert reaction["active"] is True
        assert reaction["count"] == 1
        visible = list_community_posts(viewer_user_id="community-reader")
        assert visible[0]["id"] == post["id"]
        assert visible[0]["liked_by_viewer"] is True

        checkpoint("reports, moderation action and audit state")
        moderation_case = create_report(
            ReportCreate(
                actor_user_id="community-reader",
                target_type="post",
                target_id=post["id"],
                reason="Needs source review",
                priority="high",
            )
        )
        assert moderation_case["status"] == "open"
        assert list_moderation_queue("open")[0]["id"] == moderation_case["id"]
        action = apply_moderation_action(
            moderation_case["id"],
            ModerationActionCreate(
                actor_user_id="moderator-one",
                action="hide",
                reason="Temporarily hidden during source review.",
            ),
        )
        assert action["status"] == "monitoring"
        assert list_community_posts(viewer_user_id="community-reader") == []

        checkpoint("blocks enforced in messaging")
        conversation = create_conversation(
            ConversationCreate(
                actor_user_id="message-one",
                member_user_ids=["message-two"],
                title="Basketball operations thread",
            )
        )
        first_message = send_message(
            conversation["id"],
            MessageCreate(actor_user_id="message-one", body="Initial review note."),
        )
        assert first_message["status"] == "sent"
        assert len(list_messages(conversation["id"], "message-two")) == 1
        block_user(
            RelationshipUpdate(
                actor_user_id="message-two",
                target_user_id="message-one",
                reason="Contract test block",
            )
        )
        try:
            send_message(
                conversation["id"],
                MessageCreate(actor_user_id="message-one", body="This must be rejected."),
            )
            raise AssertionError("Blocked message unexpectedly succeeded")
        except Exception as error:
            assert "block" in str(error).lower()

        checkpoint("isolated Python notebook execution")
        assert validate_python_code("import os")
        assert validate_python_code("open('secret.txt')")
        runtime = execute_python_notebook(
            PythonExecutionRequest(
                code="values = numeric('points')\nresult = {'count': len(values), 'mean': mean(values), 'maximum': max(values)}\nprint('analysis complete')",
                rows=[{"player": "A", "points": 20}, {"player": "B", "points": 30}],
                columns=[{"key": "player"}, {"key": "points"}],
            )
        )
        assert runtime.status == "completed"
        assert runtime.result["count"] == 2
        assert runtime.result["mean"] == 25
        assert runtime.result["maximum"] == 30
        assert "analysis complete" in runtime.stdout

    print("Sports Terminal platform completion contract test passed.")
except Exception as error:
    print(f"PLATFORM_COMPLETION_FAILURE: {type(error).__name__}: {error}", flush=True)
    traceback.print_exc()
    raise
